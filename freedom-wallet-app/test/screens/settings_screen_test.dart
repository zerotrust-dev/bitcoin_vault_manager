import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/settings/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen shows settings options', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Bitcoin Network'), findsOneWidget);
    expect(find.text('Display Currency'), findsOneWidget);
    expect(find.text('Biometric Lock'), findsOneWidget);
    expect(find.text('Push Notifications'), findsOneWidget);
  });
}
