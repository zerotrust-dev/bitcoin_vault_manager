import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/onboarding/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen shows title and buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeScreen()),
      ),
    );

    expect(find.text('Freedom Wallet'), findsOneWidget);
    expect(
      find.text('Your Bitcoin savings, protected by time'),
      findsOneWidget,
    );
    expect(find.text('Set up my vault'), findsOneWidget);
    expect(find.text('I already have a vault'), findsOneWidget);
    expect(find.text('v0.1.0 · Testnet'), findsOneWidget);
  });
}
