import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/presentation/common/widgets/step_indicator.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';

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
  String _feeLevel = 'medium';
  bool _signing = false;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
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
    return Column(
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
        const Spacer(),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delay',
                        style: TextStyle(color: Colors.grey)),
                    const Text('~1 week (1008 blocks)',
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
                onPressed: () => setState(() => _currentStep = 3),
                child: const Text('Approve on Device'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignStep() {
    if (!_signing) {
      // Start simulated signing
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _signing = true;
            _currentStep = 4;
          });
        }
      });
    }

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
