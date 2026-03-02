use bitcoin::address::Address;
use bitcoin::blockdata::opcodes::all::{OP_CHECKSIGVERIFY, OP_RETURN};
use bitcoin::blockdata::script::{Builder, PushBytesBuf, ScriptBuf};
use bitcoin::secp256k1::{Secp256k1, XOnlyPublicKey};
use bitcoin::taproot::TaprootBuilder;
use bitcoin::Sequence;
use serde::{Deserialize, Serialize};

use crate::error::CoreError;
use crate::keys;
use crate::vault::{Network, VaultMetadata, VaultTemplate, RecoveryType};

/// Result of generating a vault Taproot address
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultAddressResult {
    /// Taproot address (bc1p... or tb1p...)
    pub address: String,
    /// Internal key (hex)
    pub internal_key: String,
    /// Spending script (hex)
    pub spending_script_hex: String,
    /// Metadata script (hex)
    pub metadata_script_hex: String,
    /// Vault metadata that was encoded
    pub metadata: VaultMetadata,
}

/// Generate a Taproot vault address with spending delay and metadata
///
/// Script tree structure:
///   Internal Key = emergency key (or NUMS if no emergency device)
///   Leaf 0 (depth 1): Spending script = <primary_key> OP_CHECKSIGVERIFY <delay> OP_CSV
///   Leaf 1 (depth 1): Metadata script = OP_RETURN <metadata_bytes>
pub fn generate_vault_address(
    primary_xpub: &str,
    emergency_xpub: Option<&str>,
    template: &VaultTemplate,
    vault_index: u32,
    network: Network,
) -> Result<VaultAddressResult, CoreError> {
    let secp = Secp256k1::new();
    let btc_network: bitcoin::Network = network.into();

    // 1. Derive primary key for spending script
    let primary_key = keys::derive_child_pubkey(primary_xpub, vault_index, network)?;

    // 2. Determine internal key (emergency or unspendable)
    let internal_key = match emergency_xpub {
        Some(xpub) => keys::derive_child_pubkey(xpub, vault_index, network)?,
        None => keys::unspendable_internal_key(),
    };

    // 3. Build spending script: <primary_key> OP_CHECKSIGVERIFY <delay> OP_CSV
    let delay_blocks = template.delay_blocks();
    let spending_script = build_spending_script(&primary_key, delay_blocks);

    // 4. Build metadata
    let recovery_type = match template {
        VaultTemplate::Custom { recovery_type, .. } => *recovery_type,
        _ => {
            if emergency_xpub.is_some() {
                RecoveryType::EmergencyKey
            } else {
                RecoveryType::TimelockOnly
            }
        }
    };

    let metadata = VaultMetadata {
        version: 1,
        template_id: template.template_id().to_string(),
        delay_blocks,
        destination_indices: vec![],
        recovery_type,
        created_at_block: 0, // Filled by caller with actual block height
        vault_index,
    };

    // 5. Build metadata script: OP_RETURN <metadata_bytes>
    let metadata_script = build_metadata_script(&metadata);

    // 6. Build Taproot script tree with two leaves at depth 1
    let builder = TaprootBuilder::new()
        .add_leaf(1, spending_script.clone())
        .map_err(|e| CoreError::DerivationError(format!("Failed to add spending leaf: {:?}", e)))?
        .add_leaf(1, metadata_script.clone())
        .map_err(|e| CoreError::DerivationError(format!("Failed to add metadata leaf: {:?}", e)))?;

    let spend_info = builder
        .finalize(&secp, internal_key)
        .map_err(|_| CoreError::DerivationError("Failed to finalize Taproot tree".to_string()))?;

    // 7. Generate address
    let address = Address::p2tr(
        &secp,
        internal_key,
        spend_info.merkle_root(),
        btc_network,
    );

    Ok(VaultAddressResult {
        address: address.to_string(),
        internal_key: hex::encode(internal_key.serialize()),
        spending_script_hex: hex::encode(spending_script.as_bytes()),
        metadata_script_hex: hex::encode(metadata_script.as_bytes()),
        metadata,
    })
}

/// Build the spending script: <primary_key> OP_CHECKSIGVERIFY <delay> OP_CSV
///
/// This script enforces:
/// 1. A valid Schnorr signature from the primary device key
/// 2. A minimum relative timelock of `delay_blocks` blocks
fn build_spending_script(primary_key: &XOnlyPublicKey, delay_blocks: u32) -> ScriptBuf {
    Builder::new()
        .push_x_only_key(primary_key)
        .push_opcode(OP_CHECKSIGVERIFY)
        .push_sequence(Sequence::from_height(delay_blocks as u16))
        .push_opcode(bitcoin::blockdata::opcodes::all::OP_CSV)
        .into_script()
}

/// Build the metadata script: OP_RETURN <metadata_bytes>
///
/// This leaf is provably unspendable (OP_RETURN always fails).
/// It commits vault configuration to the blockchain for recovery.
fn build_metadata_script(metadata: &VaultMetadata) -> ScriptBuf {
    let metadata_bytes = metadata.to_bytes();
    let push_bytes = PushBytesBuf::try_from(metadata_bytes)
        .expect("metadata bytes should be valid push data (< 4294967296 bytes)");
    Builder::new()
        .push_opcode(OP_RETURN)
        .push_slice(&push_bytes)
        .into_script()
}

/// Validate a Bitcoin address string for the given network
pub fn validate_address(address_str: &str, network: Network) -> Result<bool, CoreError> {
    let btc_network: bitcoin::Network = network.into();
    let address = address_str
        .parse::<Address<bitcoin::address::NetworkUnchecked>>()
        .map_err(|e| CoreError::InvalidAddress(format!("Failed to parse address: {}", e)))?;

    let checked = address
        .require_network(btc_network)
        .map_err(|e| CoreError::InvalidAddress(format!("Network mismatch: {}", e)))?;

    Ok(checked.is_spend_standard())
}

/// Decode metadata from a script leaf hex string
pub fn decode_metadata_from_script(script_hex: &str) -> Result<VaultMetadata, CoreError> {
    let script_bytes = hex::decode(script_hex)
        .map_err(|e| CoreError::MetadataError(format!("Invalid hex: {}", e)))?;

    // The script is: OP_RETURN <push> <metadata_bytes>
    // OP_RETURN = 0x6a, then a push of the metadata
    if script_bytes.is_empty() || script_bytes[0] != 0x6a {
        return Err(CoreError::MetadataError("Script does not start with OP_RETURN".to_string()));
    }

    if script_bytes.len() < 3 {
        return Err(CoreError::MetadataError("Script too short".to_string()));
    }

    // Parse the push opcode
    let (data_start, data_len) = if script_bytes[1] < 0x4c {
        (2usize, script_bytes[1] as usize)
    } else if script_bytes[1] == 0x4c {
        if script_bytes.len() < 4 {
            return Err(CoreError::MetadataError("Script too short for PUSHDATA1".to_string()));
        }
        (3usize, script_bytes[2] as usize)
    } else {
        return Err(CoreError::MetadataError("Unexpected push opcode".to_string()));
    };

    if data_start + data_len > script_bytes.len() {
        return Err(CoreError::MetadataError("Data extends past script end".to_string()));
    }

    VaultMetadata::from_bytes(&script_bytes[data_start..data_start + data_len])
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_XPUB: &str = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";

    #[test]
    fn test_generate_vault_address_savings() {
        let result = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 0, Network::Mainnet,
        );
        assert!(result.is_ok(), "Failed: {:?}", result.err());
        let addr = result.unwrap();
        assert!(addr.address.starts_with("bc1p"), "Got: {}", addr.address);
        assert!(!addr.spending_script_hex.is_empty());
        assert!(!addr.metadata_script_hex.is_empty());
        assert_eq!(addr.metadata.delay_blocks, 1008);
    }

    #[test]
    fn test_generate_vault_address_spending() {
        let result = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::spending(), 0, Network::Mainnet,
        );
        assert!(result.is_ok());
        let addr = result.unwrap();
        assert!(addr.address.starts_with("bc1p"));
        assert_eq!(addr.metadata.delay_blocks, 144);
    }

    #[test]
    fn test_generate_vault_address_with_emergency() {
        let result = generate_vault_address(
            TEST_XPUB, Some(TEST_XPUB), &VaultTemplate::savings(), 0, Network::Mainnet,
        );
        assert!(result.is_ok());
    }

    #[test]
    fn test_generate_vault_address_deterministic() {
        let a1 = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 0, Network::Mainnet,
        ).unwrap();
        let a2 = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 0, Network::Mainnet,
        ).unwrap();
        assert_eq!(a1.address, a2.address);

        let a3 = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 1, Network::Mainnet,
        ).unwrap();
        assert_ne!(a1.address, a3.address);
    }

    #[test]
    fn test_metadata_roundtrip_via_script() {
        let addr = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 42, Network::Mainnet,
        ).unwrap();

        let decoded = decode_metadata_from_script(&addr.metadata_script_hex).unwrap();
        assert_eq!(decoded.version, 1);
        assert_eq!(decoded.template_id, "savings_v1");
        assert_eq!(decoded.delay_blocks, 1008);
        assert_eq!(decoded.vault_index, 42);
    }

    #[test]
    fn test_validate_address_valid() {
        let addr = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 0, Network::Mainnet,
        ).unwrap();
        assert!(validate_address(&addr.address, Network::Mainnet).unwrap());
    }

    #[test]
    fn test_validate_address_wrong_network() {
        let addr = generate_vault_address(
            TEST_XPUB, None, &VaultTemplate::savings(), 0, Network::Mainnet,
        ).unwrap();
        assert!(validate_address(&addr.address, Network::Testnet).is_err());
    }

    #[test]
    fn test_spending_script_structure() {
        let key = keys::derive_child_pubkey(TEST_XPUB, 0, Network::Mainnet).unwrap();
        let script = build_spending_script(&key, 1008);
        let bytes = script.as_bytes();
        assert!(!bytes.is_empty());
        assert!(bytes.contains(&0xad), "Missing OP_CHECKSIGVERIFY");
        assert!(bytes.contains(&0xb2), "Missing OP_CSV");
    }
}
