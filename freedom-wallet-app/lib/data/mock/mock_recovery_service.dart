import 'package:freedom_wallet/domain/interfaces/recovery_service.dart';
import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class MockRecoveryService implements RecoveryService {
  @override
  Future<RecoveryResult> scanForVaults({
    required String primaryXpub,
    String? emergencyXpub,
    required Network network,
    int gapLimit = 20,
    void Function(RecoveryProgress progress)? onProgress,
  }) async {
    // Simulate scanning with progress callbacks
    for (int i = 0; i < 25; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      onProgress?.call(RecoveryProgress(
        currentIndex: i ~/ 2,
        templatesChecked: i + 1,
        vaultsFound: i >= 10 ? 2 : (i >= 4 ? 1 : 0),
        phaseDescription:
            'Checking index ${i ~/ 2} (${i.isEven ? 'savings' : 'spending'})...',
      ));
    }

    return RecoveryResult(
      success: true,
      recoveredVaults: [
        RecoveredVault(
          vaultIndex: 0,
          address: 'bc1p_mock_savings_addr_0',
          template: VaultTemplate.savings,
          utxos: const [],
          totalBalanceSats: 50000000,
        ),
        RecoveredVault(
          vaultIndex: 1,
          address: 'bc1p_mock_spending_addr_1',
          template: VaultTemplate.spending,
          utxos: const [],
          totalBalanceSats: 5000000,
        ),
      ],
      addressesScanned: 25,
      durationMs: 3000,
    );
  }

  @override
  void cancelScan() {}
}
