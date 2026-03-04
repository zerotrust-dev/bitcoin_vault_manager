import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/domain/models/alert.dart';
import 'package:freedom_wallet/presentation/providers/alert_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No alerts', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return _AlertCard(alert: alert);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final Alert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon) = switch (alert.severity) {
      AlertSeverity.critical => (Colors.red, Icons.warning),
      AlertSeverity.warning => (Colors.orange, Icons.info),
      AlertSeverity.info => (Colors.blue, Icons.notifications),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alert.acknowledged
            ? BorderSide.none
            : BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: alert.acknowledged ? Colors.grey : null,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(alert.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: TextStyle(
                fontSize: 14,
                color: alert.acknowledged ? Colors.grey : null,
              ),
            ),
            if (alert.actions.isNotEmpty && !alert.acknowledged) ...[
              const SizedBox(height: 12),
              Row(
                children: alert.actions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildActionButton(context, ref, action),
                  );
                }).toList(),
              ),
            ],
            if (alert.acknowledged)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Acknowledged',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, WidgetRef ref, AlertAction action) {
    switch (action.type) {
      case AlertActionType.dismiss:
        return ElevatedButton(
          onPressed: () => _acknowledge(ref),
          child: Text(action.label),
        );
      case AlertActionType.viewDetails:
        return ElevatedButton(
          onPressed: () => context.go('/spend/${alert.vaultId}'),
          child: Text(action.label),
        );
      case AlertActionType.cancelTransaction:
        return OutlinedButton(
          onPressed: () => _showCancelConfirmation(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: Text(action.label),
        );
      case AlertActionType.emergencyRecovery:
        return OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Emergency recovery coming in Phase 5')),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: Text(action.label),
        );
    }
  }

  void _acknowledge(WidgetRef ref) {
    final service = ref.read(alertServiceProvider);
    service.acknowledgeAlert(alert.id);
    ref.invalidate(alertsProvider);
  }

  void _showCancelConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transaction?'),
        content: const Text(
          'This will initiate an emergency key-path spend to move your funds '
          'back to safety. You will need your hardware wallet to sign.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _acknowledge(ref);
              context.go('/spend/${alert.vaultId}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Transaction'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
