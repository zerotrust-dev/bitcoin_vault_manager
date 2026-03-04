import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/domain/errors/blockchain_errors.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/models/utxo.dart';
import 'package:freedom_wallet/presentation/common/widgets/step_indicator.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';
import 'package:freedom_wallet/presentation/providers/device_provider.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';
import 'package:freedom_wallet/presentation/providers/watcher_provider.dart';

class SpendWizardScreen extends ConsumerStatefulWidget {
  final String vaultId;

  const SpendWizardScreen({super.key, required this.vaultId});

  @override
  ConsumerState<SpendWizardScreen> createState() => _SpendWizardScreenState();
}

class _SpendWizardScreenState extends ConsumerState<SpendWizardScreen> {
  int _currentStep = 0;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _manualUtxoController = TextEditingController();
  String _feeLevel = 'medium';
  bool _signing = false;
  bool _broadcasting = false;
  String? _signError;
  String? _txHex;
  String? _broadcastTxid;
  String? _broadcastError;
  bool _showManualUtxo = false;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _manualUtxoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Bitcoin')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: StepIndicator(
              totalSteps: 5,
              currentStep: _currentStep,
              labels: const [
                'Address',
                'Amount',
                'Review',
                'Sign',
                'Done',
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (_currentStep) {
                0 => _buildAddressStep(),
                1 => _buildAmountStep(),
                2 => _buildReviewStep(),
                3 => _buildSignStep(),
                4 => _buildDoneStep(),
                _ => const SizedBox(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where do you want to send?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Destination Address',
            hintText: 'bc1q...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            _addressController.text =
                'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
          },
          icon: const Icon(Icons.paste, size: 16),
          label: const Text('Paste from clipboard'),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _addressController.text.isNotEmpty
                ? () => setState(() => _currentStep = 1)
                : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountStep() {
    // Resolve vault address for UTXO fetching
    final vaults = ref.watch(vaultsProvider);
    final vault = vaults.valueOrNull?.firstWhere(
      (v) => v.id == widget.vaultId,
      orElse: () => vaults.valueOrNull!.first,
    );
    final vaultAddress = vault?.address;

    // Fetch UTXOs from blockchain
    final utxosAsync = vaultAddress != null
        ? ref.watch(vaultUtxosProvider(vaultAddress))
        : null;

    // Fetch fee estimates
    final feesAsync = ref.watch(feeEstimatesProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How much do you want to send?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // UTXO summary from blockchain
          if (utxosAsync != null)
            utxosAsync.when(
              data: (utxos) {
                final totalSats =
                    utxos.fold<int>(0, (sum, u) => sum + u.value);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${utxos.length} UTXO${utxos.length == 1 ? '' : 's'} available',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              BtcAmount(sats: totalSats, fontSize: 13),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => ref
                              .invalidate(vaultUtxosProvider(vaultAddress!)),
                          tooltip: 'Refresh UTXOs',
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading UTXOs from blockchain...'),
                    ],
                  ),
                ),
              ),
              error: (e, _) => Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Could not fetch UTXOs: $e',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () => ref
                            .invalidate(vaultUtxosProvider(vaultAddress!)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (BTC)',
              hintText: '0.001',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_bitcoin),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Fee Priority',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Fee selector with real estimates
          feesAsync.when(
            data: (fees) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'low',
                      label: Text(
                          'Low\n${fees.lowPriority.toStringAsFixed(1)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'medium',
                      label: Text(
                          'Med\n${fees.mediumPriority.toStringAsFixed(1)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'high',
                      label: Text(
                          'High\n${fees.highPriority.toStringAsFixed(1)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_feeLevel},
                  onSelectionChanged: (v) =>
                      setState(() => _feeLevel = v.first),
                ),
                const SizedBox(height: 4),
                Text(
                  'sat/vB',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            loading: () => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'high', label: Text('High')),
              ],
              selected: {_feeLevel},
              onSelectionChanged: (v) =>
                  setState(() => _feeLevel = v.first),
            ),
            error: (_, _) => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low ~2')),
                ButtonSegment(value: 'medium', label: Text('Med ~10')),
                ButtonSegment(value: 'high', label: Text('High ~25')),
              ],
              selected: {_feeLevel},
              onSelectionChanged: (v) =>
                  setState(() => _feeLevel = v.first),
            ),
          ),

          const SizedBox(height: 16),

          // Advanced: manual UTXO fallback
          InkWell(
            onTap: () => setState(() => _showManualUtxo = !_showManualUtxo),
            child: Row(
              children: [
                Icon(
                  _showManualUtxo
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Advanced: enter UTXO manually',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (_showManualUtxo) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _manualUtxoController,
              decoration: const InputDecoration(
                labelText: 'txid:vout:amount_sats',
                hintText: 'abc123...def:0:100000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.input),
                helperText: 'Overrides auto-fetched UTXOs',
              ),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _amountController.text.isNotEmpty
                      ? () => setState(() => _currentStep = 2)
                      : null,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final amountSats =
        ((double.tryParse(_amountController.text) ?? 0) * 100000000).round();

    // Use real fee rate
    final fees = ref.watch(feeEstimatesProvider).valueOrNull;
    final feeRate = _feeRateFromEstimates(fees);
    // Estimate fee: ~141 vbytes for a typical Taproot spend
    final feeSats = (feeRate * 141).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Transaction',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReviewRow(label: 'To', value: _addressController.text),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount',
                        style: TextStyle(color: Colors.grey)),
                    BtcAmount(sats: amountSats, fontSize: 14),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fee', style: TextStyle(color: Colors.grey)),
                    BtcAmount(sats: feeSats, fontSize: 14),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fee rate',
                        style: TextStyle(color: Colors.grey)),
                    Text('${feeRate.toStringAsFixed(1)} sat/vB',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const Divider(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delay', style: TextStyle(color: Colors.grey)),
                    Text('~1 week (1008 blocks)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.orange.withValues(alpha: 0.1),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This transaction will complete after the timelock delay. '
                    'You can cancel it during this period.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (_signError != null) ...[
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _signError!,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _signing ? null : () => _buildAndSign(),
                child: const Text('Approve on Device'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint, size: 64, color: Colors.orange),
          SizedBox(height: 24),
          Text(
            'Approve on your device',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Check the transaction details on your hardware wallet\nand confirm to sign.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 32),
          CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    final completionDate = DateTime.now().add(const Duration(days: 7));

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _broadcastError != null ? Icons.error_outline : Icons.schedule,
              size: 64,
              color: _broadcastError != null ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              _broadcasting
                  ? 'Broadcasting...'
                  : _broadcastError != null
                      ? 'Broadcast Failed'
                      : 'Transaction Broadcast',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_broadcasting)
              const CircularProgressIndicator()
            else if (_broadcastError != null) ...[
              Text(
                _broadcastError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _broadcast,
                child: const Text('Retry Broadcast'),
              ),
            ] else ...[
              const Text(
                'Your transaction is now in the delay period.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status',
                              style: TextStyle(color: Colors.grey)),
                          Text('Delay Active',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Completes',
                              style: TextStyle(color: Colors.grey)),
                          Text(
                            '${completionDate.day}/${completionDate.month}/${completionDate.year}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Blocks remaining',
                              style: TextStyle(color: Colors.grey)),
                          Text('1008',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (_broadcastTxid != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Txid',
                                style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                '${_broadcastTxid!.substring(0, _broadcastTxid!.length.clamp(0, 16))}...',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Back to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parse manual UTXO input in format "txid:vout:amount_sats".
  Map<String, dynamic>? _parseManualUtxo() {
    final input = _manualUtxoController.text.trim();
    if (input.isEmpty) return null;
    final parts = input.split(':');
    if (parts.length != 3) return null;
    final txid = parts[0];
    final vout = int.tryParse(parts[1]);
    final amount = int.tryParse(parts[2]);
    if (vout == null || amount == null) return null;
    return {
      'txid': txid,
      'vout': vout,
      'value': amount,
    };
  }

  double _feeRateFromEstimates(FeeEstimates? fees) {
    if (fees == null) {
      return _feeLevel == 'low'
          ? 2.0
          : _feeLevel == 'medium'
              ? 10.0
              : 25.0;
    }
    return _feeLevel == 'low'
        ? fees.lowPriority
        : _feeLevel == 'medium'
            ? fees.mediumPriority
            : fees.highPriority;
  }

  /// Resolve UTXOs: manual override > auto-fetched from blockchain.
  List<Map<String, dynamic>>? _resolveUtxos() {
    // Manual override takes priority
    if (_showManualUtxo && _manualUtxoController.text.trim().isNotEmpty) {
      final manual = _parseManualUtxo();
      if (manual != null) return [manual];
      return null; // invalid format
    }

    // Auto-fetched UTXOs
    final vaults = ref.read(vaultsProvider).valueOrNull;
    final vault = vaults?.firstWhere((v) => v.id == widget.vaultId);
    if (vault == null) return null;

    final utxosAsync = ref.read(vaultUtxosProvider(vault.address));
    final utxos = utxosAsync.valueOrNull;
    if (utxos == null || utxos.isEmpty) return null;

    return utxos.map((u) => u.toFfiJson()).toList();
  }

  Future<void> _buildAndSign() async {
    setState(() {
      _signError = null;
      _currentStep = 3;
      _signing = true;
    });

    try {
      final ffi = ref.read(rustFfiProvider);

      // Get vault data
      final vaults = ref.read(vaultsProvider);
      final vault = vaults.valueOrNull?.firstWhere(
        (v) => v.id == widget.vaultId,
      );

      if (vault == null) {
        setState(() {
          _signError = 'Vault not found';
          _currentStep = 2;
          _signing = false;
        });
        return;
      }

      // Resolve UTXOs
      final utxos = _resolveUtxos();
      if (utxos == null || utxos.isEmpty) {
        setState(() {
          _signError = _showManualUtxo
              ? 'Invalid UTXO. Enter in format: txid:vout:amount_sats'
              : 'No UTXOs available. Fund this vault first or enter a UTXO manually.';
          _currentStep = 2;
          _signing = false;
        });
        return;
      }

      // Get fee rate
      final fees = ref.read(feeEstimatesProvider).valueOrNull;
      final feeRate = _feeRateFromEstimates(fees);

      // Build vault config for Rust FFI
      final vaultConfig = {
        'primary_xpub':
            vault.primaryDevice.xpub ?? vault.primaryDevice.fingerprint,
        if (vault.emergencyDevice != null)
          'emergency_xpub': vault.emergencyDevice!.xpub ??
              vault.emergencyDevice!.fingerprint,
        'template': {
          'type': vault.template.type,
          'delay_blocks': vault.template.delayBlocks,
        },
        'vault_index': 0,
        'network': vault.network.index,
      };

      // Build PSBT via Rust FFI
      final intent = {
        'destination': _addressController.text,
        'fee_rate': feeRate,
      };

      final psbtResult = ffi.buildDelayedSpendPsbt(
        intent: intent,
        utxos: utxos,
        vaultConfig: vaultConfig,
      );

      final unsignedPsbt = psbtResult['psbt_base64'] as String;

      // Sign on device
      final deviceNotifier = ref.read(pairedDeviceProvider.notifier);
      final signedPsbt = await deviceNotifier.signPsbt(unsignedPsbt);

      // Finalize PSBT
      final finalResult = ffi.finalizePsbt(signedPsbt);
      final txHex = finalResult['tx_hex'] as String?;

      if (mounted) {
        setState(() {
          _txHex = txHex;
          _currentStep = 4;
          _signing = false;
        });
        // Auto-broadcast
        _broadcast();
      }
    } on DeviceUserDeniedException {
      if (mounted) {
        setState(() {
          _signError = 'You rejected the transaction on your device.';
          _currentStep = 2;
          _signing = false;
        });
      }
    } on DeviceDisconnectedException {
      if (mounted) {
        setState(() {
          _signError = 'Device disconnected. Reconnect and try again.';
          _currentStep = 2;
          _signing = false;
        });
      }
    } on DeviceNotFoundException {
      if (mounted) {
        setState(() {
          _signError = 'No device connected. Pair your device first.';
          _currentStep = 2;
          _signing = false;
        });
      }
    } on RustCoreException catch (e) {
      if (mounted) {
        setState(() {
          _signError = 'PSBT error: ${e.message}';
          _currentStep = 2;
          _signing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _signError = 'Unexpected error: $e';
          _currentStep = 2;
          _signing = false;
        });
      }
    }
  }

  Future<void> _broadcast() async {
    if (_txHex == null) return;
    setState(() {
      _broadcasting = true;
      _broadcastError = null;
    });

    try {
      final watcher = ref.read(watcherServiceProvider);
      final result = await watcher.broadcastTransaction(_txHex!);

      if (mounted) {
        if (result.success) {
          setState(() {
            _broadcastTxid = result.txid;
            _broadcasting = false;
          });
          // Refresh UTXOs and vault data
          final vaults = ref.read(vaultsProvider).valueOrNull;
          final vault = vaults?.firstWhere((v) => v.id == widget.vaultId);
          if (vault != null) {
            ref.invalidate(vaultUtxosProvider(vault.address));
          }
          ref.invalidate(vaultsProvider);
          // Trigger a poll to update balances
          ref.read(vaultMonitorProvider.notifier).pollNow();
        } else {
          setState(() {
            _broadcastError = result.error ?? 'Broadcast rejected';
            _broadcasting = false;
          });
        }
      }
    } on BlockchainException catch (e) {
      if (mounted) {
        setState(() {
          _broadcastError = e.message;
          _broadcasting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _broadcastError = 'Broadcast failed: $e';
          _broadcasting = false;
        });
      }
    }
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
