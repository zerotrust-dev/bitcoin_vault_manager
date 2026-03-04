import 'package:flutter_test/flutter_test.dart';
import 'package:freedom_wallet/data/mock/mock_recovery_service.dart';
import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

void main() {
  group('RecoveryModels', () {
    test('RecoveredVault defaults to selected', () {
      const vault = RecoveredVault(
        vaultIndex: 0,
        address: 'bc1p_test',
        template: VaultTemplate.savings,
        utxos: [],
        totalBalanceSats: 50000000,
      );
      expect(vault.selected, isTrue);
    });

    test('RecoveredVault copyWith toggles selected', () {
      const vault = RecoveredVault(
        vaultIndex: 0,
        address: 'bc1p_test',
        template: VaultTemplate.savings,
        utxos: [],
        totalBalanceSats: 50000000,
      );
      final toggled = vault.copyWith(selected: false);
      expect(toggled.selected, isFalse);
      expect(toggled.vaultIndex, 0);
      expect(toggled.address, 'bc1p_test');
    });

    test('RecoveredVault totalBalanceBtc converts correctly', () {
      const vault = RecoveredVault(
        vaultIndex: 0,
        address: 'bc1p_test',
        template: VaultTemplate.savings,
        utxos: [],
        totalBalanceSats: 50000000,
      );
      expect(vault.totalBalanceBtc, 0.5);
    });

    test('RecoveryProgress holds scan state', () {
      const progress = RecoveryProgress(
        currentIndex: 5,
        templatesChecked: 12,
        vaultsFound: 1,
        phaseDescription: 'Checking index 5 (savings)...',
      );
      expect(progress.currentIndex, 5);
      expect(progress.templatesChecked, 12);
      expect(progress.vaultsFound, 1);
    });

    test('RecoveryResult with no vaults', () {
      const result = RecoveryResult(
        success: true,
        recoveredVaults: [],
        addressesScanned: 40,
        durationMs: 5000,
      );
      expect(result.recoveredVaults, isEmpty);
      expect(result.addressesScanned, 40);
      expect(result.errorMessage, isNull);
    });

    test('RecoveryResult with error message', () {
      const result = RecoveryResult(
        success: false,
        recoveredVaults: [],
        addressesScanned: 10,
        durationMs: 1000,
        errorMessage: 'Scan cancelled by user',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, 'Scan cancelled by user');
    });
  });

  group('MockRecoveryService', () {
    late MockRecoveryService service;

    setUp(() {
      service = MockRecoveryService();
    });

    test('scanForVaults returns 2 vaults', () async {
      final result = await service.scanForVaults(
        primaryXpub: 'xpub_test',
        network: Network.testnet,
      );
      expect(result.success, isTrue);
      expect(result.recoveredVaults, hasLength(2));
      expect(result.recoveredVaults[0].template.type, 'savings');
      expect(result.recoveredVaults[0].totalBalanceSats, 50000000);
      expect(result.recoveredVaults[1].template.type, 'spending');
      expect(result.recoveredVaults[1].totalBalanceSats, 5000000);
    });

    test('scanForVaults reports progress', () async {
      final progressUpdates = <RecoveryProgress>[];
      await service.scanForVaults(
        primaryXpub: 'xpub_test',
        network: Network.testnet,
        onProgress: (p) => progressUpdates.add(p),
      );
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last.vaultsFound, 2);
      expect(progressUpdates.last.templatesChecked, 25);
    });

    test('scanForVaults reports addressesScanned', () async {
      final result = await service.scanForVaults(
        primaryXpub: 'xpub_test',
        network: Network.testnet,
      );
      expect(result.addressesScanned, 25);
    });

    test('cancelScan does not throw', () {
      expect(() => service.cancelScan(), returnsNormally);
    });
  });
}
