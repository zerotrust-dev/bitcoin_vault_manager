import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/app/app.dart';

void main() {
  testWidgets('App renders Freedom Wallet title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FreedomWalletApp(),
      ),
    );

    expect(find.text('Freedom Wallet'), findsNWidgets(2)); // AppBar + body
    expect(find.text('The blockchain IS the backup.'), findsOneWidget);
  });
}
