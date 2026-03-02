import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/presentation/common/widgets/step_indicator.dart';

class RecoveryWizardScreen extends StatefulWidget {
  const RecoveryWizardScreen({super.key});

  @override
  State<RecoveryWizardScreen> createState() => _RecoveryWizardScreenState();
}

class _RecoveryWizardScreenState extends State<RecoveryWizardScreen> {
  int _currentStep = 0;
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Wizard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: StepIndicator(
              totalSteps: 4,
              currentStep: _currentStep,
              labels: const ['Connect', 'Scan', 'Review', 'Confirm'],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (_currentStep) {
                0 => _buildConnectStep(),
                1 => _buildScanStep(),
                2 => _buildReviewStep(),
                3 => _buildConfirmStep(),
                _ => const SizedBox(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.usb, size: 64, color: Colors.grey),
        const SizedBox(height: 24),
        const Text(
          'Connect your hardware wallet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll use your seed phrase to scan the blockchain\nfor existing vaults.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => setState(() => _currentStep = 1),
          icon: const Icon(Icons.search),
          label: const Text('Connect & Scan'),
        ),
      ],
    );
  }

  Widget _buildScanStep() {
    if (!_scanning) {
      _scanning = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _currentStep = 2;
          });
        }
      });
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Scanning blockchain...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Looking for vaults associated with your seed phrase.\nThis may take a moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 48, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Vaults Found!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'We found the following vaults on the blockchain:',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings, color: Colors.orange),
            title: const Text('Long-term Savings'),
            subtitle: const Text('0.50000000 BTC · Savings Vault'),
            trailing: const Icon(Icons.check, color: Colors.green),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.orange),
            title: const Text('Daily Spending'),
            subtitle: const Text('0.05000000 BTC · Spending Vault'),
            trailing: const Icon(Icons.check, color: Colors.green),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 3),
            child: const Text('Recover These Vaults'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Recovery Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '2 vaults have been restored successfully.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}
