use std::ffi::CString;
use std::os::raw::c_char;

// Module declarations
pub mod error;
pub mod ffi;
pub mod keys;
pub mod taproot;
pub mod vault;

// Re-exports for convenience
pub use error::{CoreError, CoreResult};
pub use vault::{Network, VaultTemplate, VaultMetadata, RecoveryType};

// ═══════════════════════════════════════════════════════════════════
//                         FFI EXPORTS
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
        Ok(_) => 0,  // Success
        Err(_) => -1, // Invalid network
    }
}

/// Free a string allocated by Rust
///
/// Must be called for every string returned by FFI functions to prevent memory leaks.
///
/// # Arguments
/// * `ptr` - Pointer to string allocated by Rust
///
/// # Safety
/// - `ptr` must be a valid pointer returned from a Rust FFI function
/// - `ptr` must not be used after calling this function
/// - Passing a null pointer is safe (no-op)
/// - Passing an invalid pointer causes undefined behavior
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

            // Should be a valid semver string
            assert!(version.contains('.'));
            assert_eq!(version, env!("CARGO_PKG_VERSION"));

            free_rust_string(version_ptr);
        }
    }

    #[test]
    fn test_vault_init_valid_networks() {
        assert_eq!(vault_init(0), 0); // Mainnet
        assert_eq!(vault_init(1), 0); // Testnet
        assert_eq!(vault_init(2), 0); // Signet
        assert_eq!(vault_init(3), 0); // Regtest
    }

    #[test]
    fn test_vault_init_invalid_network() {
        assert_eq!(vault_init(4), -1);
        assert_eq!(vault_init(-1), -1);
        assert_eq!(vault_init(999), -1);
    }

    #[test]
    fn test_free_rust_string_null_is_safe() {
        // Should not crash
        free_rust_string(std::ptr::null_mut());
    }
}
