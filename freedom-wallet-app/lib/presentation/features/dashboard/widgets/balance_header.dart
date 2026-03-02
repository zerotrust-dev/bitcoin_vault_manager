import 'package:flutter/material.dart';
import 'package:freedom_wallet/presentation/common/widgets/btc_amount.dart';

class BalanceHeader extends StatelessWidget {
  final int totalSats;

  const BalanceHeader({super.key, required this.totalSats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          BtcAmount(sats: totalSats, fontSize: 28),
        ],
      ),
    );
  }
}
