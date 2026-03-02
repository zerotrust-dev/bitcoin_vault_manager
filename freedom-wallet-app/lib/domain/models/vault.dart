enum Network {
  mainnet,
  testnet,
  signet,
  regtest,
}

enum VaultStatus {
  awaitingFunding,
  active,
  pendingSpend,
  empty,
  error,
}

enum RecoveryType {
  emergencyKey,
  timelockOnly,
  multiSig,
}

class VaultTemplate {
  final String type; // 'savings', 'spending', 'custom'
  final int delayBlocks;
  final RecoveryType? recoveryType;

  const VaultTemplate({
    required this.type,
    required this.delayBlocks,
    this.recoveryType,
  });

  static const savings = VaultTemplate(type: 'savings', delayBlocks: 1008);
  static const spending = VaultTemplate(type: 'spending', delayBlocks: 144);

  factory VaultTemplate.custom({
    required int delayBlocks,
    required RecoveryType recoveryType,
  }) =>
      VaultTemplate(
        type: 'custom',
        delayBlocks: delayBlocks,
        recoveryType: recoveryType,
      );

  String get displayName {
    switch (type) {
      case 'savings':
        return 'Savings Vault';
      case 'spending':
        return 'Spending Vault';
      case 'custom':
        return 'Custom Vault';
      default:
        return 'Unknown';
    }
  }

  String get delayDescription {
    if (delayBlocks >= 1008) return '~1 week';
    if (delayBlocks >= 144) return '~1 day';
    final hours = (delayBlocks * 10 / 60).round();
    if (hours > 0) return '~$hours hours';
    return '~${delayBlocks * 10} minutes';
  }
}

class Vault {
  final String id;
  final String name;
  final VaultTemplate template;
  final int balanceSats;
  final String address;
  final String descriptor;
  final VaultStatus status;
  final DeviceRef primaryDevice;
  final DeviceRef? emergencyDevice;
  final Network network;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final List<PendingTransactionRef> pendingTransactions;

  const Vault({
    required this.id,
    required this.name,
    required this.template,
    required this.balanceSats,
    required this.address,
    required this.descriptor,
    required this.status,
    required this.primaryDevice,
    this.emergencyDevice,
    required this.network,
    required this.createdAt,
    this.lastActivityAt,
    this.pendingTransactions = const [],
  });

  Vault copyWith({
    String? name,
    int? balanceSats,
    VaultStatus? status,
    DateTime? lastActivityAt,
    List<PendingTransactionRef>? pendingTransactions,
  }) {
    return Vault(
      id: id,
      name: name ?? this.name,
      template: template,
      balanceSats: balanceSats ?? this.balanceSats,
      address: address,
      descriptor: descriptor,
      status: status ?? this.status,
      primaryDevice: primaryDevice,
      emergencyDevice: emergencyDevice,
      network: network,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
    );
  }

  double get balanceBtc => balanceSats / 100000000;
}

/// Lightweight reference to avoid circular imports
class DeviceRef {
  final String fingerprint;
  final String name;

  const DeviceRef({required this.fingerprint, required this.name});
}

class PendingTransactionRef {
  final String txid;
  final int amountSats;

  const PendingTransactionRef({required this.txid, required this.amountSats});
}
