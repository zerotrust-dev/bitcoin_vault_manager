import 'package:freedom_wallet/domain/models/vault.dart';

abstract class VaultService {
  Future<List<Vault>> getVaults();
  Future<Vault> getVault(String id);
  Future<Vault> createVault({
    required String name,
    required VaultTemplate template,
    required DeviceRef primaryDevice,
    DeviceRef? emergencyDevice,
    required Network network,
  });
  Future<void> simulateFunding(String vaultId, int amountSats);
  int get totalBalanceSats;
}
