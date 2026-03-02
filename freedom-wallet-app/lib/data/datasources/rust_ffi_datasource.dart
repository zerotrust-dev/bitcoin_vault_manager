import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ═══════════════════════════════════════════════════════════════════
//                    NATIVE TYPE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════

// vault_version() -> *mut c_char
typedef _VaultVersionNative = Pointer<Utf8> Function();
typedef _VaultVersionDart = Pointer<Utf8> Function();

// vault_init(network: i32) -> i32
typedef _VaultInitNative = Int32 Function(Int32 network);
typedef _VaultInitDart = int Function(int network);

// free_rust_string(ptr: *mut c_char)
typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

// ffi_validate_xpub(xpub: *const c_char, network: i32) -> *mut c_char
typedef _ValidateXpubNative = Pointer<Utf8> Function(
    Pointer<Utf8> xpub, Int32 network);
typedef _ValidateXpubDart = Pointer<Utf8> Function(
    Pointer<Utf8> xpub, int network);

// ffi_get_derivation_path(vault_index: u32, network: i32) -> *mut c_char
typedef _GetDerivationPathNative = Pointer<Utf8> Function(
    Uint32 vaultIndex, Int32 network);
typedef _GetDerivationPathDart = Pointer<Utf8> Function(
    int vaultIndex, int network);

// ffi_generate_vault_address(params_json: *const c_char, network: i32) -> *mut c_char
typedef _GenerateAddressNative = Pointer<Utf8> Function(
    Pointer<Utf8> paramsJson, Int32 network);
typedef _GenerateAddressDart = Pointer<Utf8> Function(
    Pointer<Utf8> paramsJson, int network);

// ffi_validate_address(address: *const c_char, network: i32) -> *mut c_char
typedef _ValidateAddressNative = Pointer<Utf8> Function(
    Pointer<Utf8> address, Int32 network);
typedef _ValidateAddressDart = Pointer<Utf8> Function(
    Pointer<Utf8> address, int network);

// ffi_decode_metadata_leaf(script_hex: *const c_char) -> *mut c_char
typedef _DecodeMetadataNative = Pointer<Utf8> Function(
    Pointer<Utf8> scriptHex);
typedef _DecodeMetadataDart = Pointer<Utf8> Function(
    Pointer<Utf8> scriptHex);

// ffi_build_delayed_spend_psbt(intent, utxos, vault: *const c_char) -> *mut c_char
typedef _BuildDelayedPsbtNative = Pointer<Utf8> Function(
    Pointer<Utf8> intentJson, Pointer<Utf8> utxosJson, Pointer<Utf8> vaultJson);
typedef _BuildDelayedPsbtDart = Pointer<Utf8> Function(
    Pointer<Utf8> intentJson, Pointer<Utf8> utxosJson, Pointer<Utf8> vaultJson);

// ffi_build_emergency_psbt(params, utxos, vault: *const c_char) -> *mut c_char
typedef _BuildEmergencyPsbtNative = Pointer<Utf8> Function(
    Pointer<Utf8> paramsJson, Pointer<Utf8> utxosJson, Pointer<Utf8> vaultJson);
typedef _BuildEmergencyPsbtDart = Pointer<Utf8> Function(
    Pointer<Utf8> paramsJson, Pointer<Utf8> utxosJson, Pointer<Utf8> vaultJson);

// ffi_verify_psbt_policy(psbt_base64, vault_json: *const c_char) -> *mut c_char
typedef _VerifyPsbtPolicyNative = Pointer<Utf8> Function(
    Pointer<Utf8> psbtBase64, Pointer<Utf8> vaultJson);
typedef _VerifyPsbtPolicyDart = Pointer<Utf8> Function(
    Pointer<Utf8> psbtBase64, Pointer<Utf8> vaultJson);

// ffi_finalize_psbt(signed_psbt_base64: *const c_char) -> *mut c_char
typedef _FinalizePsbtNative = Pointer<Utf8> Function(
    Pointer<Utf8> signedPsbtBase64);
typedef _FinalizePsbtDart = Pointer<Utf8> Function(
    Pointer<Utf8> signedPsbtBase64);

// ffi_blocks_to_time_estimate(blocks: u32) -> *mut c_char
typedef _BlocksToTimeNative = Pointer<Utf8> Function(Uint32 blocks);
typedef _BlocksToTimeDart = Pointer<Utf8> Function(int blocks);

// ffi_calculate_unlock_height(current_height: u32, delay_blocks: u32) -> u32
typedef _CalcUnlockHeightNative = Uint32 Function(
    Uint32 currentHeight, Uint32 delayBlocks);
typedef _CalcUnlockHeightDart = int Function(
    int currentHeight, int delayBlocks);

// ═══════════════════════════════════════════════════════════════════
//                       EXCEPTION TYPE
// ═══════════════════════════════════════════════════════════════════

class RustCoreException implements Exception {
  final String message;
  final int? code;

  RustCoreException(this.message, {this.code});

  @override
  String toString() => 'RustCoreException($code): $message';
}

// ═══════════════════════════════════════════════════════════════════
//                     FFI BRIDGE CLASS
// ═══════════════════════════════════════════════════════════════════

class RustFfi {
  static RustFfi? _instance;
  late final DynamicLibrary _lib;

  // Bound function pointers
  late final _VaultVersionDart _vaultVersion;
  late final _VaultInitDart _vaultInit;
  late final _FreeStringDart _freeRustString;
  late final _ValidateXpubDart _validateXpub;
  late final _GetDerivationPathDart _getDerivationPath;
  late final _GenerateAddressDart _generateVaultAddress;
  late final _ValidateAddressDart _validateAddress;
  late final _DecodeMetadataDart _decodeMetadataLeaf;
  late final _BuildDelayedPsbtDart _buildDelayedSpendPsbt;
  late final _BuildEmergencyPsbtDart _buildEmergencyPsbt;
  late final _VerifyPsbtPolicyDart _verifyPsbtPolicy;
  late final _FinalizePsbtDart _finalizePsbt;
  late final _BlocksToTimeDart _blocksToTimeEstimate;
  late final _CalcUnlockHeightDart _calculateUnlockHeight;

  static RustFfi get instance {
    _instance ??= RustFfi._();
    return _instance!;
  }

  RustFfi._() {
    _lib = _openLibrary();
    _bindFunctions();
  }

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
    throw UnsupportedError('Platform not supported for vault-core FFI');
  }

  void _bindFunctions() {
    _vaultVersion = _lib
        .lookup<NativeFunction<_VaultVersionNative>>('vault_version')
        .asFunction();
    _vaultInit = _lib
        .lookup<NativeFunction<_VaultInitNative>>('vault_init')
        .asFunction();
    _freeRustString = _lib
        .lookup<NativeFunction<_FreeStringNative>>('free_rust_string')
        .asFunction();
    _validateXpub = _lib
        .lookup<NativeFunction<_ValidateXpubNative>>('ffi_validate_xpub')
        .asFunction();
    _getDerivationPath = _lib
        .lookup<NativeFunction<_GetDerivationPathNative>>(
            'ffi_get_derivation_path')
        .asFunction();
    _generateVaultAddress = _lib
        .lookup<NativeFunction<_GenerateAddressNative>>(
            'ffi_generate_vault_address')
        .asFunction();
    _validateAddress = _lib
        .lookup<NativeFunction<_ValidateAddressNative>>('ffi_validate_address')
        .asFunction();
    _decodeMetadataLeaf = _lib
        .lookup<NativeFunction<_DecodeMetadataNative>>(
            'ffi_decode_metadata_leaf')
        .asFunction();
    _buildDelayedSpendPsbt = _lib
        .lookup<NativeFunction<_BuildDelayedPsbtNative>>(
            'ffi_build_delayed_spend_psbt')
        .asFunction();
    _buildEmergencyPsbt = _lib
        .lookup<NativeFunction<_BuildEmergencyPsbtNative>>(
            'ffi_build_emergency_psbt')
        .asFunction();
    _verifyPsbtPolicy = _lib
        .lookup<NativeFunction<_VerifyPsbtPolicyNative>>(
            'ffi_verify_psbt_policy')
        .asFunction();
    _finalizePsbt = _lib
        .lookup<NativeFunction<_FinalizePsbtNative>>('ffi_finalize_psbt')
        .asFunction();
    _blocksToTimeEstimate = _lib
        .lookup<NativeFunction<_BlocksToTimeNative>>(
            'ffi_blocks_to_time_estimate')
        .asFunction();
    _calculateUnlockHeight = _lib
        .lookup<NativeFunction<_CalcUnlockHeightNative>>(
            'ffi_calculate_unlock_height')
        .asFunction();
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         PUBLIC API
  // ═══════════════════════════════════════════════════════════════════

  String getVersion() {
    final ptr = _vaultVersion();
    try {
      return ptr.toDartString();
    } finally {
      _freeRustString(ptr);
    }
  }

  void initialize(int network) {
    final result = _vaultInit(network);
    if (result != 0) {
      throw RustCoreException('Initialization failed', code: result);
    }
  }

  Map<String, dynamic> validateXpub(String xpub, int network) {
    final xpubPtr = xpub.toNativeUtf8();
    try {
      final ptr = _validateXpub(xpubPtr, network);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(xpubPtr);
    }
  }

  String getDerivationPath(int vaultIndex, int network) {
    final ptr = _getDerivationPath(vaultIndex, network);
    try {
      return ptr.toDartString();
    } finally {
      _freeRustString(ptr);
    }
  }

  Map<String, dynamic> generateVaultAddress({
    required String primaryXpub,
    String? emergencyXpub,
    required Map<String, dynamic> template,
    required int vaultIndex,
    required int network,
  }) {
    final params = {
      'primary_xpub': primaryXpub,
      if (emergencyXpub != null) 'emergency_xpub': emergencyXpub,
      'template': template,
      'vault_index': vaultIndex,
    };
    final paramsPtr = jsonEncode(params).toNativeUtf8();
    try {
      final ptr = _generateVaultAddress(paramsPtr, network);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(paramsPtr);
    }
  }

  Map<String, dynamic> validateAddress(String address, int network) {
    final addrPtr = address.toNativeUtf8();
    try {
      final ptr = _validateAddress(addrPtr, network);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(addrPtr);
    }
  }

  Map<String, dynamic> decodeMetadataLeaf(String scriptHex) {
    final hexPtr = scriptHex.toNativeUtf8();
    try {
      final ptr = _decodeMetadataLeaf(hexPtr);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(hexPtr);
    }
  }

  Map<String, dynamic> buildDelayedSpendPsbt({
    required Map<String, dynamic> intent,
    required List<Map<String, dynamic>> utxos,
    required Map<String, dynamic> vaultConfig,
  }) {
    final intentPtr = jsonEncode(intent).toNativeUtf8();
    final utxosPtr = jsonEncode(utxos).toNativeUtf8();
    final vaultPtr = jsonEncode(vaultConfig).toNativeUtf8();
    try {
      final ptr = _buildDelayedSpendPsbt(intentPtr, utxosPtr, vaultPtr);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(intentPtr);
      calloc.free(utxosPtr);
      calloc.free(vaultPtr);
    }
  }

  Map<String, dynamic> buildEmergencyPsbt({
    required String destination,
    required double feeRate,
    required List<Map<String, dynamic>> utxos,
    required Map<String, dynamic> vaultConfig,
  }) {
    final params = {'destination': destination, 'fee_rate': feeRate};
    final paramsPtr = jsonEncode(params).toNativeUtf8();
    final utxosPtr = jsonEncode(utxos).toNativeUtf8();
    final vaultPtr = jsonEncode(vaultConfig).toNativeUtf8();
    try {
      final ptr = _buildEmergencyPsbt(paramsPtr, utxosPtr, vaultPtr);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(paramsPtr);
      calloc.free(utxosPtr);
      calloc.free(vaultPtr);
    }
  }

  Map<String, dynamic> verifyPsbtPolicy({
    required String psbtBase64,
    required Map<String, dynamic> vaultConfig,
  }) {
    final psbtPtr = psbtBase64.toNativeUtf8();
    final vaultPtr = jsonEncode(vaultConfig).toNativeUtf8();
    try {
      final ptr = _verifyPsbtPolicy(psbtPtr, vaultPtr);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(psbtPtr);
      calloc.free(vaultPtr);
    }
  }

  Map<String, dynamic> finalizePsbt(String signedPsbtBase64) {
    final psbtPtr = signedPsbtBase64.toNativeUtf8();
    try {
      final ptr = _finalizePsbt(psbtPtr);
      return _parseJsonResult(ptr);
    } finally {
      calloc.free(psbtPtr);
    }
  }

  String blocksToTimeEstimate(int blocks) {
    final ptr = _blocksToTimeEstimate(blocks);
    try {
      return ptr.toDartString();
    } finally {
      _freeRustString(ptr);
    }
  }

  int calculateUnlockHeight(int currentHeight, int delayBlocks) {
    return _calculateUnlockHeight(currentHeight, delayBlocks);
  }

  // ═══════════════════════════════════════════════════════════════════
  //                         HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Parse a JSON result pointer from Rust, free the pointer, and check for errors.
  Map<String, dynamic> _parseJsonResult(Pointer<Utf8> ptr) {
    try {
      final jsonString = ptr.toDartString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      if (json['error'] == true) {
        throw RustCoreException(
          json['message'] as String? ?? 'Unknown error',
          code: json['code'] as int?,
        );
      }
      return json;
    } finally {
      _freeRustString(ptr);
    }
  }
}
