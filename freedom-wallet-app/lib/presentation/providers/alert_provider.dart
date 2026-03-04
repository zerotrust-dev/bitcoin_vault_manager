import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/mock/mock_alert_service.dart';
import 'package:freedom_wallet/data/services/blockchain_alert_service.dart';
import 'package:freedom_wallet/domain/interfaces/alert_service.dart';
import 'package:freedom_wallet/domain/models/alert.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';

final alertServiceProvider = Provider<AlertService>((ref) {
  if (useMocks) return MockAlertService();
  return BlockchainAlertService();
});

final alertsProvider = FutureProvider<List<Alert>>((ref) async {
  final service = ref.watch(alertServiceProvider);
  return service.getAlerts();
});

final unacknowledgedCountProvider = Provider<int>((ref) {
  final alertsAsync = ref.watch(alertsProvider);
  return alertsAsync.when(
    data: (alerts) => alerts.where((a) => !a.acknowledged).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
