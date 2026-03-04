import 'package:freedom_wallet/domain/models/utxo.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

/// A vault discovered during blockchain scanning.
class RecoveredVault {
  final int vaultIndex;
  final String address;
  final VaultTemplate template;
  final List<Utxo> utxos;
  final int totalBalanceSats;
  final bool selected;

  const RecoveredVault({
    required this.vaultIndex,
    required this.address,
    required this.template,
    required this.utxos,
    required this.totalBalanceSats,
    this.selected = true,
  });

  RecoveredVault copyWith({bool? selected}) => RecoveredVault(
        vaultIndex: vaultIndex,
        address: address,
        template: template,
        utxos: utxos,
        totalBalanceSats: totalBalanceSats,
        selected: selected ?? this.selected,
      );

  double get totalBalanceBtc => totalBalanceSats / 100000000;
}

/// Progress reported during blockchain scanning.
class RecoveryProgress {
  final int currentIndex;
  final int templatesChecked;
  final int vaultsFound;
  final String phaseDescription;

  const RecoveryProgress({
    required this.currentIndex,
    required this.templatesChecked,
    required this.vaultsFound,
    required this.phaseDescription,
  });
}

/// Final result of a recovery scan.
class RecoveryResult {
  final bool success;
  final List<RecoveredVault> recoveredVaults;
  final int addressesScanned;
  final int durationMs;
  final String? errorMessage;

  const RecoveryResult({
    required this.success,
    required this.recoveredVaults,
    required this.addressesScanned,
    required this.durationMs,
    this.errorMessage,
  });
}
