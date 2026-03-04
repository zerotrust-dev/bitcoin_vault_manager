import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/datasources/esplora_client.dart';
import 'package:freedom_wallet/data/mock/mock_watcher_service.dart';
import 'package:freedom_wallet/data/services/esplora_watcher_service.dart';
import 'package:freedom_wallet/domain/interfaces/watcher_service.dart';
import 'package:freedom_wallet/domain/models/alert.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/providers/alert_provider.dart';
import 'package:freedom_wallet/presentation/providers/settings_provider.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';
import 'package:uuid/uuid.dart';

/// Esplora client, rebuilt when network setting changes.
final esploraClientProvider = Provider<EsploraClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final baseUrl = EsploraClient.baseUrlForNetwork(settings.network);
  return EsploraClient(baseUrl: baseUrl);
});

/// WatcherService with useMocks toggle.
final watcherServiceProvider = Provider<WatcherService>((ref) {
  if (useMocks) return MockWatcherService();
  final client = ref.watch(esploraClientProvider);
  return EsploraWatcherService(client: client);
});

/// Fee estimates from blockchain.
final feeEstimatesProvider = FutureProvider<FeeEstimates>((ref) async {
  final watcher = ref.watch(watcherServiceProvider);
  return watcher.getFeeEstimates();
});

/// UTXOs for a specific vault address.
final vaultUtxosProvider =
    FutureProvider.family<List<Utxo>, String>((ref, address) async {
  final watcher = ref.watch(watcherServiceProvider);
  return watcher.getUtxos(address);
});

/// Vault monitor state.
class VaultMonitorState {
  final bool isPolling;
  final DateTime? lastChecked;
  final Map<String, int> previousBalances; // address -> sats

  const VaultMonitorState({
    this.isPolling = false,
    this.lastChecked,
    this.previousBalances = const {},
  });

  VaultMonitorState copyWith({
    bool? isPolling,
    DateTime? lastChecked,
    Map<String, int>? previousBalances,
  }) {
    return VaultMonitorState(
      isPolling: isPolling ?? this.isPolling,
      lastChecked: lastChecked ?? this.lastChecked,
      previousBalances: previousBalances ?? this.previousBalances,
    );
  }
}

/// Polls vault addresses for balance changes and generates alerts.
final vaultMonitorProvider =
    StateNotifierProvider<VaultMonitorNotifier, VaultMonitorState>(
  (ref) => VaultMonitorNotifier(ref),
);

class VaultMonitorNotifier extends StateNotifier<VaultMonitorState> {
  final Ref _ref;
  Timer? _timer;
  static const _uuid = Uuid();

  VaultMonitorNotifier(this._ref) : super(const VaultMonitorState());

  /// Start periodic polling. Safe to call multiple times (idempotent).
  void startPolling({Duration interval = const Duration(seconds: 60)}) {
    if (state.isPolling) return;
    state = state.copyWith(isPolling: true);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _pollAll());
    _pollAll(); // immediate first check
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isPolling: false);
  }

  /// Force a single poll (e.g. after broadcasting a tx).
  Future<void> pollNow() => _pollAll();

  Future<void> _pollAll() async {
    final vaults = _ref.read(vaultsProvider).valueOrNull ?? [];
    if (vaults.isEmpty) return;

    final watcher = _ref.read(watcherServiceProvider);
    final alertService = _ref.read(alertServiceProvider);
    final vaultService = _ref.read(vaultServiceProvider);

    final updatedBalances = Map<String, int>.from(state.previousBalances);
    bool anyChanged = false;

    for (final vault in vaults) {
      try {
        final balance = await watcher.getBalance(vault.address);
        final oldBalance = updatedBalances[vault.address];

        if (oldBalance != null && balance != oldBalance) {
          anyChanged = true;
          if (balance > oldBalance) {
            await alertService.addAlert(_fundedAlert(vault, balance - oldBalance));
          } else {
            await alertService.addAlert(
                _spendDetectedAlert(vault, oldBalance - balance));
          }
          await vaultService.updateVaultBalance(vault.id, balance);
        } else if (oldBalance == null && balance != vault.balanceSats) {
          // First poll — sync stored balance with blockchain
          await vaultService.updateVaultBalance(vault.id, balance);
          anyChanged = true;
        }

        updatedBalances[vault.address] = balance;
      } catch (_) {
        // Don't crash polling on individual vault errors
      }

      // Small delay between vaults to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    state = state.copyWith(
      lastChecked: DateTime.now(),
      previousBalances: updatedBalances,
    );

    if (anyChanged) {
      _ref.invalidate(alertsProvider);
      _ref.invalidate(vaultsProvider);
    }
  }

  Alert _fundedAlert(Vault vault, int amountSats) {
    return Alert(
      id: _uuid.v4(),
      type: AlertType.vaultFunded,
      vaultId: vault.id,
      title: 'Vault Funded',
      message:
          '${vault.name} received ${(amountSats / 100000000).toStringAsFixed(8)} BTC.',
      severity: AlertSeverity.info,
      timestamp: DateTime.now(),
      actions: [
        const AlertAction(
          id: 'view',
          label: 'View Details',
          type: AlertActionType.viewDetails,
        ),
        const AlertAction(
          id: 'dismiss',
          label: 'Dismiss',
          type: AlertActionType.dismiss,
        ),
      ],
    );
  }

  Alert _spendDetectedAlert(Vault vault, int amountSats) {
    return Alert(
      id: _uuid.v4(),
      type: AlertType.spendDetected,
      vaultId: vault.id,
      title: 'Spend Detected',
      message:
          '${vault.name} is spending ${(amountSats / 100000000).toStringAsFixed(8)} BTC. '
          'If you didn\'t do this, cancel immediately.',
      severity: AlertSeverity.critical,
      timestamp: DateTime.now(),
      actions: [
        const AlertAction(
          id: 'cancel',
          label: 'Cancel Transaction',
          type: AlertActionType.cancelTransaction,
        ),
        const AlertAction(
          id: 'dismiss',
          label: 'Yes, I did this',
          type: AlertActionType.dismiss,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
