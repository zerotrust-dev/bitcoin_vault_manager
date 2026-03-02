import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/mock/mock_vault_service.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

final vaultServiceProvider = Provider((ref) => MockVaultService());

final vaultsProvider = FutureProvider<List<Vault>>((ref) async {
  final service = ref.watch(vaultServiceProvider);
  return service.getVaults();
});

final selectedVaultProvider = StateProvider<String?>((ref) => null);

final selectedVaultDataProvider = FutureProvider<Vault?>((ref) async {
  final vaultId = ref.watch(selectedVaultProvider);
  if (vaultId == null) return null;
  final service = ref.watch(vaultServiceProvider);
  return service.getVault(vaultId);
});

final totalBalanceProvider = Provider<int>((ref) {
  final vaultsAsync = ref.watch(vaultsProvider);
  return vaultsAsync.when(
    data: (vaults) => vaults.fold(0, (sum, v) => sum + v.balanceSats),
    loading: () => 0,
    error: (_, _) => 0,
  );
});
