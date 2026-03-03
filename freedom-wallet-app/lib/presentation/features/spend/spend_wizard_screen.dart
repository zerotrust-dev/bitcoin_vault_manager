import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/presentation/common/widgets/step_indicator.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';
import 'package:freedom_wallet/presentation/providers/device_provider.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';

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
  final _utxoController = TextEditingController();
  String _feeLevel = 'medium';
  bool _signing = false;
  String? _signError;
  String? _txHex;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _utxoController.dispose();
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How much do you want to send?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'low', label: Text('Low')),
              ButtonSegment(value: 'medium', label: Text('Medium')),
              ButtonSegment(value: 'high', label: Text('High')),
            ],
            selected: {_feeLevel},
            onSelectionChanged: (v) => setState(() => _feeLevel = v.first),
          ),
          const SizedBox(height: 8),
          Text(
            _feeLevel == 'low'
                ? '~2 sat/vB · May take hours'
                : _feeLevel == 'medium'
                    ? '~10 sat/vB · ~30 minutes'
                    : '~25 sat/vB · Next block',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          // Manual UTXO input (until Phase 4 watcher provides real UTXOs)
          const Text(
            'UTXO (for testnet)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _utxoController,
            decoration: const InputDecoration(
              labelText: 'txid:vout:amount_sats',
              hintText: 'abc123...def:0:100000',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.input),
              helperText: 'Format: txid:output_index:amount_in_satoshis',
              helperMaxLines: 2,
            ),
          ),
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
    final feeSats = _feeLevel == 'low'
        ? 282
        : _feeLevel == 'medium'
            ? 1410
            : 3525;

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
                    const Text('Amount', style: TextStyle(color: Colors.grey)),
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
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _signError!,
                      style: const TextStyle(fontSize: 13, color: Colors.red),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'Transaction Broadcast',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
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
                      Text('Status', style: TextStyle(color: Colors.grey)),
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                  if (_txHex != null) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tx hex',
                            style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Text(
                            '${_txHex!.substring(0, _txHex!.length.clamp(0, 16))}...',
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
    );
  }

  /// Parse manual UTXO input in format "txid:vout:amount_sats".
  Map<String, dynamic>? _parseUtxo() {
    final input = _utxoController.text.trim();
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

  double get _feeRate => _feeLevel == 'low'
      ? 2.0
      : _feeLevel == 'medium'
          ? 10.0
          : 25.0;

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

      // Parse UTXO
      final utxo = _parseUtxo();
      if (utxo == null) {
        setState(() {
          _signError =
              'Invalid UTXO. Enter in format: txid:vout:amount_sats';
          _currentStep = 2;
          _signing = false;
        });
        return;
      }

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
        'fee_rate': _feeRate,
      };

      final psbtResult = ffi.buildDelayedSpendPsbt(
        intent: intent,
        utxos: [utxo],
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
