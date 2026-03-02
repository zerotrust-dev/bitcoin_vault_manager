import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/presentation/features/backup/backup_center_screen.dart';

void main() {
  testWidgets('BackupCenterScreen shows backup info', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BackupCenterScreen()),
      ),
    );

    expect(
      find.text('The blockchain IS the backup.'),
      findsOneWidget,
    );
    expect(find.text('What needs backup'), findsOneWidget);
    expect(find.text('What does NOT need backup'), findsOneWidget);
    expect(find.text('Test Recovery'), findsOneWidget);
  });
}
