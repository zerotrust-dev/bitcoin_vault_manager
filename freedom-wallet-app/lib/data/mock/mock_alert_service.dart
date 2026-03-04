import 'package:freedom_wallet/data/mock/mock_data.dart';
import 'package:freedom_wallet/domain/interfaces/alert_service.dart';
import 'package:freedom_wallet/domain/models/alert.dart';

class MockAlertService implements AlertService {
  List<Alert> _alerts = List.from(MockData.alerts);

  @override
  Future<List<Alert>> getAlerts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_alerts);
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _alerts = _alerts.map((a) {
      if (a.id == alertId) {
        return a.copyWith(acknowledged: true);
      }
      return a;
    }).toList();
  }

  @override
  Future<void> addAlert(Alert alert) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _alerts = [alert, ..._alerts];
  }

  @override
  int get unacknowledgedCount =>
      _alerts.where((a) => !a.acknowledged).length;
}
