import 'package:freedom_wallet/domain/models/alert.dart';
import 'package:freedom_wallet/domain/models/device.dart';
import 'package:freedom_wallet/domain/models/transaction.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class MockData {
  static final trezorDevice = DeviceInfo(
    name: 'Trezor Model T',
    type: DeviceType.trezor,
    fingerprint: 'a1b2c3d4',
    xpub:
        'xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiKbERr4d5qkSmQGgRFmDBRK2HAFD99bazG3M9spqkzmraLke4YGpMtBX3X1m4SwcoAm8kDBvvhCJLk3',
    firmwareVersion: '2.6.3',
    role: DeviceRole.daily,
    connectionMethod: ConnectionMethod.usb,
    supportsTaproot: true,
    pairedAt: DateTime(2024, 1, 15),
  );

  static final coldcardDevice = DeviceInfo(
    name: 'Coldcard Mk4',
    type: DeviceType.coldcard,
    fingerprint: 'e5f6g7h8',
    xpub:
        'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYRVVStcCkpIy7idz6mNdMZe9Hg8x7aNnECYDhqoBHGtYFy',
    firmwareVersion: '5.2.0',
    role: DeviceRole.emergency,
    connectionMethod: ConnectionMethod.qrCode,
    supportsTaproot: true,
    pairedAt: DateTime(2024, 1, 15),
  );

  static final savingsVault = Vault(
    id: 'vault-savings-001',
    name: 'Long-term Savings',
    template: VaultTemplate.savings,
    balanceSats: 50000000, // 0.5 BTC
    address:
        'bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297',
    descriptor: 'tr(xpub.../86h/0h/0h)',
    status: VaultStatus.active,
    primaryDevice: DeviceRef(fingerprint: 'a1b2c3d4', name: 'Trezor Model T', xpub: 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiKbERr4d5qkSmQGgRFmDBRK2HAFD99bazG3M9spqkzmraLke4YGpMtBX3X1m4SwcoAm8kDBvvhCJLk3'),
    emergencyDevice: DeviceRef(fingerprint: 'e5f6g7h8', name: 'Coldcard Mk4', xpub: 'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYRVVStcCkpIy7idz6mNdMZe9Hg8x7aNnECYDhqoBHGtYFy'),
    network: Network.testnet,
    createdAt: DateTime(2024, 1, 20),
    lastActivityAt: DateTime(2024, 3, 1),
  );

  static final spendingVault = Vault(
    id: 'vault-spending-001',
    name: 'Daily Spending',
    template: VaultTemplate.spending,
    balanceSats: 5000000, // 0.05 BTC
    address:
        'bc1pxyz789abc456def123ghi789jkl012mno345pqr678stu901vwx234yz5678',
    descriptor: 'tr(xpub.../86h/0h/1h)',
    status: VaultStatus.active,
    primaryDevice: DeviceRef(fingerprint: 'a1b2c3d4', name: 'Trezor Model T', xpub: 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiKbERr4d5qkSmQGgRFmDBRK2HAFD99bazG3M9spqkzmraLke4YGpMtBX3X1m4SwcoAm8kDBvvhCJLk3'),
    network: Network.testnet,
    createdAt: DateTime(2024, 2, 10),
    lastActivityAt: DateTime(2024, 3, 5),
  );

  static final pendingVault = Vault(
    id: 'vault-pending-001',
    name: 'New Vault',
    template: VaultTemplate.savings,
    balanceSats: 0,
    address:
        'bc1pabc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890abc',
    descriptor: 'tr(xpub.../86h/0h/2h)',
    status: VaultStatus.awaitingFunding,
    primaryDevice: DeviceRef(fingerprint: 'a1b2c3d4', name: 'Trezor Model T', xpub: 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiKbERr4d5qkSmQGgRFmDBRK2HAFD99bazG3M9spqkzmraLke4YGpMtBX3X1m4SwcoAm8kDBvvhCJLk3'),
    network: Network.testnet,
    createdAt: DateTime(2024, 3, 10),
  );

  static final allVaults = [savingsVault, spendingVault, pendingVault];

  static final pendingTx = PendingTransaction(
    txid: 'abc123def456789012345678901234567890abcdef1234567890abcdef123456',
    amountSats: 1000000,
    destination: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
    broadcastHeight: 830000,
    unlockHeight: 831008,
    status: PendingStatus.delayActive,
    canCancel: true,
    broadcastAt: DateTime(2024, 3, 1),
  );

  static final alerts = [
    Alert(
      id: 'alert-001',
      type: AlertType.spendDetected,
      vaultId: 'vault-savings-001',
      title: 'Spend Detected',
      message:
          'A spend of 0.01 BTC was initiated from your Savings Vault. Did you authorize this?',
      severity: AlertSeverity.critical,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      actions: [
        const AlertAction(
          id: 'approve',
          label: 'Yes, I did this',
          type: AlertActionType.dismiss,
        ),
        const AlertAction(
          id: 'cancel',
          label: 'No! Cancel it',
          type: AlertActionType.cancelTransaction,
        ),
      ],
    ),
    Alert(
      id: 'alert-002',
      type: AlertType.timelockMaturing,
      vaultId: 'vault-spending-001',
      title: 'Timelock Maturing',
      message:
          'Your pending spend of 0.005 BTC will complete in approximately 12 hours.',
      severity: AlertSeverity.warning,
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      actions: [
        const AlertAction(
          id: 'view',
          label: 'View Details',
          type: AlertActionType.viewDetails,
        ),
      ],
    ),
    Alert(
      id: 'alert-003',
      type: AlertType.vaultFunded,
      vaultId: 'vault-savings-001',
      title: 'Vault Funded',
      message: 'Your Savings Vault received 0.1 BTC. New balance: 0.5 BTC.',
      severity: AlertSeverity.info,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      acknowledged: true,
    ),
  ];
}
