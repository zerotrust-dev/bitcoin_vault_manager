import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

/// Service for recovering vaults by scanning the blockchain.
abstract class RecoveryService {
  /// Scan blockchain for existing vaults associated with the given xpub.
  ///
  /// Derives deterministic addresses for each vault index and template type,
  /// then checks the blockchain for UTXOs at those addresses.
  /// Scanning stops after [gapLimit] consecutive empty indices.
  Future<RecoveryResult> scanForVaults({
    required String primaryXpub,
    String? emergencyXpub,
    required Network network,
    int gapLimit = 20,
    void Function(RecoveryProgress progress)? onProgress,
  });

  /// Cancel an in-progress scan.
  void cancelScan();
}
