import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/data/mock/mock_vault_service.dart';
import 'package:freedom_wallet/data/services/rust_vault_service.dart';
import 'package:freedom_wallet/domain/interfaces/vault_service.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

/// Set to true to use mock services instead of real Rust FFI.
/// Useful for UI development without the native library.
const bool useMocks = false;

final rustFfiProvider = Provider<RustFfi>((ref) {
  final ffi = RustFfi.instance;
  ffi.initialize(Network.testnet.index);
  return ffi;
});

final vaultServiceProvider = Provider<VaultService>((ref) {
  if (useMocks) {
    return MockVaultService();
  }
  final ffi = ref.watch(rustFfiProvider);
  return RustVaultService(ffi: ffi);
});

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
