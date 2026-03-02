import 'package:flutter/material.dart';

class BtcAmount extends StatelessWidget {
  final int sats;
  final double fontSize;
  final Color? color;
  final bool showUnit;

  const BtcAmount({
    super.key,
    required this.sats,
    this.fontSize = 16,
    this.color,
    this.showUnit = true,
  });

  @override
  Widget build(BuildContext context) {
    final btc = sats / 100000000;
    final text = showUnit ? '${btc.toStringAsFixed(8)} BTC' : btc.toStringAsFixed(8);
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontFamily: 'monospace',
      ),
    );
  }
}
