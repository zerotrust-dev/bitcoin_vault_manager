enum SpendPath {
  delayed,
  emergency,
}

enum PendingStatus {
  mempool,
  delayActive,
  ready,
  canceled,
  completed,
}

class SpendIntent {
  final String vaultId;
  final String destination;
  final int? amountSats;
  final double feeRate;
  final SpendPath pathType;

  const SpendIntent({
    required this.vaultId,
    required this.destination,
    this.amountSats,
    required this.feeRate,
    required this.pathType,
  });
}

class TransactionSummary {
  final String fromVault;
  final String toAddress;
  final int amountSats;
  final int feeSats;
  final SpendPath pathType;
  final int? delayBlocks;
  final DateTime? estimatedCompletion;

  const TransactionSummary({
    required this.fromVault,
    required this.toAddress,
    required this.amountSats,
    required this.feeSats,
    required this.pathType,
    this.delayBlocks,
    this.estimatedCompletion,
  });

  double get amountBtc => amountSats / 100000000;
  double get feeBtc => feeSats / 100000000;
}

class PendingTransaction {
  final String txid;
  final int amountSats;
  final String destination;
  final int broadcastHeight;
  final int unlockHeight;
  final PendingStatus status;
  final bool canCancel;
  final DateTime broadcastAt;

  const PendingTransaction({
    required this.txid,
    required this.amountSats,
    required this.destination,
    required this.broadcastHeight,
    required this.unlockHeight,
    required this.status,
    required this.canCancel,
    required this.broadcastAt,
  });

  double get amountBtc => amountSats / 100000000;

  int get remainingBlocks {
    // Mock: assume current height is broadcastHeight + some blocks
    return unlockHeight - broadcastHeight;
  }
}

class BroadcastResult {
  final String txid;
  final bool success;
  final String? error;

  const BroadcastResult({
    required this.txid,
    required this.success,
    this.error,
  });
}
