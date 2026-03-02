import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/mock/mock_alert_service.dart';
import 'package:freedom_wallet/domain/models/alert.dart';

final alertServiceProvider = Provider((ref) => MockAlertService());

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
