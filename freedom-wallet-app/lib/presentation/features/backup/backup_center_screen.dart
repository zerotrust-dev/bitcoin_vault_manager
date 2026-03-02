import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackupCenterScreen extends StatelessWidget {
  const BackupCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup Center')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero message
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.shield,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The blockchain IS the backup.',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your vault configuration is stored on-chain. '
                            'Only your seed phrase needs traditional backup.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // What needs backup
            const Text(
              'What needs backup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _ChecklistItem(
              title: 'Seed phrase written down',
              subtitle: 'Your 12 or 24 word recovery phrase',
              icon: Icons.edit_note,
              checked: true,
            ),
            _ChecklistItem(
              title: 'Stored in secure location',
              subtitle: 'Fireproof safe, safety deposit box, etc.',
              icon: Icons.lock,
              checked: false,
            ),
            _ChecklistItem(
              title: 'Tested recovery once',
              subtitle: 'Verify you can restore from seed',
              icon: Icons.verified_user,
              checked: false,
            ),
            const SizedBox(height: 24),
            // What does NOT need backup
            const Text(
              'What does NOT need backup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _InfoItem(
              title: 'Vault configuration',
              subtitle: 'Encoded in Taproot script on the blockchain',
              icon: Icons.link,
            ),
            _InfoItem(
              title: 'Transaction history',
              subtitle: 'Permanently recorded on-chain',
              icon: Icons.history,
            ),
            _InfoItem(
              title: 'Timelock parameters',
              subtitle: 'Part of the vault metadata in script tree',
              icon: Icons.timer,
            ),
            const SizedBox(height: 32),
            // Test recovery button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/recovery'),
                icon: const Icon(Icons.restore),
                label: const Text('Test Recovery'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool checked;

  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: checked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.cloud_done, color: Colors.green, size: 20),
      ),
    );
  }
}
