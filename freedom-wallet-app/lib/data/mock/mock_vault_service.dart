import 'package:freedom_wallet/data/mock/mock_data.dart';
import 'package:freedom_wallet/domain/interfaces/vault_service.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class MockVaultService implements VaultService {
  List<Vault> _vaults = List.from(MockData.allVaults);

  @override
  Future<List<Vault>> getVaults() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_vaults);
  }

  @override
  Future<Vault> getVault(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
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
    await Future.delayed(const Duration(seconds: 1));
    final vault = Vault(
      id: 'vault-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      template: template,
      balanceSats: 0,
      address:
          'bc1p${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padRight(58, '0')}',
      descriptor: 'tr(xpub.../86h/0h/${_vaults.length}h)',
      status: VaultStatus.awaitingFunding,
      primaryDevice: primaryDevice,
      emergencyDevice: emergencyDevice,
      network: network,
      createdAt: DateTime.now(),
    );
    _vaults = [..._vaults, vault];
    return vault;
  }

  @override
  Future<void> simulateFunding(String vaultId, int amountSats) async {
    await Future.delayed(const Duration(seconds: 2));
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
  }

  @override
  int get totalBalanceSats =>
      _vaults.fold(0, (sum, v) => sum + v.balanceSats);
}
