import 'package:freedom_wallet/data/mock/mock_data.dart';
import 'package:freedom_wallet/domain/models/alert.dart';

class MockAlertService {
  List<Alert> _alerts = List.from(MockData.alerts);

  Future<List<Alert>> getAlerts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_alerts);
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _alerts = _alerts.map((a) {
      if (a.id == alertId) {
        return a.copyWith(acknowledged: true);
      }
      return a;
    }).toList();
  }

  int get unacknowledgedCount =>
      _alerts.where((a) => !a.acknowledged).length;
}
