import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/presentation/features/onboarding/welcome_screen.dart';
import 'package:freedom_wallet/presentation/features/onboarding/pair_device_screen.dart';
import 'package:freedom_wallet/presentation/features/onboarding/template_screen.dart';
import 'package:freedom_wallet/presentation/features/onboarding/publish_vault_screen.dart';
import 'package:freedom_wallet/presentation/features/dashboard/dashboard_screen.dart';
import 'package:freedom_wallet/presentation/features/spend/spend_wizard_screen.dart';
import 'package:freedom_wallet/presentation/features/backup/backup_center_screen.dart';
import 'package:freedom_wallet/presentation/features/backup/recovery_wizard_screen.dart';
import 'package:freedom_wallet/presentation/features/alerts/alerts_screen.dart';
import 'package:freedom_wallet/presentation/features/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/pair-device',
      builder: (context, state) => const PairDeviceScreen(),
    ),
    GoRoute(
      path: '/onboarding/template',
      builder: (context, state) => const TemplateScreen(),
    ),
    GoRoute(
      path: '/onboarding/publish',
      builder: (context, state) => const PublishVaultScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/spend/:vaultId',
      builder: (context, state) => SpendWizardScreen(
        vaultId: state.pathParameters['vaultId']!,
      ),
    ),
    GoRoute(
      path: '/backup',
      builder: (context, state) => const BackupCenterScreen(),
    ),
    GoRoute(
      path: '/recovery',
      builder: (context, state) => const RecoveryWizardScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
