import 'package:flutter_test/flutter_test.dart';
import 'package:freedom_wallet/data/services/blockchain_alert_service.dart';
import 'package:freedom_wallet/data/local/alert_storage.dart';
import 'package:freedom_wallet/domain/models/alert.dart';

/// Fake AlertStorage that stores in memory (no FlutterSecureStorage).
class FakeAlertStorage extends AlertStorage {
  List<Alert> _stored = [];

  FakeAlertStorage() : super(storage: null);

  @override
  Future<List<Alert>> loadAlerts() async => List.from(_stored);

  @override
  Future<void> saveAlerts(List<Alert> alerts) async {
    _stored = List.from(alerts);
  }

  @override
  Future<void> clearAlerts() async {
    _stored = [];
  }
}

void main() {
  group('BlockchainAlertService', () {
    late FakeAlertStorage storage;
    late BlockchainAlertService service;

    setUp(() {
      storage = FakeAlertStorage();
      service = BlockchainAlertService(storage: storage);
    });

    test('starts with empty alerts', () async {
      final alerts = await service.getAlerts();
      expect(alerts, isEmpty);
      expect(service.unacknowledgedCount, 0);
    });

    test('addAlert adds to the list', () async {
      await service.addAlert(_testAlert('1', 'First'));
      await service.addAlert(_testAlert('2', 'Second'));

      final alerts = await service.getAlerts();
      expect(alerts, hasLength(2));
      // Newest first
      expect(alerts[0].id, '2');
      expect(alerts[1].id, '1');
    });

    test('acknowledgeAlert marks alert as acknowledged', () async {
      await service.addAlert(_testAlert('1', 'Test'));

      var alerts = await service.getAlerts();
      expect(alerts[0].acknowledged, false);
      expect(service.unacknowledgedCount, 1);

      await service.acknowledgeAlert('1');

      alerts = await service.getAlerts();
      expect(alerts[0].acknowledged, true);
      expect(service.unacknowledgedCount, 0);
    });

    test('persists alerts via storage', () async {
      await service.addAlert(_testAlert('1', 'Persisted'));

      // Create a new service instance with same storage
      final service2 = BlockchainAlertService(storage: storage);
      final alerts = await service2.getAlerts();
      expect(alerts, hasLength(1));
      expect(alerts[0].title, 'Persisted');
    });

    test('unacknowledgedCount tracks correctly', () async {
      await service.addAlert(_testAlert('1', 'A'));
      await service.addAlert(_testAlert('2', 'B'));
      await service.addAlert(_testAlert('3', 'C'));

      expect(service.unacknowledgedCount, 3);

      await service.acknowledgeAlert('2');
      expect(service.unacknowledgedCount, 2);

      await service.acknowledgeAlert('1');
      await service.acknowledgeAlert('3');
      expect(service.unacknowledgedCount, 0);
    });
  });
}

Alert _testAlert(String id, String title) => Alert(
      id: id,
      type: AlertType.vaultFunded,
      vaultId: 'vault-1',
      title: title,
      message: 'Test alert message',
      severity: AlertSeverity.info,
      timestamp: DateTime.now(),
    );
