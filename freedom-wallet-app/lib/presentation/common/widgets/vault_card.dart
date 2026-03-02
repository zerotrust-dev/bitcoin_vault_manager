import 'package:flutter/material.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';

class VaultCard extends StatelessWidget {
  final Vault vault;
  final VoidCallback? onTap;

  const VaultCard({super.key, required this.vault, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vault.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(status: vault.status),
                ],
              ),
              const SizedBox(height: 8),
              BtcAmount(sats: vault.balanceSats, fontSize: 20),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _templateIcon(vault.template.type),
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${vault.template.displayName} · ${vault.template.delayDescription} delay',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _templateIcon(String type) {
    switch (type) {
      case 'savings':
        return Icons.savings;
      case 'spending':
        return Icons.payment;
      default:
        return Icons.tune;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final VaultStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      VaultStatus.active => ('Active', Colors.green),
      VaultStatus.awaitingFunding => ('Awaiting Funding', Colors.orange),
      VaultStatus.pendingSpend => ('Pending Spend', Colors.blue),
      VaultStatus.empty => ('Empty', Colors.grey),
      VaultStatus.error => ('Error', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
