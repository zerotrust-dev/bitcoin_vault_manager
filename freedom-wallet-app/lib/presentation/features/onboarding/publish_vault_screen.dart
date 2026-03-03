import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/presentation/providers/device_provider.dart';
import 'package:freedom_wallet/presentation/providers/onboarding_provider.dart';

class PublishVaultScreen extends ConsumerStatefulWidget {
  const PublishVaultScreen({super.key});

  @override
  ConsumerState<PublishVaultScreen> createState() => _PublishVaultScreenState();
}

class _PublishVaultScreenState extends ConsumerState<PublishVaultScreen> {
  bool _deviceVerified = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    // Generate address on screen load, using real xpub from paired device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pairedDevice = ref.read(pairedDeviceProvider).valueOrNull;
      ref.read(onboardingProvider.notifier).publishVault(
            primaryXpub: pairedDevice?.xpub,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Publish Vault')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.isPublishing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating Taproot address...'),
                  ],
                ),
              )
            : state.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(onboardingProvider.notifier)
                              .publishVault(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : state.isFunded
                ? _fundedView(context: context)
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Send Bitcoin to this address to activate your vault',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // QR code placeholder
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2,
                                    size: 120, color: Colors.grey.shade800),
                                Text(
                                  'QR Code',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Address display
                        if (state.generatedAddress != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.generatedAddress!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: state.generatedAddress!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Address copied')),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                              const SizedBox(width: 12),
                              if (!_deviceVerified && !_verifying)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    setState(() => _verifying = true);
                                    try {
                                      await ref
                                          .read(pairedDeviceProvider.notifier)
                                          .verifyOnDevice(
                                              state.generatedAddress!);
                                      if (mounted) {
                                        setState(() {
                                          _deviceVerified = true;
                                          _verifying = false;
                                        });
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        setState(() => _verifying = false);
                                        messenger
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Device verification failed. Try again.'),
                                        ));
                                      }
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.fingerprint, size: 16),
                                  label: const Text('Verify on Device'),
                                ),
                              if (_verifying)
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Check your device...'),
                                  ],
                                ),
                              if (_deviceVerified)
                                Chip(
                                  avatar: Icon(Icons.verified,
                                      size: 16, color: primary),
                                  label: const Text('Verified'),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Template summary
                        if (state.selectedTemplate != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _SummaryRow(
                                    label: 'Template',
                                    value:
                                        state.selectedTemplate!.displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'Delay',
                                    value:
                                        state.selectedTemplate!.delayDescription,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Simulate funding button (for demo)
                        if (_deviceVerified)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(onboardingProvider.notifier)
                                    .simulateFunding();
                              },
                              child:
                                  const Text('Simulate Incoming Transaction'),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _fundedView({required BuildContext context}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Vault Funded!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your vault is now active and protected.',
            style: TextStyle(color: Colors.grey.shade400),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
