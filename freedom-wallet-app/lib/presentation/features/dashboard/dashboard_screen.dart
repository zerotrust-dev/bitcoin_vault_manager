import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';
import 'package:freedom_wallet/presentation/providers/alert_provider.dart';
import 'package:freedom_wallet/presentation/common/widgets/vault_card.dart';
import 'package:freedom_wallet/presentation/features/dashboard/widgets/balance_header.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultsAsync = ref.watch(vaultsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final alertCount = ref.watch(unacknowledgedCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freedom Wallet'),
        actions: [
          if (alertCount > 0)
            Badge(
              label: Text('$alertCount'),
              child: IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => context.go('/alerts'),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () => context.go('/alerts'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          BalanceHeader(totalSats: totalBalance),
          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Would navigate to receive flow
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receive flow coming soon')),
                      );
                    },
                    icon: const Icon(Icons.call_received, size: 18),
                    label: const Text('Receive'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/backup'),
                    icon: const Icon(Icons.shield, size: 18),
                    label: const Text('Backup'),
                  ),
                ),
              ],
            ),
          ),
          // Vault list
          Expanded(
            child: vaultsAsync.when(
              data: (vaults) {
                if (vaults.isEmpty) {
                  return const Center(
                    child: Text(
                      'No vaults yet. Create your first vault!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: vaults.length,
                  itemBuilder: (context, index) {
                    final vault = vaults[index];
                    return VaultCard(
                      vault: vault,
                      onTap: () => context.go('/spend/${vault.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/onboarding/pair-device'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
