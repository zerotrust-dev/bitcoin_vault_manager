import 'transaction.dart';

enum AlertType {
  spendDetected,
  timelockMaturing,
  recoveryRecommended,
  transactionConfirmed,
  vaultFunded,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

enum AlertActionType {
  dismiss,
  cancelTransaction,
  viewDetails,
  emergencyRecovery,
}

class AlertAction {
  final String id;
  final String label;
  final AlertActionType type;

  const AlertAction({
    required this.id,
    required this.label,
    required this.type,
  });
}

class Alert {
  final String id;
  final AlertType type;
  final String vaultId;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final bool acknowledged;
  final PendingTransaction? transaction;
  final List<AlertAction> actions;

  const Alert({
    required this.id,
    required this.type,
    required this.vaultId,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.acknowledged = false,
    this.transaction,
    this.actions = const [],
  });

  Alert copyWith({bool? acknowledged}) {
    return Alert(
      id: id,
      type: type,
      vaultId: vaultId,
      title: title,
      message: message,
      severity: severity,
      timestamp: timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
      transaction: transaction,
      actions: actions,
    );
  }
}
