# FFI Interface Specification

## Overview

This document defines the Foreign Function Interface (FFI) between the Rust core library (`vault-core`) and the Flutter application. All communication happens through JSON strings passed via C-compatible function signatures.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Flutter App (Dart)                           │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  RustFfi Class                               │   │
│  │  - Loads native library                                      │   │
│  │  - Wraps FFI calls                                           │   │
│  │  - Handles JSON serialization                                │   │
│  │  - Manages memory (free strings)                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               │ C ABI (JSON strings)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Rust Core Library                            │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  FFI Module (lib.rs)                         │   │
│  │  - #[no_mangle] extern "C" functions                         │   │
│  │  - Receives *const c_char                                    │   │
│  │  - Returns *mut c_char                                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Dart FFI Bridge Implementation

```dart
// lib/data/datasources/rust_ffi_datasource.dart

import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// Native function type definitions
typedef VaultVersionNative = Pointer<Utf8> Function();
typedef VaultVersionDart = Pointer<Utf8> Function();

typedef VaultInitNative = Int32 Function(Int32 network);
typedef VaultInitDart = int Function(int network);

typedef CreateVaultNative = Pointer<Utf8> Function(Pointer<Utf8> requestJson);
typedef CreateVaultDart = Pointer<Utf8> Function(Pointer<Utf8> requestJson);

typedef GenerateAddressNative = Pointer<Utf8> Function(
  Pointer<Utf8> paramsJson, 
  Int32 network
);
typedef GenerateAddressDart = Pointer<Utf8> Function(
  Pointer<Utf8> paramsJson, 
  int network
);

typedef BuildPsbtNative = Pointer<Utf8> Function(
  Pointer<Utf8> intentJson,
  Pointer<Utf8> utxosJson
);
typedef BuildPsbtDart = Pointer<Utf8> Function(
  Pointer<Utf8> intentJson,
  Pointer<Utf8> utxosJson
);

typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

/// FFI bridge to Rust core library
class RustFfi {
  static RustFfi? _instance;
  late final DynamicLibrary _lib;
  
  // Function pointers
  late final VaultVersionDart _vaultVersion;
  late final VaultInitDart _vaultInit;
  late final CreateVaultDart _createVault;
  late final GenerateAddressDart _generateVaultAddress;
  late final BuildPsbtDart _buildDelayedSpendPsbt;
  late final BuildPsbtDart _buildEmergencyPsbt;
  late final FreeStringDart _freeRustString;
  
  /// Singleton instance
  static RustFfi get instance {
    _instance ??= RustFfi._();
    return _instance!;
  }
  
  RustFfi._() {
    _lib = _openLibrary();
    _bindFunctions();
  }
  
  /// Open the native library based on platform
  DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libvault_core.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('vault_core.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libvault_core.dylib');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libvault_core.so');
    }
    throw UnsupportedError('Platform not supported');
  }
  
  /// Bind all FFI functions
  void _bindFunctions() {
    _vaultVersion = _lib
        .lookup<NativeFunction<VaultVersionNative>>('vault_version')
        .asFunction();
    
    _vaultInit = _lib
        .lookup<NativeFunction<VaultInitNative>>('vault_init')
        .asFunction();
    
    _createVault = _lib
        .lookup<NativeFunction<CreateVaultNative>>('create_vault')
        .asFunction();
    
    _generateVaultAddress = _lib
        .lookup<NativeFunction<GenerateAddressNative>>('generate_vault_address')
        .asFunction();
    
    _buildDelayedSpendPsbt = _lib
        .lookup<NativeFunction<BuildPsbtNative>>('build_delayed_spend_psbt')
        .asFunction();
    
    _buildEmergencyPsbt = _lib
        .lookup<NativeFunction<BuildPsbtNative>>('build_emergency_psbt')
        .asFunction();
    
    _freeRustString = _lib
        .lookup<NativeFunction<FreeStringNative>>('free_rust_string')
        .asFunction();
  }
  
  // ═══════════════════════════════════════════════════════════════════
  //                         PUBLIC API
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get library version
  String getVersion() {
    final ptr = _vaultVersion();
    final result = ptr.toDartString();
    _freeRustString(ptr);
    return result;
  }
  
  /// Initialize library with network
  void initialize(Network network) {
    final result = _vaultInit(network.index);
    if (result != 0) {
      throw RustCoreException('Initialization failed with code: $result');
    }
  }
  
  /// Create a new vault
  Future<Vault> createVault(VaultCreationRequest request) async {
    return _callRust(
      () => _createVault(_toNative(request.toJson())),
      (json) => Vault.fromJson(json),
    );
  }
  
  /// Generate vault address with metadata
  Future<TaprootAddressResult> generateVaultAddress({
    required String primaryXpub,
    String? emergencyXpub,
    required VaultTemplate template,
    required int vaultIndex,
    required Network network,
  }) async {
    final params = {
      'primary_xpub': primaryXpub,
      'emergency_xpub': emergencyXpub,
      'template': template.toJson(),
      'vault_index': vaultIndex,
    };
    
    return _callRust(
      () => _generateVaultAddress(_toNative(params), network.index),
      (json) => TaprootAddressResult.fromJson(json),
    );
  }
  
  /// Build PSBT for delayed spend
  Future<PsbtData> buildDelayedSpendPsbt({
    required SpendIntent intent,
    required List<Utxo> utxos,
  }) async {
    return _callRust(
      () => _buildDelayedSpendPsbt(
        _toNative(intent.toJson()),
        _toNative(utxos.map((u) => u.toJson()).toList()),
      ),
      (json) => PsbtData.fromJson(json),
    );
  }
  
  /// Build PSBT for emergency recovery
  Future<PsbtData> buildEmergencyPsbt({
    required String vaultId,
    required String destination,
    required double feeRate,
    required List<Utxo> utxos,
  }) async {
    final params = {
      'vault_id': vaultId,
      'destination': destination,
      'fee_rate': feeRate,
    };
    
    return _callRust(
      () => _buildEmergencyPsbt(
        _toNative(params),
        _toNative(utxos.map((u) => u.toJson()).toList()),
      ),
      (json) => PsbtData.fromJson(json),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  //                         HELPERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Convert Dart object to native string pointer
  Pointer<Utf8> _toNative(Object data) {
    final jsonString = jsonEncode(data);
    return jsonString.toNativeUtf8();
  }
  
  /// Call Rust function with error handling
  T _callRust<T>(
    Pointer<Utf8> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) {
    final ptr = call();
    try {
      final jsonString = ptr.toDartString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Check for error response
      if (json['error'] == true) {
        throw RustCoreException(
          json['message'] as String,
          code: json['code'] as int?,
        );
      }
      
      return parse(json);
    } finally {
      _freeRustString(ptr);
    }
  }
}

/// Exception from Rust core
class RustCoreException implements Exception {
  final String message;
  final int? code;
  
  RustCoreException(this.message, {this.code});
  
  @override
  String toString() => 'RustCoreException: $message (code: $code)';
}
```

---

## Rust FFI Implementation

```rust
// src/lib.rs

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

mod ffi;
mod keys;
mod taproot;
mod vault;
mod transaction;
mod recovery;
mod util;

use crate::ffi::*;
use crate::vault::*;
use crate::taproot::*;
use crate::transaction::*;

// ═══════════════════════════════════════════════════════════════════
//                         STRING HELPERS
// ═══════════════════════════════════════════════════════════════════

/// Convert Rust string to C string pointer
fn to_c_string(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(cs) => cs.into_raw(),
        Err(_) => CString::new("error: invalid string").unwrap().into_raw(),
    }
}

/// Convert C string pointer to Rust string
fn from_c_string(ptr: *const c_char) -> Result<String, CoreError> {
    if ptr.is_null() {
        return Err(CoreError::InvalidInput("null pointer".to_string()));
    }
    unsafe {
        CStr::from_ptr(ptr)
            .to_str()
            .map(|s| s.to_string())
            .map_err(|e| CoreError::InvalidInput(e.to_string()))
    }
}

/// Create JSON error response
fn error_response(error: CoreError) -> *mut c_char {
    let response = serde_json::json!({
        "error": true,
        "code": error.code(),
        "message": error.to_string(),
    });
    to_c_string(&response.to_string())
}

/// Create JSON success response
fn success_response<T: serde::Serialize>(data: T) -> *mut c_char {
    match serde_json::to_string(&data) {
        Ok(json) => to_c_string(&json),
        Err(e) => error_response(CoreError::SerializationError(e.to_string())),
    }
}

// ═══════════════════════════════════════════════════════════════════
//                         EXPORTED FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Get library version
#[no_mangle]
pub extern "C" fn vault_version() -> *mut c_char {
    to_c_string(env!("CARGO_PKG_VERSION"))
}

/// Initialize library with network
#[no_mangle]
pub extern "C" fn vault_init(network: i32) -> i32 {
    // Network: 0=mainnet, 1=testnet, 2=signet, 3=regtest
    match Network::try_from(network) {
        Ok(_) => 0, // Success
        Err(_) => -1, // Invalid network
    }
}

/// Create a new vault
/// Input: JSON VaultCreationRequest
/// Output: JSON Vault
#[no_mangle]
pub extern "C" fn create_vault(request_json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<Vault, CoreError> {
        let json_str = from_c_string(request_json)?;
        let request: VaultCreationRequest = serde_json::from_str(&json_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        
        vault::create_vault(request)
    })();
    
    match result {
        Ok(vault) => success_response(vault),
        Err(e) => error_response(e),
    }
}

/// Generate Taproot address with metadata leaf
/// Input: JSON params
/// Output: JSON TaprootAddressResult
#[no_mangle]
pub extern "C" fn generate_vault_address(
    params_json: *const c_char,
    network: i32,
) -> *mut c_char {
    let result = (|| -> Result<TaprootAddressResult, CoreError> {
        let json_str = from_c_string(params_json)?;
        let params: AddressParams = serde_json::from_str(&json_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        let network = Network::try_from(network)?;
        
        taproot::generate_taproot_address(
            &params.primary_xpub,
            params.emergency_xpub.as_deref(),
            &params.template,
            params.vault_index,
            network,
        )
    })();
    
    match result {
        Ok(addr) => success_response(addr),
        Err(e) => error_response(e),
    }
}

/// Build PSBT for delayed spend
#[no_mangle]
pub extern "C" fn build_delayed_spend_psbt(
    intent_json: *const c_char,
    utxos_json: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<PsbtData, CoreError> {
        let intent_str = from_c_string(intent_json)?;
        let utxos_str = from_c_string(utxos_json)?;
        
        let intent: SpendIntent = serde_json::from_str(&intent_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        let utxos: Vec<Utxo> = serde_json::from_str(&utxos_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        
        transaction::build_delayed_spend_psbt(intent, &utxos)
    })();
    
    match result {
        Ok(psbt) => success_response(psbt),
        Err(e) => error_response(e),
    }
}

/// Build PSBT for emergency recovery
#[no_mangle]
pub extern "C" fn build_emergency_psbt(
    params_json: *const c_char,
    utxos_json: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<PsbtData, CoreError> {
        let params_str = from_c_string(params_json)?;
        let utxos_str = from_c_string(utxos_json)?;
        
        let params: EmergencyParams = serde_json::from_str(&params_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        let utxos: Vec<Utxo> = serde_json::from_str(&utxos_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        
        transaction::build_emergency_psbt(
            &params.vault_id,
            &params.destination,
            params.fee_rate,
            &utxos,
        )
    })();
    
    match result {
        Ok(psbt) => success_response(psbt),
        Err(e) => error_response(e),
    }
}

/// Derive addresses for blockchain scanning
#[no_mangle]
pub extern "C" fn derive_scan_addresses(
    params_json: *const c_char,
    network: i32,
) -> *mut c_char {
    let result = (|| -> Result<Vec<ScanAddress>, CoreError> {
        let params_str = from_c_string(params_json)?;
        let params: ScanParams = serde_json::from_str(&params_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        let network = Network::try_from(network)?;
        
        recovery::derive_scan_addresses(
            &params.xpub,
            params.start_index,
            params.count,
            network,
        )
    })();
    
    match result {
        Ok(addresses) => success_response(addresses),
        Err(e) => error_response(e),
    }
}

/// Decode metadata from script leaf
#[no_mangle]
pub extern "C" fn decode_metadata_leaf(
    script_leaf_hex: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<VaultMetadata, CoreError> {
        let hex_str = from_c_string(script_leaf_hex)?;
        let bytes = hex::decode(&hex_str)
            .map_err(|e| CoreError::InvalidInput(e.to_string()))?;
        
        VaultMetadata::from_bytes(&bytes)
    })();
    
    match result {
        Ok(metadata) => success_response(metadata),
        Err(e) => error_response(e),
    }
}

/// Validate Bitcoin address
#[no_mangle]
pub extern "C" fn validate_address(
    address: *const c_char,
    expected_network: i32,
) -> *mut c_char {
    let result = (|| -> Result<AddressValidation, CoreError> {
        let addr_str = from_c_string(address)?;
        let network = Network::try_from(expected_network)?;
        
        util::validate_address(&addr_str, network)
    })();
    
    match result {
        Ok(validation) => success_response(validation),
        Err(e) => error_response(e),
    }
}

/// Convert blocks to time estimate
#[no_mangle]
pub extern "C" fn blocks_to_time_estimate(blocks: u32) -> *mut c_char {
    let estimate = util::blocks_to_time_string(blocks);
    to_c_string(&estimate)
}

/// Free a string allocated by Rust
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
```

---

## Complete FFI Function Reference

| Function | Input | Output | Description |
|----------|-------|--------|-------------|
| `vault_version` | - | `*char` (string) | Library version |
| `vault_init` | `network: i32` | `i32` (status) | Initialize with network |
| `create_vault` | `request: JSON` | `Vault: JSON` | Create new vault |
| `generate_vault_address` | `params: JSON, network: i32` | `TaprootAddressResult: JSON` | Generate address with metadata |
| `get_receive_address` | `vault_config: JSON` | `address: JSON` | Get receive address |
| `build_delayed_spend_psbt` | `intent: JSON, utxos: JSON` | `PsbtData: JSON` | Build delayed PSBT |
| `build_emergency_psbt` | `params: JSON, utxos: JSON` | `PsbtData: JSON` | Build emergency PSBT |
| `build_cancel_psbt` | `params: JSON` | `PsbtData: JSON` | Build cancel PSBT |
| `verify_psbt_policy` | `psbt: base64, vault: JSON` | `ValidationResult: JSON` | Verify PSBT |
| `finalize_psbt` | `signed_psbt: base64` | `FinalizedTx: JSON` | Finalize PSBT |
| `derive_scan_addresses` | `params: JSON, network: i32` | `addresses: JSON[]` | Derive addresses for scanning |
| `reconstruct_vault` | `data: JSON, xpub: string, network: i32` | `Vault: JSON` | Reconstruct from blockchain |
| `decode_metadata_leaf` | `script_hex: string` | `VaultMetadata: JSON` | Decode metadata |
| `validate_address` | `address: string, network: i32` | `ValidationResult: JSON` | Validate address |
| `validate_xpub` | `xpub: string, network: i32` | `ValidationResult: JSON` | Validate xpub |
| `blocks_to_time_estimate` | `blocks: u32` | `string` | Convert blocks to time |
| `free_rust_string` | `ptr: *char` | - | Free allocated string |

---

## Error Handling

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| 1001 | `INVALID_XPUB` | Invalid extended public key |
| 1002 | `INVALID_ADDRESS` | Invalid Bitcoin address |
| 1003 | `NETWORK_MISMATCH` | Address/xpub network doesn't match |
| 2001 | `PSBT_BUILD_FAILED` | Failed to construct PSBT |
| 2002 | `INSUFFICIENT_FUNDS` | Not enough balance |
| 2003 | `POLICY_VIOLATION` | Transaction violates vault policy |
| 3001 | `KEY_DERIVATION_FAILED` | Failed to derive key |
| 3002 | `METADATA_DECODE_FAILED` | Invalid metadata encoding |
| 4001 | `SERIALIZATION_ERROR` | JSON serialization failed |
| 4002 | `INVALID_INPUT` | Malformed input |

### Error Response Format

```json
{
  "error": true,
  "code": 2002,
  "message": "Insufficient funds: need 100000 sats, have 50000 sats"
}
```

---

## Memory Management

**Critical:** All strings returned from Rust MUST be freed using `free_rust_string()`.

```dart
// ❌ WRONG - Memory leak!
final ptr = _createVault(requestJson);
final result = ptr.toDartString();
// Missing: _freeRustString(ptr);

// ✅ CORRECT
final ptr = _createVault(requestJson);
try {
  final result = ptr.toDartString();
  // Process result...
} finally {
  _freeRustString(ptr);
}
```

---

## Thread Safety

The Rust core is designed to be thread-safe:
- No global mutable state
- All data passed by value (via JSON)
- Secp256k1 context uses global initialization

Flutter should call FFI functions from isolates if needed for heavy computation.

---

## Testing the FFI Bridge

```dart
// test/ffi_test.dart

void main() {
  late RustFfi ffi;
  
  setUpAll(() {
    ffi = RustFfi.instance;
    ffi.initialize(Network.testnet);
  });
  
  test('version returns valid string', () {
    final version = ffi.getVersion();
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });
  
  test('address generation works', () async {
    final result = await ffi.generateVaultAddress(
      primaryXpub: 'tpub...',
      template: VaultTemplate.savings(),
      vaultIndex: 0,
      network: Network.testnet,
    );
    
    expect(result.address, startsWith('tb1p'));
    expect(result.descriptor, isNotEmpty);
  });
  
  test('invalid xpub returns error', () async {
    expect(
      () => ffi.generateVaultAddress(
        primaryXpub: 'invalid',
        template: VaultTemplate.savings(),
        vaultIndex: 0,
        network: Network.testnet,
      ),
      throwsA(isA<RustCoreException>()),
    );
  });
}
```
