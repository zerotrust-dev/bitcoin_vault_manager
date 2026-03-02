import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen shows balance header and vault list',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen()),
      ),
    );

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // After data loads
    await tester.pumpAndSettle();

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Freedom Wallet'), findsOneWidget);
    expect(find.text('Long-term Savings'), findsOneWidget);
    expect(find.text('Daily Spending'), findsOneWidget);
  });
}
