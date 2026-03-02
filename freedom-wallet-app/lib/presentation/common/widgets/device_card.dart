import 'package:flutter/material.dart';
import 'package:freedom_wallet/domain/models/device.dart';

class DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback? onVerify;
  final bool verified;

  const DeviceCard({
    super.key,
    required this.device,
    this.onVerify,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _deviceIcon(device.type),
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Firmware ${device.firmwareVersion}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (verified)
                  const Chip(
                    label: Text('Verified'),
                    avatar: Icon(Icons.verified, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Fingerprint', value: device.fingerprint),
            const SizedBox(height: 4),
            _InfoRow(label: 'Connection', value: device.connectionDisplayName),
            const SizedBox(height: 4),
            _InfoRow(
              label: 'Taproot',
              value: device.supportsTaproot ? 'Supported' : 'Not Supported',
            ),
            if (onVerify != null && !verified) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Verify on Device'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.trezor:
        return Icons.security;
      case DeviceType.ledger:
        return Icons.usb;
      case DeviceType.coldcard:
        return Icons.sd_card;
      case DeviceType.bitbox02:
        return Icons.memory;
      case DeviceType.generic:
        return Icons.devices;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
