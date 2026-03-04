import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/mock/mock_recovery_service.dart';
import 'package:freedom_wallet/data/services/recovery_service_impl.dart';
import 'package:freedom_wallet/domain/interfaces/recovery_service.dart';
import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';
import 'package:freedom_wallet/presentation/providers/watcher_provider.dart';

enum RecoveryState {
  idle,
  connecting,
  scanning,
  reviewing,
  confirming,
  complete,
  error,
}

class RecoveryScreenState {
  final RecoveryState phase;
  final RecoveryProgress? progress;
  final RecoveryResult? result;
  final String? errorMessage;

  const RecoveryScreenState({
    this.phase = RecoveryState.idle,
    this.progress,
    this.result,
    this.errorMessage,
  });

  RecoveryScreenState copyWith({
    RecoveryState? phase,
    RecoveryProgress? progress,
    RecoveryResult? result,
    String? errorMessage,
  }) =>
      RecoveryScreenState(
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        errorMessage: errorMessage,
      );

  List<RecoveredVault> get selectedVaults =>
      result?.recoveredVaults.where((v) => v.selected).toList() ?? [];
}

final recoveryServiceProvider = Provider<RecoveryService>((ref) {
  if (useMocks) return MockRecoveryService();
  final ffi = ref.watch(rustFfiProvider);
  final esplora = ref.watch(esploraClientProvider);
  return RecoveryServiceImpl(ffi: ffi, esplora: esplora);
});

final recoveryProvider =
    StateNotifierProvider<RecoveryNotifier, RecoveryScreenState>(
  (ref) => RecoveryNotifier(ref),
);

class RecoveryNotifier extends StateNotifier<RecoveryScreenState> {
  final Ref _ref;

  RecoveryNotifier(this._ref) : super(const RecoveryScreenState());

  void setPhase(RecoveryState phase) {
    state = state.copyWith(phase: phase);
  }

  Future<void> startScan({
    required String primaryXpub,
    String? emergencyXpub,
    required Network network,
  }) async {
    state = state.copyWith(
      phase: RecoveryState.scanning,
      errorMessage: null,
    );

    try {
      final service = _ref.read(recoveryServiceProvider);
      final result = await service.scanForVaults(
        primaryXpub: primaryXpub,
        emergencyXpub: emergencyXpub,
        network: network,
        onProgress: (progress) {
          if (mounted) {
            state = state.copyWith(progress: progress);
          }
        },
      );

      if (mounted) {
        state = state.copyWith(
          phase: RecoveryState.reviewing,
          result: result,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          phase: RecoveryState.error,
          errorMessage: 'Scan failed: $e',
        );
      }
    }
  }

  void cancelScan() {
    _ref.read(recoveryServiceProvider).cancelScan();
    state = const RecoveryScreenState();
  }

  void toggleVaultSelection(int vaultIndex) {
    final result = state.result;
    if (result == null) return;
    final updated = result.recoveredVaults.map((v) {
      if (v.vaultIndex == vaultIndex) {
        return v.copyWith(selected: !v.selected);
      }
      return v;
    }).toList();
    state = state.copyWith(
      result: RecoveryResult(
        success: result.success,
        recoveredVaults: updated,
        addressesScanned: result.addressesScanned,
        durationMs: result.durationMs,
      ),
    );
  }

  Future<void> confirmRecovery({
    required DeviceRef primaryDevice,
    required Network network,
  }) async {
    state = state.copyWith(phase: RecoveryState.confirming);

    try {
      final vaultService = _ref.read(vaultServiceProvider);

      for (final recovered in state.selectedVaults) {
        // Check for duplicate addresses
        final existing = await vaultService.getVaults();
        if (existing.any((v) => v.address == recovered.address)) continue;

        final typeName =
            recovered.template.type == 'savings' ? 'Savings' : 'Spending';

        await vaultService.importRecoveredVault(
          name: 'Recovered $typeName #${recovered.vaultIndex}',
          template: recovered.template,
          address: recovered.address,
          balanceSats: recovered.totalBalanceSats,
          vaultIndex: recovered.vaultIndex,
          primaryDevice: primaryDevice,
          network: network,
        );
      }

      // Refresh vault list and sync balances
      _ref.invalidate(vaultsProvider);
      _ref.read(vaultMonitorProvider.notifier).pollNow();

      if (mounted) {
        state = state.copyWith(phase: RecoveryState.complete);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          phase: RecoveryState.error,
          errorMessage: 'Recovery failed: $e',
        );
      }
    }
  }

  void reset() {
    state = const RecoveryScreenState();
  }
}
