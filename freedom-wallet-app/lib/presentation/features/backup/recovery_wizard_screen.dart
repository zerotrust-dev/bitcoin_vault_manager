import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/domain/models/device.dart';
import 'package:freedom_wallet/domain/models/recovery.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';
import 'package:freedom_wallet/presentation/common/widgets/step_indicator.dart';
import 'package:freedom_wallet/presentation/providers/device_provider.dart';
import 'package:freedom_wallet/presentation/providers/recovery_provider.dart';
import 'package:freedom_wallet/presentation/providers/settings_provider.dart';

class RecoveryWizardScreen extends ConsumerStatefulWidget {
  const RecoveryWizardScreen({super.key});

  @override
  ConsumerState<RecoveryWizardScreen> createState() =>
      _RecoveryWizardScreenState();
}

class _RecoveryWizardScreenState extends ConsumerState<RecoveryWizardScreen> {
  @override
  void dispose() {
    ref.read(recoveryProvider.notifier).cancelScan();
    super.dispose();
  }

  int get _currentStep {
    final phase = ref.read(recoveryProvider).phase;
    switch (phase) {
      case RecoveryState.idle:
      case RecoveryState.connecting:
        return 0;
      case RecoveryState.scanning:
        return 1;
      case RecoveryState.reviewing:
        return 2;
      case RecoveryState.confirming:
      case RecoveryState.complete:
        return 3;
      case RecoveryState.error:
        if (ref.read(recoveryProvider).result != null) return 2;
        if (ref.read(recoveryProvider).progress != null) return 1;
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recoveryState = ref.watch(recoveryProvider);

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
              child: switch (recoveryState.phase) {
                RecoveryState.idle ||
                RecoveryState.connecting =>
                  _buildConnectStep(),
                RecoveryState.scanning => _buildScanStep(recoveryState),
                RecoveryState.reviewing => _buildReviewStep(recoveryState),
                RecoveryState.confirming => _buildConfirmingStep(),
                RecoveryState.complete => _buildCompleteStep(recoveryState),
                RecoveryState.error => _buildErrorStep(recoveryState),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectStep() {
    final deviceAsync = ref.watch(pairedDeviceProvider);
    final connectionStatus = ref.watch(deviceConnectionStatusProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          connectionStatus == DeviceConnectionStatus.connected
              ? Icons.usb
              : Icons.usb_off,
          size: 64,
          color: connectionStatus == DeviceConnectionStatus.connected
              ? Colors.green
              : Colors.grey,
        ),
        const SizedBox(height: 24),
        const Text(
          'Connect your hardware wallet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll use your device\'s xpub to scan the blockchain\nfor existing vaults.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),
        deviceAsync.when(
          data: (device) {
            if (device != null) {
              return Column(
                children: [
                  Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.typeDisplayName} · ${device.fingerprint}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _startScan(device),
                      icon: const Icon(Icons.search),
                      label: const Text('Start Scanning'),
                    ),
                  ),
                ],
              );
            }
            return SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: connectionStatus == DeviceConnectionStatus.connecting
                    ? null
                    : () => ref
                        .read(pairedDeviceProvider.notifier)
                        .pairDevice(ConnectionMethod.usb),
                icon: connectionStatus == DeviceConnectionStatus.connecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.usb),
                label: Text(
                  connectionStatus == DeviceConnectionStatus.connecting
                      ? 'Connecting...'
                      : 'Connect Device',
                ),
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Column(
            children: [
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(pairedDeviceProvider.notifier)
                    .pairDevice(ConnectionMethod.usb),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startScan(DeviceInfo device) {
    final network = ref.read(settingsProvider).network;
    ref.read(recoveryProvider.notifier).startScan(
          primaryXpub: device.xpub,
          network: network,
        );
  }

  Widget _buildScanStep(RecoveryScreenState recoveryState) {
    final progress = recoveryState.progress;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Scanning blockchain...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (progress != null) ...[
            Text(
              progress.phaseDescription,
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(
                    Icons.search, '${progress.templatesChecked} checked'),
                const SizedBox(width: 16),
                _infoChip(Icons.account_balance_wallet,
                    '${progress.vaultsFound} found'),
              ],
            ),
          ] else
            Text(
              'Preparing scan...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => ref.read(recoveryProvider.notifier).cancelScan(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReviewStep(RecoveryScreenState recoveryState) {
    final result = recoveryState.result;
    if (result == null) return const SizedBox();

    if (result.recoveredVaults.isEmpty) {
      return _buildNoVaultsFound(result);
    }

    final selectedCount = recoveryState.selectedVaults.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, size: 32, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.recoveredVaults.length} vault${result.recoveredVaults.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Scanned ${result.addressesScanned} addresses in '
                    '${(result.durationMs / 1000).toStringAsFixed(1)}s',
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: result.recoveredVaults.length,
            itemBuilder: (context, index) {
              final vault = result.recoveredVaults[index];
              return Card(
                child: CheckboxListTile(
                  value: vault.selected,
                  onChanged: (_) => ref
                      .read(recoveryProvider.notifier)
                      .toggleVaultSelection(vault.vaultIndex),
                  title: Text(
                    '${vault.template.displayName} #${vault.vaultIndex}',
                  ),
                  subtitle:
                      BtcAmount(sats: vault.totalBalanceSats, fontSize: 14),
                  secondary: Icon(
                    vault.template.type == 'savings'
                        ? Icons.savings
                        : Icons.payment,
                    color: Colors.orange,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: selectedCount > 0 ? _confirmRecovery : null,
            child: Text(
              'Recover $selectedCount Vault${selectedCount == 1 ? '' : 's'}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoVaultsFound(RecoveryResult result) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 24),
          const Text(
            'No Vaults Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Scanned ${result.addressesScanned} addresses but found no vaults.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'Possible reasons:\n'
            '  - Haven\'t created a vault yet\n'
            '  - Using a different hardware wallet\n'
            '  - Vault was fully spent\n'
            '  - Wrong network selected',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => ref.read(recoveryProvider.notifier).reset(),
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => context.go('/onboarding/template'),
                child: const Text('Create New Vault'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRecovery() {
    final device = ref.read(pairedDeviceProvider).valueOrNull;
    if (device == null) return;

    final network = ref.read(settingsProvider).network;
    ref.read(recoveryProvider.notifier).confirmRecovery(
          primaryDevice: DeviceRef(
            fingerprint: device.fingerprint,
            name: device.name,
            xpub: device.xpub,
          ),
          network: network,
        );
  }

  Widget _buildConfirmingStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Saving recovered vaults...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep(RecoveryScreenState recoveryState) {
    final count = recoveryState.selectedVaults.length;

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
          Text(
            '$count vault${count == 1 ? ' has' : 's have'} been restored.',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                ref.read(recoveryProvider.notifier).reset();
                context.go('/dashboard');
              },
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStep(RecoveryScreenState recoveryState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          const Text(
            'Recovery Error',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            recoveryState.errorMessage ?? 'An unknown error occurred.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => ref.read(recoveryProvider.notifier).reset(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
