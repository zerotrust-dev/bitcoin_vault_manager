import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/providers/onboarding_provider.dart';

class TemplateScreen extends ConsumerWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Template')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How do you want to protect your Bitcoin?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a security template for your vault',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 24),
                  _TemplateCard(
                    title: 'Savings Vault',
                    subtitle: 'Maximum protection',
                    description:
                        'Any spend requires a 1-week delay before completing. '
                        'This gives you time to cancel unauthorized transactions.',
                    delay: '~1 week (1008 blocks)',
                    icon: Icons.savings,
                    selected: state.selectedTemplate?.type == 'savings',
                    onTap: () => ref
                        .read(onboardingProvider.notifier)
                        .selectTemplate(VaultTemplate.savings),
                  ),
                  const SizedBox(height: 12),
                  _TemplateCard(
                    title: 'Spending Vault',
                    subtitle: 'Balanced security',
                    description:
                        'Spends complete after a 1-day delay. '
                        'Good for funds you access more frequently.',
                    delay: '~1 day (144 blocks)',
                    icon: Icons.payment,
                    selected: state.selectedTemplate?.type == 'spending',
                    onTap: () => ref
                        .read(onboardingProvider.notifier)
                        .selectTemplate(VaultTemplate.spending),
                  ),
                  const SizedBox(height: 12),
                  _TemplateCard(
                    title: 'Custom Vault',
                    subtitle: 'Advanced',
                    description:
                        'Set your own delay period and recovery options.',
                    delay: 'Variable',
                    icon: Icons.tune,
                    selected: state.selectedTemplate?.type == 'custom',
                    onTap: () => ref
                        .read(onboardingProvider.notifier)
                        .selectTemplate(VaultTemplate.custom(
                          delayBlocks: 504,
                          recoveryType: RecoveryType.emergencyKey,
                        )),
                  ),
                ],
              ),
            ),
          ),
          if (state.selectedTemplate != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/publish'),
                  child: const Text('Continue'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String delay;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.delay,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: selected ? primary : Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: selected ? primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Delay: $delay',
                      style: TextStyle(
                        fontSize: 12,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
