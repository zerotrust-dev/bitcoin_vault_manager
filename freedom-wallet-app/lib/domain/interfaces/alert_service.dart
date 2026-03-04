import 'package:freedom_wallet/domain/models/alert.dart';

/// Abstract service for managing vault alerts.
abstract class AlertService {
  Future<List<Alert>> getAlerts();
  Future<void> acknowledgeAlert(String alertId);
  Future<void> addAlert(Alert alert);
  int get unacknowledgedCount;
}
