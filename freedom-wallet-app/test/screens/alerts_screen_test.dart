import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/alerts/alerts_screen.dart';

void main() {
  testWidgets('AlertsScreen shows alert list', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AlertsScreen()),
      ),
    );

    // Initially loading
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Spend Detected'), findsOneWidget);
    expect(find.text('Timelock Maturing'), findsOneWidget);
  });
}
