import 'package:flutter/material.dart';
import 'package:freedom_wallet/app/router.dart';
import 'package:freedom_wallet/app/theme.dart';

class FreedomWalletApp extends StatelessWidget {
  const FreedomWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Freedom Wallet',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
