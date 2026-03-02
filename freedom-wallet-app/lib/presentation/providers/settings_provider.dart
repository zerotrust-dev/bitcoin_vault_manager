import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class AppSettings {
  final Network network;
  final String displayCurrency;
  final bool biometricEnabled;
  final bool pushNotificationsEnabled;

  const AppSettings({
    this.network = Network.testnet,
    this.displayCurrency = 'BTC',
    this.biometricEnabled = false,
    this.pushNotificationsEnabled = true,
  });

  AppSettings copyWith({
    Network? network,
    String? displayCurrency,
    bool? biometricEnabled,
    bool? pushNotificationsEnabled,
  }) {
    return AppSettings(
      network: network ?? this.network,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setNetwork(Network network) {
    state = state.copyWith(network: network);
  }

  void setDisplayCurrency(String currency) {
    state = state.copyWith(displayCurrency: currency);
  }

  void toggleBiometric() {
    state = state.copyWith(biometricEnabled: !state.biometricEnabled);
  }

  void togglePushNotifications() {
    state = state.copyWith(
      pushNotificationsEnabled: !state.pushNotificationsEnabled,
    );
  }
}
