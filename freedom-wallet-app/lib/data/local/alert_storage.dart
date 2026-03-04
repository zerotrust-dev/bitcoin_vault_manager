import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freedom_wallet/domain/models/alert.dart';
import 'package:freedom_wallet/domain/models/transaction.dart';

const _alertsKey = 'alert_list';

/// Persists alerts via FlutterSecureStorage.
class AlertStorage {
  final FlutterSecureStorage _storage;

  AlertStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<Alert>> loadAlerts() async {
    final json = await _storage.read(key: _alertsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => _alertFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAlerts(List<Alert> alerts) async {
    final json = jsonEncode(alerts.map(_alertToJson).toList());
    await _storage.write(key: _alertsKey, value: json);
  }

  Future<void> clearAlerts() async {
    await _storage.delete(key: _alertsKey);
  }

  static Map<String, dynamic> _alertToJson(Alert a) => {
        'id': a.id,
        'type': a.type.index,
        'vault_id': a.vaultId,
        'title': a.title,
        'message': a.message,
        'severity': a.severity.index,
        'timestamp': a.timestamp.toIso8601String(),
        'acknowledged': a.acknowledged,
        if (a.transaction != null)
          'transaction': {
            'txid': a.transaction!.txid,
            'amount_sats': a.transaction!.amountSats,
            'destination': a.transaction!.destination,
            'broadcast_height': a.transaction!.broadcastHeight,
            'unlock_height': a.transaction!.unlockHeight,
            'status': a.transaction!.status.index,
            'can_cancel': a.transaction!.canCancel,
            'broadcast_at': a.transaction!.broadcastAt.toIso8601String(),
          },
        'actions': a.actions
            .map((act) => {
                  'id': act.id,
                  'label': act.label,
                  'type': act.type.index,
                })
            .toList(),
      };

  static Alert _alertFromJson(Map<String, dynamic> j) {
    PendingTransaction? tx;
    if (j['transaction'] != null) {
      final t = j['transaction'] as Map<String, dynamic>;
      tx = PendingTransaction(
        txid: t['txid'] as String,
        amountSats: t['amount_sats'] as int,
        destination: t['destination'] as String,
        broadcastHeight: t['broadcast_height'] as int,
        unlockHeight: t['unlock_height'] as int,
        status: PendingStatus.values[t['status'] as int],
        canCancel: t['can_cancel'] as bool,
        broadcastAt: DateTime.parse(t['broadcast_at'] as String),
      );
    }

    return Alert(
      id: j['id'] as String,
      type: AlertType.values[j['type'] as int],
      vaultId: j['vault_id'] as String,
      title: j['title'] as String,
      message: j['message'] as String,
      severity: AlertSeverity.values[j['severity'] as int],
      timestamp: DateTime.parse(j['timestamp'] as String),
      acknowledged: j['acknowledged'] as bool? ?? false,
      transaction: tx,
      actions: (j['actions'] as List<dynamic>?)
              ?.map((a) {
                final m = a as Map<String, dynamic>;
                return AlertAction(
                  id: m['id'] as String,
                  label: m['label'] as String,
                  type: AlertActionType.values[m['type'] as int],
                );
              })
              .toList() ??
          [],
    );
  }
}
