import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Network'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Bitcoin Network'),
            subtitle: Text(settings.network.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNetworkPicker(context, ref, settings.network),
          ),
          const Divider(),
          const _SectionHeader(title: 'Display'),
          ListTile(
            leading: const Icon(Icons.currency_bitcoin),
            title: const Text('Display Currency'),
            subtitle: Text(settings.displayCurrency),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BTC', label: Text('BTC')),
                ButtonSegment(value: 'sats', label: Text('sats')),
              ],
              selected: {settings.displayCurrency},
              onSelectionChanged: (v) =>
                  ref.read(settingsProvider.notifier).setDisplayCurrency(v.first),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Security'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Lock'),
            subtitle: const Text('Require fingerprint to open app'),
            value: settings.biometricEnabled,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleBiometric(),
          ),
          const Divider(),
          const _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Push Notifications'),
            subtitle: const Text('Get alerts about vault activity'),
            value: settings.pushNotificationsEnabled,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).togglePushNotifications(),
          ),
          const Divider(),
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('0.1.0 (Phase 1 - Mock Data)'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Freedom Wallet'),
            subtitle: Text('The blockchain IS the backup.'),
          ),
        ],
      ),
    );
  }

  void _showNetworkPicker(
      BuildContext context, WidgetRef ref, Network current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Network'),
        children: Network.values.map((network) {
          return ListTile(
            leading: network == current
                ? const Icon(Icons.radio_button_checked)
                : const Icon(Icons.radio_button_unchecked),
            title: Text(network.name),
            onTap: () {
              ref.read(settingsProvider.notifier).setNetwork(network);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
