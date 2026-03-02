import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/onboarding/template_screen.dart';

void main() {
  testWidgets('TemplateScreen shows three template options', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TemplateScreen()),
      ),
    );

    expect(find.text('How do you want to protect your Bitcoin?'), findsOneWidget);
    expect(find.text('Savings Vault'), findsOneWidget);
    expect(find.text('Spending Vault'), findsOneWidget);
    expect(find.text('Custom Vault'), findsOneWidget);
  });
}
