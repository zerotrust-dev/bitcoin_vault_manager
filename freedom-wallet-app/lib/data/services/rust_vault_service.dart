import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/data/local/vault_storage.dart';
import 'package:freedom_wallet/domain/interfaces/vault_service.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class RustVaultService implements VaultService {
  final RustFfi _ffi;
  final VaultStorage _storage;
  List<Vault> _vaults = [];
  int _nextVaultIndex = 0;
  bool _loaded = false;

  RustVaultService({RustFfi? ffi, VaultStorage? storage})
      : _ffi = ffi ?? RustFfi.instance,
        _storage = storage ?? VaultStorage();

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _vaults = await _storage.loadVaults();
    _nextVaultIndex = await _storage.loadNextVaultIndex();
    _loaded = true;
  }

  @override
  Future<List<Vault>> getVaults() async {
    await _ensureLoaded();
    return List.unmodifiable(_vaults);
  }

  @override
  Future<Vault> getVault(String id) async {
    await _ensureLoaded();
    return _vaults.firstWhere((v) => v.id == id);
  }

  @override
  Future<Vault> createVault({
    required String name,
    required VaultTemplate template,
    required DeviceRef primaryDevice,
    DeviceRef? emergencyDevice,
    required Network network,
  }) async {
    await _ensureLoaded();

    // Convert Dart template to Rust-compatible JSON
    final rustTemplate = templateToRustJson(template);
    final networkInt = network.index;

    // Call Rust core to generate a real Taproot address
    final result = _ffi.generateVaultAddress(
      primaryXpub: primaryDevice.xpub ?? primaryDevice.fingerprint,
      emergencyXpub: emergencyDevice?.xpub ?? emergencyDevice?.fingerprint,
      template: rustTemplate,
      vaultIndex: _nextVaultIndex,
      network: networkInt,
    );

    final address = result['address'] as String;

    final vault = Vault(
      id: 'vault-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      template: template,
      balanceSats: 0,
      address: address,
      descriptor: 'tr(${primaryDevice.fingerprint}/86h/${network.index}h/0h)',
      status: VaultStatus.awaitingFunding,
      primaryDevice: primaryDevice,
      emergencyDevice: emergencyDevice,
      network: network,
      createdAt: DateTime.now(),
    );

    _vaults = [..._vaults, vault];
    _nextVaultIndex++;
    await _storage.saveVaults(_vaults);
    await _storage.saveNextVaultIndex(_nextVaultIndex);
    return vault;
  }

  @override
  Future<void> simulateFunding(String vaultId, int amountSats) async {
    await _ensureLoaded();
    _vaults = _vaults.map((v) {
      if (v.id == vaultId) {
        return v.copyWith(
          balanceSats: v.balanceSats + amountSats,
          status: VaultStatus.active,
          lastActivityAt: DateTime.now(),
        );
      }
      return v;
    }).toList();
    await _storage.saveVaults(_vaults);
  }

  @override
  Future<void> updateVaultBalance(String vaultId, int balanceSats) async {
    await _ensureLoaded();
    _vaults = _vaults.map((v) {
      if (v.id == vaultId) {
        final newStatus =
            balanceSats > 0 ? VaultStatus.active : VaultStatus.empty;
        return v.copyWith(
          balanceSats: balanceSats,
          status: newStatus,
          lastActivityAt: DateTime.now(),
        );
      }
      return v;
    }).toList();
    await _storage.saveVaults(_vaults);
  }

  @override
  Future<Vault> importRecoveredVault({
    required String name,
    required VaultTemplate template,
    required String address,
    required int balanceSats,
    required int vaultIndex,
    required DeviceRef primaryDevice,
    DeviceRef? emergencyDevice,
    required Network network,
  }) async {
    await _ensureLoaded();

    final vault = Vault(
      id: 'vault-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      template: template,
      balanceSats: balanceSats,
      address: address,
      descriptor:
          'tr(${primaryDevice.fingerprint}/86h/${network.index}h/0h/0/$vaultIndex)',
      status: balanceSats > 0 ? VaultStatus.active : VaultStatus.empty,
      primaryDevice: primaryDevice,
      emergencyDevice: emergencyDevice,
      network: network,
      createdAt: DateTime.now(),
    );

    _vaults = [..._vaults, vault];
    if (vaultIndex >= _nextVaultIndex) {
      _nextVaultIndex = vaultIndex + 1;
    }
    await _storage.saveVaults(_vaults);
    await _storage.saveNextVaultIndex(_nextVaultIndex);
    return vault;
  }

  @override
  int get totalBalanceSats =>
      _vaults.fold(0, (sum, v) => sum + v.balanceSats);

  /// Convert a Dart VaultTemplate to the JSON shape Rust expects.
  ///
  /// Rust uses `#[serde(tag = "type")]` internally-tagged enum:
  /// - `{"type":"savings"}` or `{"type":"savings","delay_blocks":1008}`
  /// - `{"type":"spending"}` or `{"type":"spending","delay_blocks":144}`
  /// - `{"type":"custom","delay_blocks":N,"recovery_type":"emergency_key"}`
  static Map<String, dynamic> templateToRustJson(VaultTemplate t) {
    final json = <String, dynamic>{'type': t.type};
    if (t.delayBlocks != _defaultDelay(t.type)) {
      json['delay_blocks'] = t.delayBlocks;
    }
    if (t.type == 'custom') {
      json['delay_blocks'] = t.delayBlocks;
      json['recovery_type'] = _recoveryTypeToRust(t.recoveryType);
    }
    return json;
  }

  static int _defaultDelay(String type) {
    switch (type) {
      case 'savings':
        return 1008;
      case 'spending':
        return 144;
      default:
        return 0;
    }
  }

  static String _recoveryTypeToRust(RecoveryType? rt) {
    switch (rt) {
      case RecoveryType.emergencyKey:
        return 'emergency_key';
      case RecoveryType.timelockOnly:
        return 'timelock_only';
      case RecoveryType.multiSig:
        return 'multi_sig';
      default:
        return 'timelock_only';
    }
  }
}
