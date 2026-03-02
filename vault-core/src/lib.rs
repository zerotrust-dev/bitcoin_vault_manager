use std::ffi::CString;
use std::os::raw::c_char;

// Module declarations
pub mod error;
pub mod ffi;
pub mod keys;
pub mod taproot;
pub mod transaction;
pub mod vault;

// Re-exports for convenience
pub use error::{CoreError, CoreResult};
pub use vault::{Network, VaultTemplate, VaultMetadata, RecoveryType};

// ═══════════════════════════════════════════════════════════════════
//                      INITIALIZATION FFI
// ═══════════════════════════════════════════════════════════════════

/// Get library version
///
/// Returns the semantic version of the vault-core library.
/// The returned string must be freed using `free_rust_string()`.
///
/// # Safety
/// This function is safe to call from any context.
#[no_mangle]
pub extern "C" fn vault_version() -> *mut c_char {
    ffi::to_c_string(env!("CARGO_PKG_VERSION"))
}

/// Initialize library with network
///
/// # Arguments
/// * `network` - Network selection (0=mainnet, 1=testnet, 2=signet, 3=regtest)
///
/// # Returns
/// * `0` on success
/// * `-1` on invalid network
///
/// # Safety
/// This function is safe to call from any context.
#[no_mangle]
pub extern "C" fn vault_init(network: i32) -> i32 {
    match Network::try_from(network) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Free a string allocated by Rust
///
/// # Safety
/// - `ptr` must be a valid pointer returned from a Rust FFI function, or null
/// - `ptr` must not be used after calling this function
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

// ═══════════════════════════════════════════════════════════════════
//                       KEY DERIVATION FFI
// ═══════════════════════════════════════════════════════════════════

/// Validate an xpub string
///
/// # Arguments
/// * `xpub` - Extended public key string (xpub... or tpub...)
/// * `network` - Network (0=mainnet, 1=testnet, 2=signet, 3=regtest)
///
/// # Returns
/// JSON string: `{"xpub":"...","fingerprint":"...","network":"...","supports_taproot":true}`
/// or error JSON: `{"error":true,"code":...,"message":"..."}`
///
/// # Safety
/// `xpub` must be a valid null-terminated C string.
#[no_mangle]
pub extern "C" fn ffi_validate_xpub(xpub: *const c_char, network: i32) -> *mut c_char {
    let xpub_str = match ffi::from_c_string(xpub) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let net = match Network::try_from(network) {
        Ok(n) => n,
        Err(e) => return ffi::error_response(e),
    };

    match keys::validate_xpub(&xpub_str, net) {
        Ok(info) => ffi::success_response(info),
        Err(e) => ffi::error_response(e),
    }
}

/// Get BIP86 derivation path for a vault index
///
/// # Arguments
/// * `vault_index` - Vault derivation index
/// * `network` - Network (0=mainnet, 1=testnet, 2=signet, 3=regtest)
///
/// # Returns
/// Path string like "m/86'/0'/0'/0/0". Must be freed with `free_rust_string()`.
///
/// # Safety
/// This function is safe to call from any context.
#[no_mangle]
pub extern "C" fn ffi_get_derivation_path(vault_index: u32, network: i32) -> *mut c_char {
    let net = match Network::try_from(network) {
        Ok(n) => n,
        Err(e) => return ffi::error_response(e),
    };
    ffi::to_c_string(&keys::get_derivation_path(vault_index, net))
}

// ═══════════════════════════════════════════════════════════════════
//                     VAULT ADDRESS FFI
// ═══════════════════════════════════════════════════════════════════

/// Generate a Taproot vault address with embedded metadata
///
/// # Arguments
/// * `params_json` - JSON: `{"primary_xpub":"...","emergency_xpub":"...","template":{...},"vault_index":0}`
/// * `network` - Network (0=mainnet, 1=testnet, 2=signet, 3=regtest)
///
/// # Returns
/// JSON with address, internal_key, scripts, metadata. Must be freed with `free_rust_string()`.
///
/// # Safety
/// `params_json` must be a valid null-terminated C string.
#[no_mangle]
pub extern "C" fn ffi_generate_vault_address(
    params_json: *const c_char,
    network: i32,
) -> *mut c_char {
    let params_str = match ffi::from_c_string(params_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let net = match Network::try_from(network) {
        Ok(n) => n,
        Err(e) => return ffi::error_response(e),
    };

    #[derive(serde::Deserialize)]
    struct Params {
        primary_xpub: String,
        emergency_xpub: Option<String>,
        template: VaultTemplate,
        vault_index: u32,
    }

    let params: Params = match serde_json::from_str(&params_str) {
        Ok(p) => p,
        Err(e) => {
            return ffi::error_response(CoreError::InvalidInput(format!(
                "Invalid params JSON: {}",
                e
            )))
        }
    };

    match taproot::generate_vault_address(
        &params.primary_xpub,
        params.emergency_xpub.as_deref(),
        &params.template,
        params.vault_index,
        net,
    ) {
        Ok(result) => ffi::success_response(result),
        Err(e) => ffi::error_response(e),
    }
}

/// Validate a Bitcoin address for a given network
///
/// # Arguments
/// * `address` - Bitcoin address string
/// * `network` - Network (0=mainnet, 1=testnet, 2=signet, 3=regtest)
///
/// # Returns
/// JSON: `{"valid":true}` or error JSON
///
/// # Safety
/// `address` must be a valid null-terminated C string.
#[no_mangle]
pub extern "C" fn ffi_validate_address(address: *const c_char, network: i32) -> *mut c_char {
    let addr_str = match ffi::from_c_string(address) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let net = match Network::try_from(network) {
        Ok(n) => n,
        Err(e) => return ffi::error_response(e),
    };

    match taproot::validate_address(&addr_str, net) {
        Ok(valid) => ffi::success_response(serde_json::json!({ "valid": valid })),
        Err(e) => ffi::error_response(e),
    }
}

/// Decode metadata from a Taproot metadata script leaf
///
/// # Arguments
/// * `script_hex` - Hex-encoded metadata script
///
/// # Returns
/// JSON VaultMetadata or error JSON
///
/// # Safety
/// `script_hex` must be a valid null-terminated C string.
#[no_mangle]
pub extern "C" fn ffi_decode_metadata_leaf(script_hex: *const c_char) -> *mut c_char {
    let hex_str = match ffi::from_c_string(script_hex) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };

    match taproot::decode_metadata_from_script(&hex_str) {
        Ok(metadata) => ffi::success_response(metadata),
        Err(e) => ffi::error_response(e),
    }
}

// ═══════════════════════════════════════════════════════════════════
//                    TRANSACTION BUILDING FFI
// ═══════════════════════════════════════════════════════════════════

/// Build PSBT for delayed spend (script-path with CSV timelock)
///
/// # Arguments
/// * `intent_json` - JSON SpendIntent: `{"destination":"...","fee_rate":5.0}`
/// * `utxos_json` - JSON array of Utxo: `[{"txid":"...","vout":0,"amount_sats":100000}]`
/// * `vault_json` - JSON VaultConfig
///
/// # Returns
/// JSON PsbtResult with base64 PSBT and summary. Must be freed with `free_rust_string()`.
///
/// # Safety
/// All pointer arguments must be valid null-terminated C strings.
#[no_mangle]
pub extern "C" fn ffi_build_delayed_spend_psbt(
    intent_json: *const c_char,
    utxos_json: *const c_char,
    vault_json: *const c_char,
) -> *mut c_char {
    let intent_str = match ffi::from_c_string(intent_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let utxos_str = match ffi::from_c_string(utxos_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let vault_str = match ffi::from_c_string(vault_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };

    let intent: transaction::SpendIntent = match serde_json::from_str(&intent_str) {
        Ok(i) => i,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid intent: {}", e))),
    };
    let utxos: Vec<transaction::Utxo> = match serde_json::from_str(&utxos_str) {
        Ok(u) => u,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid utxos: {}", e))),
    };
    let vault: transaction::VaultConfig = match serde_json::from_str(&vault_str) {
        Ok(v) => v,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid vault: {}", e))),
    };

    match transaction::build_delayed_spend_psbt(&intent, &utxos, &vault) {
        Ok(result) => ffi::success_response(result),
        Err(e) => ffi::error_response(e),
    }
}

/// Build PSBT for emergency key-path spend (no delay)
///
/// # Arguments
/// * `params_json` - JSON: `{"destination":"...","fee_rate":5.0}`
/// * `utxos_json` - JSON array of Utxo
/// * `vault_json` - JSON VaultConfig
///
/// # Returns
/// JSON PsbtResult. Must be freed with `free_rust_string()`.
///
/// # Safety
/// All pointer arguments must be valid null-terminated C strings.
#[no_mangle]
pub extern "C" fn ffi_build_emergency_psbt(
    params_json: *const c_char,
    utxos_json: *const c_char,
    vault_json: *const c_char,
) -> *mut c_char {
    let params_str = match ffi::from_c_string(params_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let utxos_str = match ffi::from_c_string(utxos_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let vault_str = match ffi::from_c_string(vault_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };

    #[derive(serde::Deserialize)]
    struct Params {
        destination: String,
        fee_rate: f64,
    }

    let params: Params = match serde_json::from_str(&params_str) {
        Ok(p) => p,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid params: {}", e))),
    };
    let utxos: Vec<transaction::Utxo> = match serde_json::from_str(&utxos_str) {
        Ok(u) => u,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid utxos: {}", e))),
    };
    let vault: transaction::VaultConfig = match serde_json::from_str(&vault_str) {
        Ok(v) => v,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid vault: {}", e))),
    };

    match transaction::build_emergency_psbt(&params.destination, params.fee_rate, &utxos, &vault) {
        Ok(result) => ffi::success_response(result),
        Err(e) => ffi::error_response(e),
    }
}

/// Verify PSBT matches vault policy
///
/// # Arguments
/// * `psbt_base64` - Base64-encoded PSBT
/// * `vault_json` - JSON VaultConfig
///
/// # Returns
/// JSON PolicyCheck: `{"valid":true,"warnings":[],"errors":[]}`
///
/// # Safety
/// All pointer arguments must be valid null-terminated C strings.
#[no_mangle]
pub extern "C" fn ffi_verify_psbt_policy(
    psbt_base64: *const c_char,
    vault_json: *const c_char,
) -> *mut c_char {
    let psbt_str = match ffi::from_c_string(psbt_base64) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };
    let vault_str = match ffi::from_c_string(vault_json) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };

    let vault: transaction::VaultConfig = match serde_json::from_str(&vault_str) {
        Ok(v) => v,
        Err(e) => return ffi::error_response(CoreError::InvalidInput(format!("Invalid vault: {}", e))),
    };

    match transaction::verify_psbt_policy(&psbt_str, &vault) {
        Ok(check) => ffi::success_response(check),
        Err(e) => ffi::error_response(e),
    }
}

/// Finalize a signed PSBT and extract raw transaction
///
/// # Arguments
/// * `signed_psbt_base64` - Base64-encoded signed PSBT
///
/// # Returns
/// JSON: `{"tx_hex":"...","txid":"...","vsize":...}`
///
/// # Safety
/// `signed_psbt_base64` must be a valid null-terminated C string.
#[no_mangle]
pub extern "C" fn ffi_finalize_psbt(signed_psbt_base64: *const c_char) -> *mut c_char {
    let psbt_str = match ffi::from_c_string(signed_psbt_base64) {
        Ok(s) => s,
        Err(e) => return ffi::error_response(e),
    };

    match transaction::finalize_psbt(&psbt_str) {
        Ok(result) => ffi::success_response(result),
        Err(e) => ffi::error_response(e),
    }
}

// ═══════════════════════════════════════════════════════════════════
//                         UTILITIES FFI
// ═══════════════════════════════════════════════════════════════════

/// Convert block count to estimated time string
///
/// # Arguments
/// * `blocks` - Number of blocks
///
/// # Returns
/// Human-readable time estimate (e.g., "~7 days"). Must be freed with `free_rust_string()`.
///
/// # Safety
/// This function is safe to call from any context.
#[no_mangle]
pub extern "C" fn ffi_blocks_to_time_estimate(blocks: u32) -> *mut c_char {
    let minutes = blocks as u64 * 10;
    let estimate = if minutes < 60 {
        format!("~{} minutes", minutes)
    } else if minutes < 1440 {
        let hours = minutes / 60;
        format!("~{} hour{}", hours, if hours == 1 { "" } else { "s" })
    } else {
        let days = minutes / 1440;
        format!("~{} day{}", days, if days == 1 { "" } else { "s" })
    };
    ffi::to_c_string(&estimate)
}

/// Calculate the absolute block height when a CSV timelock unlocks
///
/// # Arguments
/// * `current_height` - Current blockchain height
/// * `delay_blocks` - CSV delay in blocks
///
/// # Returns
/// The block height at which spending becomes possible.
#[no_mangle]
pub extern "C" fn ffi_calculate_unlock_height(current_height: u32, delay_blocks: u32) -> u32 {
    current_height.saturating_add(delay_blocks)
}

// ═══════════════════════════════════════════════════════════════════
//                         UNIT TESTS
// ═══════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_vault_version() {
        let version_ptr = vault_version();
        assert!(!version_ptr.is_null());

        unsafe {
            let version_cstr = CStr::from_ptr(version_ptr);
            let version = version_cstr.to_str().unwrap();

            assert!(version.contains('.'));
            assert_eq!(version, env!("CARGO_PKG_VERSION"));

            free_rust_string(version_ptr);
        }
    }

    #[test]
    fn test_vault_init_valid_networks() {
        assert_eq!(vault_init(0), 0);
        assert_eq!(vault_init(1), 0);
        assert_eq!(vault_init(2), 0);
        assert_eq!(vault_init(3), 0);
    }

    #[test]
    fn test_vault_init_invalid_network() {
        assert_eq!(vault_init(4), -1);
        assert_eq!(vault_init(-1), -1);
        assert_eq!(vault_init(999), -1);
    }

    #[test]
    fn test_free_rust_string_null_is_safe() {
        free_rust_string(std::ptr::null_mut());
    }

    #[test]
    fn test_blocks_to_time_estimate() {
        unsafe {
            // 6 blocks = ~60 minutes = ~1 hour
            let ptr = ffi_blocks_to_time_estimate(6);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "~1 hour");
            free_rust_string(ptr);

            // 144 blocks = ~1 day
            let ptr = ffi_blocks_to_time_estimate(144);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "~1 day");
            free_rust_string(ptr);

            // 1008 blocks = ~7 days
            let ptr = ffi_blocks_to_time_estimate(1008);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "~7 days");
            free_rust_string(ptr);

            // 3 blocks = ~30 minutes
            let ptr = ffi_blocks_to_time_estimate(3);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "~30 minutes");
            free_rust_string(ptr);
        }
    }

    #[test]
    fn test_calculate_unlock_height() {
        assert_eq!(ffi_calculate_unlock_height(800_000, 1008), 801_008);
        assert_eq!(ffi_calculate_unlock_height(800_000, 144), 800_144);
        assert_eq!(ffi_calculate_unlock_height(u32::MAX, 1), u32::MAX); // saturating
    }

    #[test]
    fn test_ffi_validate_xpub() {
        let xpub = std::ffi::CString::new(
            "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
        ).unwrap();

        unsafe {
            let result_ptr = ffi_validate_xpub(xpub.as_ptr(), 0);
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            let result: serde_json::Value = serde_json::from_str(result_str).unwrap();

            assert!(result.get("error").is_none());
            assert_eq!(result["fingerprint"], "3442193e");
            assert_eq!(result["supports_taproot"], true);

            free_rust_string(result_ptr);
        }
    }

    #[test]
    fn test_ffi_get_derivation_path() {
        unsafe {
            let ptr = ffi_get_derivation_path(0, 0);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "m/86'/0'/0'/0/0");
            free_rust_string(ptr);

            let ptr = ffi_get_derivation_path(5, 1);
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "m/86'/1'/0'/0/5");
            free_rust_string(ptr);
        }
    }

    #[test]
    fn test_ffi_generate_vault_address() {
        let params = serde_json::json!({
            "primary_xpub": "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
            "template": {"type": "savings"},
            "vault_index": 0
        });
        let params_cstr = std::ffi::CString::new(params.to_string()).unwrap();

        unsafe {
            let result_ptr = ffi_generate_vault_address(params_cstr.as_ptr(), 0);
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            let result: serde_json::Value = serde_json::from_str(result_str).unwrap();

            assert!(result.get("error").is_none(), "Got error: {}", result_str);
            assert!(result["address"].as_str().unwrap().starts_with("bc1p"));

            free_rust_string(result_ptr);
        }
    }
}
