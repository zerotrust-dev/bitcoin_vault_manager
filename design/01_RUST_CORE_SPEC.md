# Rust Core Library Specification

## Overview

The `vault-core` Rust library is the cryptographic heart of Freedom Wallet. It handles all sensitive Bitcoin operations and is exposed to the Flutter app via FFI. This library must be auditable, reproducibly built, and never expose raw private keys.

---

## Repository Structure

```
vault-core/
├── Cargo.toml
├── src/
│   ├── lib.rs                 # Main library entry, FFI exports
│   ├── ffi/
│   │   ├── mod.rs             # FFI module exports
│   │   ├── types.rs           # C-compatible types
│   │   └── strings.rs         # String handling utilities
│   ├── keys/
│   │   ├── mod.rs
│   │   ├── derivation.rs      # BIP32/39 key derivation
│   │   └── xpub.rs            # Extended public key handling
│   ├── taproot/
│   │   ├── mod.rs
│   │   ├── address.rs         # Taproot address generation
│   │   ├── script.rs          # Script tree construction
│   │   └── metadata.rs        # Metadata leaf encoding
│   ├── vault/
│   │   ├── mod.rs
│   │   ├── template.rs        # Vault templates (savings, spending)
│   │   ├── config.rs          # Vault configuration
│   │   └── descriptor.rs      # Output descriptors
│   ├── transaction/
│   │   ├── mod.rs
│   │   ├── psbt.rs            # PSBT building
│   │   ├── spend.rs           # Delayed spend transactions
│   │   ├── cancel.rs          # Cancel transactions
│   │   └── emergency.rs       # Emergency recovery
│   ├── recovery/
│   │   ├── mod.rs
│   │   ├── scan.rs            # Blockchain scanning
│   │   └── reconstruct.rs     # Vault reconstruction
│   └── util/
│       ├── mod.rs
│       ├── encoding.rs        # Encoding utilities
│       └── validation.rs      # Input validation
├── build_android.sh           # Android .so build script
├── build_ios.sh               # iOS framework build script
├── build_desktop.ps1          # Windows .dll build script
└── build_desktop.sh           # Linux/Mac build script
```

---

## Dependencies

```toml
# Cargo.toml
[package]
name = "vault-core"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
# Bitcoin Core
bdk = { version = "1.0", features = ["keys-bip39"] }
bitcoin = "0.31"
miniscript = "11.0"
secp256k1 = { version = "0.28", features = ["global-context"] }

# Key Management
bip39 = "2.0"

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# FFI
libc = "0.2"

# Error Handling
thiserror = "1.0"

# Encoding
hex = "0.4"
base64 = "0.21"

[dev-dependencies]
tokio = { version = "1", features = ["full"] }
```

---

## Core Types

### Network Configuration

```rust
/// Bitcoin network selection
#[repr(C)]
pub enum Network {
    Mainnet = 0,
    Testnet = 1,
    Signet = 2,
    Regtest = 3,
}

impl From<Network> for bitcoin::Network {
    fn from(n: Network) -> Self {
        match n {
            Network::Mainnet => bitcoin::Network::Bitcoin,
            Network::Testnet => bitcoin::Network::Testnet,
            Network::Signet => bitcoin::Network::Signet,
            Network::Regtest => bitcoin::Network::Regtest,
        }
    }
}
```

### Vault Templates

```rust
/// Pre-defined vault security templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VaultTemplate {
    /// High security savings vault (1 week delay)
    Savings {
        delay_blocks: u32,  // Default: 1008 (1 week)
    },
    /// Medium security spending vault (1 day delay)
    Spending {
        delay_blocks: u32,  // Default: 144 (1 day)
    },
    /// Custom configuration
    Custom {
        delay_blocks: u32,
        recovery_type: RecoveryType,
    },
}

impl VaultTemplate {
    pub fn savings() -> Self {
        VaultTemplate::Savings { delay_blocks: 1008 }
    }
    
    pub fn spending() -> Self {
        VaultTemplate::Spending { delay_blocks: 144 }
    }
    
    pub fn delay_blocks(&self) -> u32 {
        match self {
            VaultTemplate::Savings { delay_blocks } => *delay_blocks,
            VaultTemplate::Spending { delay_blocks } => *delay_blocks,
            VaultTemplate::Custom { delay_blocks, .. } => *delay_blocks,
        }
    }
}
```

### Vault Metadata (Blockchain-Encoded)

```rust
/// Metadata encoded in Taproot script leaf for recovery
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultMetadata {
    /// Schema version for future compatibility
    pub version: u8,
    
    /// Template identifier
    pub template_id: String,
    
    /// Delay in blocks before spend completes
    pub delay_blocks: u32,
    
    /// Indices into approved destinations list
    pub destination_indices: Vec<u8>,
    
    /// Recovery mechanism type
    pub recovery_type: RecoveryType,
    
    /// Creation timestamp (block height)
    pub created_at_block: u32,
    
    /// Derivation index for this vault
    pub vault_index: u32,
}

impl VaultMetadata {
    /// Encode metadata to bytes for script leaf
    pub fn to_bytes(&self) -> Vec<u8> {
        // Compact binary encoding
        let mut bytes = Vec::new();
        bytes.push(self.version);
        // ... encoding logic
        bytes
    }
    
    /// Decode metadata from script leaf bytes
    pub fn from_bytes(data: &[u8]) -> Result<Self, CoreError> {
        // ... decoding logic
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecoveryType {
    /// Use emergency device key-path
    EmergencyKey,
    /// Wait for timelock to expire
    TimelockOnly,
    /// Multi-signature recovery
    MultiSig { threshold: u8, total: u8 },
}
```

### Vault Configuration

```rust
/// Complete vault configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultConfig {
    /// Unique vault identifier (derived from address)
    pub id: String,
    
    /// Human-readable name
    pub name: String,
    
    /// Vault template used
    pub template: VaultTemplate,
    
    /// Primary device xpub (for delayed spending)
    pub primary_xpub: String,
    
    /// Emergency device xpub (for immediate recovery)
    pub emergency_xpub: Option<String>,
    
    /// Bitcoin network
    pub network: Network,
    
    /// Taproot descriptor
    pub descriptor: String,
    
    /// Receive address
    pub address: String,
    
    /// Metadata for recovery
    pub metadata: VaultMetadata,
    
    /// Creation timestamp
    pub created_at: u64,
}
```

### Transaction Types

```rust
/// Spending intent from user
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpendIntent {
    /// Source vault ID
    pub vault_id: String,
    
    /// Destination address
    pub destination: String,
    
    /// Amount in satoshis (None = sweep all)
    pub amount_sats: Option<u64>,
    
    /// Fee rate in sat/vB
    pub fee_rate: f32,
    
    /// Spend path type
    pub path_type: SpendPath,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SpendPath {
    /// Script path with CSV delay
    Delayed,
    /// Key path immediate (emergency only)
    Emergency,
}

/// PSBT wrapper for FFI
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PsbtData {
    /// Base64-encoded PSBT
    pub psbt_base64: String,
    
    /// Human-readable summary
    pub summary: TransactionSummary,
    
    /// Validation status
    pub is_valid: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionSummary {
    pub from_vault: String,
    pub to_address: String,
    pub amount_sats: u64,
    pub fee_sats: u64,
    pub path_type: SpendPath,
    pub delay_blocks: Option<u32>,
    pub estimated_completion: Option<String>,
}
```

---

## FFI Interface

### Exported Functions

```rust
// ═══════════════════════════════════════════════════════════════════
//                         INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

/// Get library version
#[no_mangle]
pub extern "C" fn vault_version() -> *mut c_char {
    to_c_string(env!("CARGO_PKG_VERSION"))
}

/// Initialize library with network
#[no_mangle]
pub extern "C" fn vault_init(network: Network) -> i32 {
    // Returns 0 on success, error code otherwise
}

// ═══════════════════════════════════════════════════════════════════
//                       KEY DERIVATION
// ═══════════════════════════════════════════════════════════════════

/// Derive xpub from hardware wallet response
/// Input: JSON { "master_fingerprint": "...", "xpub": "..." }
/// Output: JSON { "xpub": "...", "fingerprint": "...", "path": "..." }
#[no_mangle]
pub extern "C" fn derive_account_xpub(
    device_response_json: *const c_char,
    network: Network
) -> *mut c_char;

/// Generate BIP32 path for vault derivation
/// Output: "m/86'/0'/0'/0/index"
#[no_mangle]
pub extern "C" fn get_derivation_path(
    vault_index: u32,
    network: Network
) -> *mut c_char;

// ═══════════════════════════════════════════════════════════════════
//                     VAULT CREATION
// ═══════════════════════════════════════════════════════════════════

/// Create new vault from template
/// Input: JSON VaultCreationRequest
/// Output: JSON VaultConfig
#[no_mangle]
pub extern "C" fn create_vault(
    request_json: *const c_char
) -> *mut c_char;

/// Generate Taproot address with embedded metadata
/// Input: JSON { "primary_xpub": "...", "emergency_xpub": "...", "template": "...", "index": 0 }
/// Output: JSON { "address": "bc1p...", "descriptor": "tr(...)", "metadata_leaf": "..." }
#[no_mangle]
pub extern "C" fn generate_vault_address(
    params_json: *const c_char,
    network: Network
) -> *mut c_char;

/// Get vault receive address (for WYSIWYS verification)
#[no_mangle]
pub extern "C" fn get_receive_address(
    vault_config_json: *const c_char
) -> *mut c_char;

// ═══════════════════════════════════════════════════════════════════
//                    TRANSACTION BUILDING
// ═══════════════════════════════════════════════════════════════════

/// Build PSBT for delayed spend
/// Input: JSON SpendIntent
/// Output: JSON PsbtData
#[no_mangle]
pub extern "C" fn build_delayed_spend_psbt(
    intent_json: *const c_char,
    utxos_json: *const c_char
) -> *mut c_char;

/// Build PSBT for emergency recovery (key-path spend)
/// Input: JSON { "vault_id": "...", "destination": "...", "fee_rate": 5.0 }
/// Output: JSON PsbtData
#[no_mangle]
pub extern "C" fn build_emergency_psbt(
    params_json: *const c_char,
    utxos_json: *const c_char
) -> *mut c_char;

/// Build PSBT for cancel transaction
/// Input: JSON { "original_txid": "...", "vault_config": {...}, "fee_rate": 10.0 }
/// Output: JSON PsbtData
#[no_mangle]
pub extern "C" fn build_cancel_psbt(
    params_json: *const c_char
) -> *mut c_char;

/// Verify PSBT matches vault policy
/// Input: PSBT base64 + VaultConfig JSON
/// Output: JSON { "valid": true, "warnings": [], "errors": [] }
#[no_mangle]
pub extern "C" fn verify_psbt_policy(
    psbt_base64: *const c_char,
    vault_config_json: *const c_char
) -> *mut c_char;

/// Finalize signed PSBT for broadcast
/// Input: Signed PSBT base64
/// Output: JSON { "tx_hex": "...", "txid": "...", "size": 250 }
#[no_mangle]
pub extern "C" fn finalize_psbt(
    signed_psbt_base64: *const c_char
) -> *mut c_char;

// ═══════════════════════════════════════════════════════════════════
//                        RECOVERY
// ═══════════════════════════════════════════════════════════════════

/// Derive all possible vault addresses from xpub for scanning
/// Input: JSON { "xpub": "...", "start_index": 0, "count": 100 }
/// Output: JSON [{ "index": 0, "address": "bc1p...", "descriptor": "..." }, ...]
#[no_mangle]
pub extern "C" fn derive_scan_addresses(
    params_json: *const c_char,
    network: Network
) -> *mut c_char;

/// Reconstruct vault from address and blockchain data
/// Input: JSON { "address": "bc1p...", "script_pubkey": "...", "utxos": [...] }
/// Output: JSON VaultConfig (or null if not a vault)
#[no_mangle]
pub extern "C" fn reconstruct_vault(
    blockchain_data_json: *const c_char,
    xpub: *const c_char,
    network: Network
) -> *mut c_char;

/// Decode metadata from Taproot script leaf
/// Input: Script leaf hex
/// Output: JSON VaultMetadata
#[no_mangle]
pub extern "C" fn decode_metadata_leaf(
    script_leaf_hex: *const c_char
) -> *mut c_char;

// ═══════════════════════════════════════════════════════════════════
//                       VALIDATION
// ═══════════════════════════════════════════════════════════════════

/// Validate Bitcoin address
/// Output: JSON { "valid": true, "network": "mainnet", "type": "p2tr" }
#[no_mangle]
pub extern "C" fn validate_address(
    address: *const c_char,
    expected_network: Network
) -> *mut c_char;

/// Validate xpub format
#[no_mangle]
pub extern "C" fn validate_xpub(
    xpub: *const c_char,
    network: Network
) -> *mut c_char;

/// Validate descriptor syntax
#[no_mangle]
pub extern "C" fn validate_descriptor(
    descriptor: *const c_char
) -> *mut c_char;

// ═══════════════════════════════════════════════════════════════════
//                       UTILITIES
// ═══════════════════════════════════════════════════════════════════

/// Convert blocks to estimated time string
/// Input: 1008
/// Output: "~7 days"
#[no_mangle]
pub extern "C" fn blocks_to_time_estimate(
    blocks: u32
) -> *mut c_char;

/// Calculate absolute block height for CSV unlock
/// Input: current_height, delay_blocks
/// Output: unlock_height
#[no_mangle]
pub extern "C" fn calculate_unlock_height(
    current_height: u32,
    delay_blocks: u32
) -> u32;

/// Free allocated C string
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() { return; }
    unsafe { let _ = CString::from_raw(ptr); }
}
```

---

## Taproot Address Generation

### Script Tree Structure

```
                    Taproot Output
                          │
            ┌─────────────┴─────────────┐
            │                           │
      Internal Key              Script Tree Root
    (emergency device)                  │
                          ┌─────────────┴─────────────┐
                          │                           │
                    Spending Leaf             Metadata Leaf
                    (with CSV delay)          (for recovery)
```

### Implementation

```rust
/// Generate complete Taproot address with metadata
pub fn generate_taproot_address(
    primary_xpub: &str,
    emergency_xpub: Option<&str>,
    template: &VaultTemplate,
    vault_index: u32,
    network: Network,
) -> Result<TaprootAddressResult, CoreError> {
    
    // 1. Derive keys
    let primary_key = derive_key_from_xpub(primary_xpub, vault_index)?;
    let emergency_key = emergency_xpub
        .map(|x| derive_key_from_xpub(x, vault_index))
        .transpose()?;
    
    // 2. Create internal key (emergency device for key-path spend)
    let internal_key = emergency_key
        .unwrap_or_else(|| create_unspendable_key());
    
    // 3. Build spending script (with CSV delay)
    let spending_script = build_spending_script(
        &primary_key,
        template.delay_blocks(),
    );
    
    // 4. Build metadata leaf (never-used spending path)
    let metadata = VaultMetadata {
        version: 1,
        template_id: template.id().to_string(),
        delay_blocks: template.delay_blocks(),
        destination_indices: vec![0],
        recovery_type: RecoveryType::EmergencyKey,
        created_at_block: 0, // Set by caller
        vault_index,
    };
    let metadata_script = build_metadata_script(&metadata);
    
    // 5. Build script tree
    let script_tree = TaprootBuilder::new()
        .add_leaf(1, spending_script.clone())?
        .add_leaf(1, metadata_script.clone())?
        .finalize(&secp, internal_key)?;
    
    // 6. Compute Taproot address
    let address = Address::p2tr(
        &secp,
        internal_key,
        script_tree.merkle_root(),
        network.into(),
    );
    
    // 7. Build descriptor
    let descriptor = format!(
        "tr({},{{pk({}),{}}})#checksum",
        internal_key,
        primary_key,
        // ... full descriptor
    );
    
    Ok(TaprootAddressResult {
        address: address.to_string(),
        descriptor,
        internal_key: internal_key.to_string(),
        spending_script: spending_script.to_hex(),
        metadata_script: metadata_script.to_hex(),
        metadata,
    })
}
```

### Spending Script (CSV Delayed)

```rust
/// Build spending script with relative timelock
fn build_spending_script(
    primary_key: &XOnlyPublicKey,
    delay_blocks: u32,
) -> Script {
    // OP_CSV enforces minimum age of UTXO before spending
    // <primary_key> OP_CHECKSIGVERIFY <delay> OP_CSV
    Builder::new()
        .push_x_only_key(primary_key)
        .push_opcode(opcodes::all::OP_CHECKSIGVERIFY)
        .push_int(delay_blocks as i64)
        .push_opcode(opcodes::all::OP_CSV)
        .into_script()
}
```

### Metadata Script (Recovery Information)

```rust
/// Build metadata script (provably unspendable)
fn build_metadata_script(metadata: &VaultMetadata) -> Script {
    // OP_RETURN followed by encoded metadata
    // This script can never be satisfied (OP_RETURN always fails)
    // But the data is committed to the Taproot tree
    let encoded = metadata.to_bytes();
    
    Builder::new()
        .push_opcode(opcodes::all::OP_RETURN)
        .push_slice(&encoded)
        .into_script()
}
```

---

## Error Handling

```rust
#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("Invalid xpub format: {0}")]
    InvalidXpub(String),
    
    #[error("Invalid address: {0}")]
    InvalidAddress(String),
    
    #[error("Invalid network: expected {expected}, got {actual}")]
    NetworkMismatch { expected: String, actual: String },
    
    #[error("PSBT building failed: {0}")]
    PsbtError(String),
    
    #[error("Key derivation failed: {0}")]
    DerivationError(String),
    
    #[error("Invalid metadata encoding: {0}")]
    MetadataError(String),
    
    #[error("Insufficient funds: need {needed} sats, have {available} sats")]
    InsufficientFunds { needed: u64, available: u64 },
    
    #[error("Policy violation: {0}")]
    PolicyViolation(String),
    
    #[error("Serialization error: {0}")]
    SerializationError(String),
}

/// FFI error response
#[derive(Serialize)]
struct ErrorResponse {
    error: bool,
    code: i32,
    message: String,
}
```

---

## Build Scripts

### Windows (PowerShell)

```powershell
# build_desktop.ps1
$ErrorActionPreference = "Stop"

Write-Host "Building vault-core for Windows..."
cargo build --release

$dllPath = "target\release\vault_core.dll"
$outDir = "..\freedom-wallet-app\rust_libs\windows"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force
}

Copy-Item $dllPath "$outDir\vault_core.dll" -Force
Write-Host "DLL copied to $outDir"
```

### Android

```bash
#!/bin/bash
# build_android.sh

set -e

# Ensure cargo-ndk is installed
command -v cargo-ndk >/dev/null 2>&1 || cargo install cargo-ndk

# Build for all Android ABIs
TARGETS="aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android"
OUTPUT_DIR="../freedom-wallet-app/android/app/src/main/jniLibs"

for target in $TARGETS; do
    echo "Building for $target..."
    cargo ndk -t $target build --release
done

# Copy libraries
mkdir -p $OUTPUT_DIR/{arm64-v8a,armeabi-v7a,x86_64,x86}
cp target/aarch64-linux-android/release/libvault_core.so $OUTPUT_DIR/arm64-v8a/
cp target/armv7-linux-androideabi/release/libvault_core.so $OUTPUT_DIR/armeabi-v7a/
cp target/x86_64-linux-android/release/libvault_core.so $OUTPUT_DIR/x86_64/
cp target/i686-linux-android/release/libvault_core.so $OUTPUT_DIR/x86/

echo "Android libraries built and copied"
```

### iOS

```bash
#!/bin/bash
# build_ios.sh

set -e

# Build for iOS simulator and device
cargo build --release --target aarch64-apple-ios
cargo build --release --target x86_64-apple-ios

# Create XCFramework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libvault_core.a \
    -library target/x86_64-apple-ios/release/libvault_core.a \
    -output ../freedom-wallet-app/ios/Frameworks/VaultCore.xcframework

echo "iOS framework created"
```

---

## Testing Strategy

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_vault_address_generation() {
        let result = generate_taproot_address(
            "tpub...",
            Some("tpub..."),
            &VaultTemplate::savings(),
            0,
            Network::Testnet,
        ).unwrap();
        
        assert!(result.address.starts_with("tb1p"));
        assert!(!result.descriptor.is_empty());
    }
    
    #[test]
    fn test_metadata_roundtrip() {
        let metadata = VaultMetadata {
            version: 1,
            template_id: "savings_v1".to_string(),
            delay_blocks: 1008,
            // ...
        };
        
        let encoded = metadata.to_bytes();
        let decoded = VaultMetadata::from_bytes(&encoded).unwrap();
        
        assert_eq!(metadata.version, decoded.version);
        assert_eq!(metadata.delay_blocks, decoded.delay_blocks);
    }
    
    #[test]
    fn test_psbt_building() {
        // ... PSBT construction tests
    }
}
```

### Integration Tests

```rust
// tests/integration_tests.rs

#[test]
fn test_full_vault_lifecycle() {
    // 1. Create vault
    // 2. Generate address
    // 3. Build spend PSBT
    // 4. Verify policy
    // 5. (Mock) Sign
    // 6. Finalize
}

#[test]
fn test_recovery_flow() {
    // 1. Create vault
    // 2. Simulate blockchain data
    // 3. Reconstruct from scan
    // 4. Verify matches original
}
```

---

## Security Considerations

1. **Never expose private keys**: All signing happens on hardware wallet
2. **Validate all inputs**: Check addresses, amounts, networks before processing
3. **Memory safety**: Proper FFI string handling, no memory leaks
4. **Reproducible builds**: Locked dependencies, CI verification
5. **No network access**: Pure library, all I/O through FFI parameters

---

## Version History

| Version | Changes |
|---------|---------|
| 0.1.0 | Initial implementation, basic vault creation |
| 0.2.0 | Add PSBT building, policy verification |
| 0.3.0 | Add recovery scanning, metadata decoding |
| 1.0.0 | Production release, full audit |
