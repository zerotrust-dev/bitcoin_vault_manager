import 'package:freedom_wallet/data/datasources/esplora_client.dart';
import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/data/services/rust_vault_service.dart';
import 'package:freedom_wallet/domain/interfaces/recovery_service.dart';
import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class RecoveryServiceImpl implements RecoveryService {
  final RustFfi _ffi;
  final EsploraClient _esplora;
  bool _cancelled = false;

  static const _templatesToScan = [
    VaultTemplate.savings,
    VaultTemplate.spending,
  ];

  RecoveryServiceImpl({required RustFfi ffi, required EsploraClient esplora})
      : _ffi = ffi,
        _esplora = esplora;

  @override
  Future<RecoveryResult> scanForVaults({
    required String primaryXpub,
    String? emergencyXpub,
    required Network network,
    int gapLimit = 20,
    void Function(RecoveryProgress progress)? onProgress,
  }) async {
    _cancelled = false;
    final stopwatch = Stopwatch()..start();
    final List<RecoveredVault> found = [];
    int gapCounter = 0;
    int totalChecked = 0;
    int vaultIndex = 0;

    while (gapCounter < gapLimit && !_cancelled) {
      bool foundAtThisIndex = false;

      for (final template in _templatesToScan) {
        if (_cancelled) break;

        totalChecked++;
        onProgress?.call(RecoveryProgress(
          currentIndex: vaultIndex,
          templatesChecked: totalChecked,
          vaultsFound: found.length,
          phaseDescription:
              'Checking index $vaultIndex (${template.type})...',
        ));

        try {
          final rustTemplate = RustVaultService.templateToRustJson(template);

          final result = _ffi.generateVaultAddress(
            primaryXpub: primaryXpub,
            emergencyXpub: emergencyXpub,
            template: rustTemplate,
            vaultIndex: vaultIndex,
            network: network.index,
          );

          final address = result['address'] as String;
          final utxos = await _esplora.getUtxos(address);

          if (utxos.isNotEmpty) {
            final totalSats = utxos.fold<int>(0, (sum, u) => sum + u.value);
            found.add(RecoveredVault(
              vaultIndex: vaultIndex,
              address: address,
              template: template,
              utxos: utxos,
              totalBalanceSats: totalSats,
            ));
            foundAtThisIndex = true;
          }
        } catch (_) {
          // Individual address check failures are non-fatal; continue scanning
        }

        // Rate limit Esplora requests
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (foundAtThisIndex) {
        gapCounter = 0;
      } else {
        gapCounter++;
      }

      vaultIndex++;
    }

    stopwatch.stop();
    return RecoveryResult(
      success: !_cancelled,
      recoveredVaults: found,
      addressesScanned: totalChecked,
      durationMs: stopwatch.elapsedMilliseconds,
      errorMessage: _cancelled ? 'Scan cancelled by user' : null,
    );
  }

  @override
  void cancelScan() {
    _cancelled = true;
  }
}
