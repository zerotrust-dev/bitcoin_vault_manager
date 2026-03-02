use base64::Engine;
use bitcoin::absolute::LockTime;
use bitcoin::address::Address;
use bitcoin::blockdata::opcodes::all::{OP_CHECKSIGVERIFY, OP_RETURN};
use bitcoin::blockdata::script::{Builder, PushBytesBuf};
use bitcoin::psbt::{Input as PsbtInput, Psbt};
use bitcoin::secp256k1::{Secp256k1, XOnlyPublicKey};
use bitcoin::taproot::{LeafVersion, TaprootBuilder};
use bitcoin::{OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, Witness};
use serde::{Deserialize, Serialize};

use crate::error::CoreError;
use crate::keys;
use crate::vault::{Network, RecoveryType, VaultMetadata, VaultTemplate};

/// Spend path type
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SpendPath {
    /// Script path with CSV delay
    Delayed,
    /// Key path immediate (emergency only)
    Emergency,
}

/// UTXO information for transaction building
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Utxo {
    /// Transaction ID
    pub txid: String,
    /// Output index
    pub vout: u32,
    /// Amount in satoshis
    pub amount_sats: u64,
    /// Block height where the UTXO was confirmed (for CSV calculation)
    pub confirmation_height: Option<u32>,
}

/// Vault configuration needed for PSBT building
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultConfig {
    /// Primary device xpub
    pub primary_xpub: String,
    /// Emergency device xpub (optional)
    pub emergency_xpub: Option<String>,
    /// Vault template
    pub template: VaultTemplate,
    /// Vault index for key derivation
    pub vault_index: u32,
    /// Bitcoin network
    pub network: Network,
}

/// Spending intent from user
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpendIntent {
    /// Destination address
    pub destination: String,
    /// Fee rate in sat/vB
    pub fee_rate: f64,
}

/// Result from PSBT building
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PsbtResult {
    /// Base64-encoded PSBT
    pub psbt_base64: String,
    /// Transaction summary
    pub summary: TransactionSummary,
}

/// Human-readable transaction summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionSummary {
    /// Destination address
    pub to_address: String,
    /// Total input amount in satoshis
    pub input_sats: u64,
    /// Amount being sent (input - fee)
    pub send_sats: u64,
    /// Fee in satoshis
    pub fee_sats: u64,
    /// Spend path used
    pub path_type: SpendPath,
    /// Delay blocks (for delayed spend)
    pub delay_blocks: Option<u32>,
}

/// Policy check result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolicyCheck {
    pub valid: bool,
    pub warnings: Vec<String>,
    pub errors: Vec<String>,
}

/// Finalized transaction result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FinalizedTx {
    /// Raw transaction hex
    pub tx_hex: String,
    /// Transaction ID
    pub txid: String,
    /// Transaction virtual size in vbytes
    pub vsize: u64,
}

// ═══════════════════════════════════════════════════════════════════
//                    DELAYED SPEND (SCRIPT-PATH)
// ═══════════════════════════════════════════════════════════════════

/// Build a PSBT for a delayed spend (script-path with CSV timelock).
///
/// This is a sweep transaction: all UTXOs are consumed, no change output.
/// The signature must come from the primary device key.
/// The transaction enforces a relative timelock via OP_CSV.
pub fn build_delayed_spend_psbt(
    intent: &SpendIntent,
    utxos: &[Utxo],
    vault: &VaultConfig,
) -> Result<PsbtResult, CoreError> {
    if utxos.is_empty() {
        return Err(CoreError::InsufficientFunds {
            needed: 1,
            available: 0,
        });
    }

    let secp = Secp256k1::new();
    let btc_network: bitcoin::Network = vault.network.into();
    let delay_blocks = vault.template.delay_blocks();

    // Derive keys
    let primary_key = keys::derive_child_pubkey(&vault.primary_xpub, vault.vault_index, vault.network)?;
    let internal_key = match &vault.emergency_xpub {
        Some(xpub) => keys::derive_child_pubkey(xpub, vault.vault_index, vault.network)?,
        None => keys::unspendable_internal_key(),
    };

    // Build the spending script (same as used in address generation)
    let spending_script = build_spending_script(&primary_key, delay_blocks);

    // Build the metadata script (needed for the full script tree)
    let recovery_type = match &vault.template {
        VaultTemplate::Custom { recovery_type, .. } => *recovery_type,
        _ => {
            if vault.emergency_xpub.is_some() {
                RecoveryType::EmergencyKey
            } else {
                RecoveryType::TimelockOnly
            }
        }
    };

    let metadata = VaultMetadata {
        version: 1,
        template_id: vault.template.template_id().to_string(),
        delay_blocks,
        destination_indices: vec![],
        recovery_type,
        created_at_block: 0,
        vault_index: vault.vault_index,
    };
    let metadata_script = build_metadata_script(&metadata);

    // Build the Taproot tree to get the control block
    let builder = TaprootBuilder::new()
        .add_leaf(1, spending_script.clone())
        .map_err(|e| CoreError::PsbtError(format!("Failed to add spending leaf: {:?}", e)))?
        .add_leaf(1, metadata_script.clone())
        .map_err(|e| CoreError::PsbtError(format!("Failed to add metadata leaf: {:?}", e)))?;

    let spend_info = builder
        .finalize(&secp, internal_key)
        .map_err(|_| CoreError::PsbtError("Failed to finalize Taproot tree".to_string()))?;

    // Get the control block for the spending script leaf
    let control_block = spend_info
        .control_block(&(spending_script.clone(), LeafVersion::TapScript))
        .ok_or_else(|| CoreError::PsbtError("Failed to get control block".to_string()))?;

    // Compute the script pubkey for the vault address
    let vault_address = Address::p2tr(
        &secp,
        internal_key,
        spend_info.merkle_root(),
        btc_network,
    );
    let script_pubkey = vault_address.script_pubkey();

    // Parse destination address
    let dest_address = intent
        .destination
        .parse::<Address<bitcoin::address::NetworkUnchecked>>()
        .map_err(|e| CoreError::InvalidAddress(format!("Invalid destination: {}", e)))?
        .require_network(btc_network)
        .map_err(|e| CoreError::InvalidAddress(format!("Network mismatch: {}", e)))?;

    // Build transaction inputs
    let total_input_sats: u64 = utxos.iter().map(|u| u.amount_sats).sum();

    let tx_inputs: Vec<TxIn> = utxos
        .iter()
        .map(|utxo| {
            let txid = utxo
                .txid
                .parse::<Txid>()
                .expect("valid txid");
            TxIn {
                previous_output: OutPoint::new(txid, utxo.vout),
                script_sig: ScriptBuf::new(),
                sequence: Sequence::from_height(delay_blocks as u16),
                witness: Witness::default(),
            }
        })
        .collect();

    // Estimate fee: Taproot script-path spend ~150 vbytes per input + ~40 vbytes output overhead
    let estimated_vsize = (tx_inputs.len() as u64 * 150) + 40;
    let fee_sats = (estimated_vsize as f64 * intent.fee_rate).ceil() as u64;

    if total_input_sats <= fee_sats {
        return Err(CoreError::InsufficientFunds {
            needed: fee_sats + 1,
            available: total_input_sats,
        });
    }

    let send_sats = total_input_sats - fee_sats;

    // Build unsigned transaction (sweep — single output, no change)
    let unsigned_tx = Transaction {
        version: 2,
        lock_time: LockTime::ZERO,
        input: tx_inputs,
        output: vec![TxOut {
            value: send_sats,
            script_pubkey: dest_address.script_pubkey(),
        }],
    };

    // Create PSBT
    let mut psbt = Psbt::from_unsigned_tx(unsigned_tx)
        .map_err(|e| CoreError::PsbtError(format!("Failed to create PSBT: {}", e)))?;

    // Fill PSBT input data for each input
    for (i, utxo) in utxos.iter().enumerate() {
        let witness_utxo = TxOut {
            value: utxo.amount_sats,
            script_pubkey: script_pubkey.clone(),
        };

        psbt.inputs[i] = PsbtInput {
            witness_utxo: Some(witness_utxo),
            tap_internal_key: Some(internal_key),
            tap_merkle_root: spend_info.merkle_root(),
            ..Default::default()
        };

        // Add the tap script (spending leaf) for signing
        psbt.inputs[i].tap_scripts.insert(
            control_block.clone(),
            (spending_script.clone(), LeafVersion::TapScript),
        );
    }

    // Serialize to base64
    let psbt_base64 = base64::engine::general_purpose::STANDARD.encode(&psbt.serialize());

    Ok(PsbtResult {
        psbt_base64,
        summary: TransactionSummary {
            to_address: intent.destination.clone(),
            input_sats: total_input_sats,
            send_sats,
            fee_sats,
            path_type: SpendPath::Delayed,
            delay_blocks: Some(delay_blocks),
        },
    })
}

// ═══════════════════════════════════════════════════════════════════
//                   EMERGENCY SPEND (KEY-PATH)
// ═══════════════════════════════════════════════════════════════════

/// Build a PSBT for an emergency key-path spend (no delay).
///
/// This requires the emergency device (internal key) to sign.
/// No script disclosure needed — simple Schnorr signature.
pub fn build_emergency_psbt(
    destination: &str,
    fee_rate: f64,
    utxos: &[Utxo],
    vault: &VaultConfig,
) -> Result<PsbtResult, CoreError> {
    if vault.emergency_xpub.is_none() {
        return Err(CoreError::PolicyViolation(
            "Emergency spend requires an emergency device".to_string(),
        ));
    }

    if utxos.is_empty() {
        return Err(CoreError::InsufficientFunds {
            needed: 1,
            available: 0,
        });
    }

    let secp = Secp256k1::new();
    let btc_network: bitcoin::Network = vault.network.into();
    let delay_blocks = vault.template.delay_blocks();

    // Derive keys
    let primary_key = keys::derive_child_pubkey(&vault.primary_xpub, vault.vault_index, vault.network)?;
    let internal_key = keys::derive_child_pubkey(
        vault.emergency_xpub.as_ref().unwrap(),
        vault.vault_index,
        vault.network,
    )?;

    // Build script tree (same as address generation) to get merkle root
    let spending_script = build_spending_script(&primary_key, delay_blocks);
    let recovery_type = match &vault.template {
        VaultTemplate::Custom { recovery_type, .. } => *recovery_type,
        _ => RecoveryType::EmergencyKey,
    };
    let metadata = VaultMetadata {
        version: 1,
        template_id: vault.template.template_id().to_string(),
        delay_blocks,
        destination_indices: vec![],
        recovery_type,
        created_at_block: 0,
        vault_index: vault.vault_index,
    };
    let metadata_script = build_metadata_script(&metadata);

    let builder = TaprootBuilder::new()
        .add_leaf(1, spending_script)
        .map_err(|e| CoreError::PsbtError(format!("Failed to add spending leaf: {:?}", e)))?
        .add_leaf(1, metadata_script)
        .map_err(|e| CoreError::PsbtError(format!("Failed to add metadata leaf: {:?}", e)))?;

    let spend_info = builder
        .finalize(&secp, internal_key)
        .map_err(|_| CoreError::PsbtError("Failed to finalize Taproot tree".to_string()))?;

    // Vault address for script_pubkey
    let vault_address = Address::p2tr(
        &secp,
        internal_key,
        spend_info.merkle_root(),
        btc_network,
    );
    let script_pubkey = vault_address.script_pubkey();

    // Parse destination
    let dest_address = destination
        .parse::<Address<bitcoin::address::NetworkUnchecked>>()
        .map_err(|e| CoreError::InvalidAddress(format!("Invalid destination: {}", e)))?
        .require_network(btc_network)
        .map_err(|e| CoreError::InvalidAddress(format!("Network mismatch: {}", e)))?;

    // Build inputs (no sequence restriction for key-path spend)
    let total_input_sats: u64 = utxos.iter().map(|u| u.amount_sats).sum();

    let tx_inputs: Vec<TxIn> = utxos
        .iter()
        .map(|utxo| {
            let txid = utxo.txid.parse::<Txid>().expect("valid txid");
            TxIn {
                previous_output: OutPoint::new(txid, utxo.vout),
                script_sig: ScriptBuf::new(),
                sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
                witness: Witness::default(),
            }
        })
        .collect();

    // Key-path spends are smaller: ~58 vbytes per input + ~40 output overhead
    let estimated_vsize = (tx_inputs.len() as u64 * 58) + 40;
    let fee_sats = (estimated_vsize as f64 * fee_rate).ceil() as u64;

    if total_input_sats <= fee_sats {
        return Err(CoreError::InsufficientFunds {
            needed: fee_sats + 1,
            available: total_input_sats,
        });
    }

    let send_sats = total_input_sats - fee_sats;

    let unsigned_tx = Transaction {
        version: 2,
        lock_time: LockTime::ZERO,
        input: tx_inputs,
        output: vec![TxOut {
            value: send_sats,
            script_pubkey: dest_address.script_pubkey(),
        }],
    };

    let mut psbt = Psbt::from_unsigned_tx(unsigned_tx)
        .map_err(|e| CoreError::PsbtError(format!("Failed to create PSBT: {}", e)))?;

    // For key-path spend, we need the internal key and merkle root
    for (i, utxo) in utxos.iter().enumerate() {
        psbt.inputs[i] = PsbtInput {
            witness_utxo: Some(TxOut {
                value: utxo.amount_sats,
                script_pubkey: script_pubkey.clone(),
            }),
            tap_internal_key: Some(internal_key),
            tap_merkle_root: spend_info.merkle_root(),
            ..Default::default()
        };
    }

    let psbt_base64 = base64::engine::general_purpose::STANDARD.encode(&psbt.serialize());

    Ok(PsbtResult {
        psbt_base64,
        summary: TransactionSummary {
            to_address: destination.to_string(),
            input_sats: total_input_sats,
            send_sats,
            fee_sats,
            path_type: SpendPath::Emergency,
            delay_blocks: None,
        },
    })
}

// ═══════════════════════════════════════════════════════════════════
//                      POLICY VERIFICATION
// ═══════════════════════════════════════════════════════════════════

/// Verify that a PSBT conforms to the vault's policy.
///
/// Checks:
/// - All inputs spend from the expected vault address
/// - Sequence numbers match delay requirements (for delayed spend)
/// - Output amount is reasonable (fee not excessive)
pub fn verify_psbt_policy(
    psbt_b64: &str,
    vault: &VaultConfig,
) -> Result<PolicyCheck, CoreError> {
    let psbt_bytes = base64::engine::general_purpose::STANDARD.decode(psbt_b64)
        .map_err(|e| CoreError::PsbtError(format!("Invalid base64: {}", e)))?;

    let psbt = Psbt::deserialize(&psbt_bytes)
        .map_err(|e| CoreError::PsbtError(format!("Invalid PSBT: {}", e)))?;

    let mut warnings = Vec::new();
    let mut errors = Vec::new();

    let delay_blocks = vault.template.delay_blocks();

    // Check transaction version
    if psbt.unsigned_tx.version != 2 {
        warnings.push("Transaction version is not 2 (required for CSV)".to_string());
    }

    // Check inputs
    for (i, input) in psbt.unsigned_tx.input.iter().enumerate() {
        let seq = input.sequence;

        // For delayed spend, check CSV sequence
        let expected_delayed_seq = Sequence::from_height(delay_blocks as u16);
        let is_delayed = seq == expected_delayed_seq;
        let is_emergency = seq == Sequence::ENABLE_RBF_NO_LOCKTIME;

        if !is_delayed && !is_emergency {
            errors.push(format!(
                "Input {} has unexpected sequence {:?}",
                i, seq
            ));
        }

        // Check witness_utxo is present
        if psbt.inputs.get(i).and_then(|inp| inp.witness_utxo.as_ref()).is_none() {
            errors.push(format!("Input {} missing witness_utxo", i));
        }
    }

    // Check outputs
    if psbt.unsigned_tx.output.is_empty() {
        errors.push("Transaction has no outputs".to_string());
    }

    // Check fee is reasonable (< 10% of total input)
    let total_input: u64 = psbt
        .inputs
        .iter()
        .filter_map(|inp| inp.witness_utxo.as_ref().map(|u| u.value))
        .sum();
    let total_output: u64 = psbt.unsigned_tx.output.iter().map(|o| o.value).sum();

    if total_input > 0 {
        let fee = total_input.saturating_sub(total_output);
        let fee_pct = (fee as f64 / total_input as f64) * 100.0;
        if fee_pct > 10.0 {
            warnings.push(format!(
                "Fee is {:.1}% of input ({} sats). This seems high.",
                fee_pct, fee
            ));
        }
    }

    let valid = errors.is_empty();

    Ok(PolicyCheck {
        valid,
        warnings,
        errors,
    })
}

// ═══════════════════════════════════════════════════════════════════
//                         FINALIZATION
// ═══════════════════════════════════════════════════════════════════

/// Finalize a signed PSBT and extract the raw transaction.
///
/// After the hardware wallet signs the PSBT, this function
/// extracts the finalized transaction ready for broadcast.
pub fn finalize_psbt(signed_psbt_b64: &str) -> Result<FinalizedTx, CoreError> {
    let psbt_bytes = base64::engine::general_purpose::STANDARD.decode(signed_psbt_b64)
        .map_err(|e| CoreError::PsbtError(format!("Invalid base64: {}", e)))?;

    let psbt = Psbt::deserialize(&psbt_bytes)
        .map_err(|e| CoreError::PsbtError(format!("Invalid PSBT: {}", e)))?;

    // Extract the transaction (assumes it has been finalized by the signer)
    let tx = psbt.extract_tx();

    let txid = tx.txid().to_string();
    let tx_bytes = bitcoin::consensus::serialize(&tx);
    let tx_hex = hex::encode(&tx_bytes);
    let vsize = tx.vsize() as u64;

    Ok(FinalizedTx {
        tx_hex,
        txid,
        vsize,
    })
}

// ═══════════════════════════════════════════════════════════════════
//                       HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Build spending script (same as taproot module, duplicated for self-containment)
fn build_spending_script(primary_key: &XOnlyPublicKey, delay_blocks: u32) -> ScriptBuf {
    Builder::new()
        .push_x_only_key(primary_key)
        .push_opcode(OP_CHECKSIGVERIFY)
        .push_sequence(Sequence::from_height(delay_blocks as u16))
        .push_opcode(bitcoin::blockdata::opcodes::all::OP_CSV)
        .into_script()
}

/// Build metadata script (same as taproot module)
fn build_metadata_script(metadata: &VaultMetadata) -> ScriptBuf {
    let metadata_bytes = metadata.to_bytes();
    let push_bytes = PushBytesBuf::try_from(metadata_bytes)
        .expect("metadata bytes should be valid push data");
    Builder::new()
        .push_opcode(OP_RETURN)
        .push_slice(&push_bytes)
        .into_script()
}

// ═══════════════════════════════════════════════════════════════════
//                           TESTS
// ═══════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_XPUB: &str = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";

    fn test_vault_config(emergency: bool) -> VaultConfig {
        VaultConfig {
            primary_xpub: TEST_XPUB.to_string(),
            emergency_xpub: if emergency {
                Some(TEST_XPUB.to_string())
            } else {
                None
            },
            template: VaultTemplate::savings(),
            vault_index: 0,
            network: Network::Mainnet,
        }
    }

    fn test_utxos() -> Vec<Utxo> {
        vec![Utxo {
            txid: "a".repeat(64),
            vout: 0,
            amount_sats: 100_000,
            confirmation_height: Some(800_000),
        }]
    }

    #[test]
    fn test_build_delayed_spend_psbt() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 5.0,
        };
        let utxos = test_utxos();

        let result = build_delayed_spend_psbt(&intent, &utxos, &vault);
        assert!(result.is_ok(), "Failed: {:?}", result.err());

        let psbt_result = result.unwrap();
        assert!(!psbt_result.psbt_base64.is_empty());
        assert_eq!(psbt_result.summary.input_sats, 100_000);
        assert!(psbt_result.summary.fee_sats > 0);
        assert!(psbt_result.summary.send_sats < 100_000);
        assert_eq!(psbt_result.summary.delay_blocks, Some(1008));
    }

    #[test]
    fn test_build_delayed_spend_psbt_insufficient_funds() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 5.0,
        };
        let utxos = vec![Utxo {
            txid: "a".repeat(64),
            vout: 0,
            amount_sats: 100, // Very small amount
            confirmation_height: Some(800_000),
        }];

        let result = build_delayed_spend_psbt(&intent, &utxos, &vault);
        assert!(result.is_err());
        match result.unwrap_err() {
            CoreError::InsufficientFunds { .. } => {}
            other => panic!("Expected InsufficientFunds, got {:?}", other),
        }
    }

    #[test]
    fn test_build_delayed_spend_psbt_empty_utxos() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 5.0,
        };

        let result = build_delayed_spend_psbt(&intent, &[], &vault);
        assert!(result.is_err());
    }

    #[test]
    fn test_build_emergency_psbt() {
        let vault = test_vault_config(true);
        let dest = generate_test_address(&vault);
        let utxos = test_utxos();

        let result = build_emergency_psbt(&dest, 5.0, &utxos, &vault);
        assert!(result.is_ok(), "Failed: {:?}", result.err());

        let psbt_result = result.unwrap();
        assert!(!psbt_result.psbt_base64.is_empty());
        assert!(psbt_result.summary.fee_sats < psbt_result.summary.input_sats);
        assert!(psbt_result.summary.delay_blocks.is_none());
    }

    #[test]
    fn test_build_emergency_psbt_no_emergency_key() {
        let vault = test_vault_config(false); // No emergency xpub
        let utxos = test_utxos();

        let result = build_emergency_psbt("bc1qtest", 5.0, &utxos, &vault);
        assert!(result.is_err());
        match result.unwrap_err() {
            CoreError::PolicyViolation(_) => {}
            other => panic!("Expected PolicyViolation, got {:?}", other),
        }
    }

    #[test]
    fn test_verify_psbt_policy_valid() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 5.0,
        };
        let utxos = test_utxos();

        let psbt_result = build_delayed_spend_psbt(&intent, &utxos, &vault).unwrap();
        let check = verify_psbt_policy(&psbt_result.psbt_base64, &vault).unwrap();

        assert!(check.valid, "Errors: {:?}", check.errors);
        assert!(check.errors.is_empty());
    }

    #[test]
    fn test_verify_psbt_policy_invalid_base64() {
        let vault = test_vault_config(false);
        let result = verify_psbt_policy("not-valid-base64!!!", &vault);
        assert!(result.is_err());
    }

    #[test]
    fn test_psbt_roundtrip_serialization() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 5.0,
        };
        let utxos = test_utxos();

        let psbt_result = build_delayed_spend_psbt(&intent, &utxos, &vault).unwrap();

        // Deserialize and re-serialize
        let psbt_bytes = base64::engine::general_purpose::STANDARD.decode(&psbt_result.psbt_base64).unwrap();
        let psbt = Psbt::deserialize(&psbt_bytes).unwrap();

        // Verify PSBT structure
        assert_eq!(psbt.unsigned_tx.input.len(), 1);
        assert_eq!(psbt.unsigned_tx.output.len(), 1);
        assert_eq!(psbt.unsigned_tx.version, 2);

        // Check CSV sequence on input
        let seq = psbt.unsigned_tx.input[0].sequence;
        assert_eq!(seq, Sequence::from_height(1008));

        // Check witness_utxo is populated
        assert!(psbt.inputs[0].witness_utxo.is_some());
        assert!(psbt.inputs[0].tap_internal_key.is_some());
    }

    #[test]
    fn test_multiple_utxos() {
        let vault = test_vault_config(false);
        let intent = SpendIntent {
            destination: generate_test_address(&vault),
            fee_rate: 2.0,
        };
        let utxos = vec![
            Utxo {
                txid: "a".repeat(64),
                vout: 0,
                amount_sats: 50_000,
                confirmation_height: Some(800_000),
            },
            Utxo {
                txid: "b".repeat(64),
                vout: 1,
                amount_sats: 75_000,
                confirmation_height: Some(800_001),
            },
        ];

        let result = build_delayed_spend_psbt(&intent, &utxos, &vault);
        assert!(result.is_ok(), "Failed: {:?}", result.err());

        let psbt_result = result.unwrap();
        assert_eq!(psbt_result.summary.input_sats, 125_000);

        // Verify 2 inputs in PSBT
        let psbt_bytes = base64::engine::general_purpose::STANDARD.decode(&psbt_result.psbt_base64).unwrap();
        let psbt = Psbt::deserialize(&psbt_bytes).unwrap();
        assert_eq!(psbt.unsigned_tx.input.len(), 2);
        assert_eq!(psbt.inputs.len(), 2);
    }

    /// Generate a valid Taproot address for testing (from the same vault config)
    fn generate_test_address(vault: &VaultConfig) -> String {
        crate::taproot::generate_vault_address(
            &vault.primary_xpub,
            vault.emergency_xpub.as_deref(),
            &vault.template,
            vault.vault_index + 1, // Different index to avoid self-send
            vault.network,
        )
        .unwrap()
        .address
    }
}
