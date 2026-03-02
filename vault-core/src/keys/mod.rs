use bitcoin::bip32::{ChildNumber, DerivationPath, ExtendedPubKey};
use bitcoin::secp256k1::{Secp256k1, XOnlyPublicKey};
use serde::{Deserialize, Serialize};

use crate::error::CoreError;
use crate::vault::Network;

/// Validated xpub information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XpubInfo {
    /// The original xpub string
    pub xpub: String,
    /// Master key fingerprint (first 4 bytes of hash)
    pub fingerprint: String,
    /// Network this xpub belongs to
    pub network: String,
    /// Whether this key supports Taproot (BIP86)
    pub supports_taproot: bool,
}

/// Validate an xpub string and extract info
pub fn validate_xpub(xpub_str: &str, network: Network) -> Result<XpubInfo, CoreError> {
    let xpub = xpub_str.parse::<ExtendedPubKey>()
        .map_err(|e| CoreError::InvalidXpub(format!("Failed to parse xpub: {}", e)))?;

    let btc_network: bitcoin::Network = network.into();

    // Check network prefix matches
    // tpub = testnet/signet/regtest, xpub = mainnet
    let is_testnet_key = xpub_str.starts_with("tpub");
    let is_mainnet_key = xpub_str.starts_with("xpub");

    let expected_mainnet = matches!(btc_network, bitcoin::Network::Bitcoin);
    if expected_mainnet && !is_mainnet_key {
        return Err(CoreError::NetworkMismatch {
            expected: "mainnet (xpub)".to_string(),
            actual: "testnet key (tpub)".to_string(),
        });
    }
    if !expected_mainnet && !is_testnet_key {
        return Err(CoreError::NetworkMismatch {
            expected: "testnet (tpub)".to_string(),
            actual: "mainnet key (xpub)".to_string(),
        });
    }

    let fingerprint = hex::encode(xpub.fingerprint().as_bytes());

    Ok(XpubInfo {
        xpub: xpub_str.to_string(),
        fingerprint,
        network: format!("{:?}", network),
        supports_taproot: true, // All modern xpubs support Taproot
    })
}

/// Get BIP86 derivation path for a vault index
///
/// BIP86 path: m/86'/coin'/account'/change/index
/// Since we receive account-level xpub from hardware wallet,
/// we derive relative path: m/0/{vault_index}
pub fn get_derivation_path(vault_index: u32, network: Network) -> String {
    let coin = match network {
        Network::Mainnet => 0,
        _ => 1,
    };
    // Full absolute path (for display)
    format!("m/86'/{}'/0'/0/{}", coin, vault_index)
}

/// Derive a child x-only public key from an account xpub
///
/// The xpub is expected to be at the account level (m/86'/coin'/account')
/// We derive: xpub/0/{vault_index} (receive address at given index)
pub fn derive_child_pubkey(
    xpub_str: &str,
    vault_index: u32,
    _network: Network,
) -> Result<XOnlyPublicKey, CoreError> {
    let secp = Secp256k1::new();

    let xpub = xpub_str.parse::<ExtendedPubKey>()
        .map_err(|e| CoreError::InvalidXpub(format!("Failed to parse xpub: {}", e)))?;

    // Derive: /0/{vault_index} (non-hardened, relative from account xpub)
    let path = DerivationPath::from(vec![
        ChildNumber::Normal { index: 0 },           // change = 0 (receive)
        ChildNumber::Normal { index: vault_index },  // vault index
    ]);

    let child_xpub = xpub
        .derive_pub(&secp, &path)
        .map_err(|e| CoreError::DerivationError(format!("Child derivation failed: {}", e)))?;

    Ok(child_xpub.to_x_only_pub())
}

/// Create a provably unspendable internal key (NUMS point)
///
/// Used when no emergency device is configured.
/// This is the standard "nothing up my sleeve" point:
/// H = lift_x(SHA256("TapTweak"))
/// Spending via key-path is impossible with this internal key.
pub fn unspendable_internal_key() -> XOnlyPublicKey {
    // Standard NUMS point: the x-coordinate of the point whose discrete
    // log is unknown. This is the hash of the string "Freedom Wallet NUMS"
    // converted to a valid x-only public key on secp256k1.
    //
    // In practice, we use the generator point approach:
    // Take SHA256 of a fixed string, use it as x-coordinate, check if valid.
    use bitcoin::hashes::{sha256, Hash};
    let hash = sha256::Hash::hash(b"Freedom Wallet unspendable key v1");
    let hash_bytes = hash.as_byte_array();

    // Try to create a valid x-only public key from the hash
    // If invalid (not on curve), we use a well-known NUMS point instead
    match XOnlyPublicKey::from_slice(hash_bytes) {
        Ok(key) => key,
        Err(_) => {
            // Fallback: use the BIP341 recommended NUMS point
            // H = lift_x(0x0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0)
            // But as x-only (32 bytes): 50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0
            let nums_bytes = hex::decode(
                "50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"
            ).expect("valid hex");
            XOnlyPublicKey::from_slice(&nums_bytes).expect("valid NUMS point")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // BIP32 test vector 1: master public key (mainnet)
    const TEST_XPUB: &str = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";

    #[test]
    fn test_validate_xpub_success() {
        let result = validate_xpub(TEST_XPUB, Network::Mainnet);
        assert!(result.is_ok());
        let info = result.unwrap();
        assert_eq!(info.xpub, TEST_XPUB);
        assert_eq!(info.fingerprint, "3442193e");
        assert!(info.supports_taproot);
    }

    #[test]
    fn test_validate_xpub_network_mismatch() {
        // xpub (mainnet key) on testnet should fail
        let result = validate_xpub(TEST_XPUB, Network::Testnet);
        assert!(result.is_err());
        match result.unwrap_err() {
            CoreError::NetworkMismatch { .. } => {}
            other => panic!("Expected NetworkMismatch, got {:?}", other),
        }
    }

    #[test]
    fn test_validate_xpub_invalid_string() {
        let result = validate_xpub("not-an-xpub", Network::Mainnet);
        assert!(result.is_err());
    }

    #[test]
    fn test_get_derivation_path() {
        assert_eq!(get_derivation_path(0, Network::Mainnet), "m/86'/0'/0'/0/0");
        assert_eq!(get_derivation_path(5, Network::Testnet), "m/86'/1'/0'/0/5");
        assert_eq!(get_derivation_path(42, Network::Signet), "m/86'/1'/0'/0/42");
    }

    #[test]
    fn test_derive_child_pubkey() {
        let result = derive_child_pubkey(TEST_XPUB, 0, Network::Mainnet);
        assert!(result.is_ok());
        let key = result.unwrap();
        assert_eq!(key.serialize().len(), 32);
    }

    #[test]
    fn test_derive_child_pubkey_deterministic() {
        let key1 = derive_child_pubkey(TEST_XPUB, 0, Network::Mainnet).unwrap();
        let key2 = derive_child_pubkey(TEST_XPUB, 0, Network::Mainnet).unwrap();
        assert_eq!(key1, key2);

        // Different index should give different key
        let key3 = derive_child_pubkey(TEST_XPUB, 1, Network::Mainnet).unwrap();
        assert_ne!(key1, key3);
    }

    #[test]
    fn test_unspendable_internal_key() {
        let key = unspendable_internal_key();
        assert_eq!(key.serialize().len(), 32);
    }
}
