import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/local/device_storage.dart';
import 'package:freedom_wallet/data/mock/mock_device_service.dart';
import 'package:freedom_wallet/data/services/device_drivers/trezor_driver.dart';
import 'package:freedom_wallet/data/services/hardware_device_service.dart';
import 'package:freedom_wallet/domain/interfaces/device_service.dart';
import 'package:freedom_wallet/domain/models/device.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';

enum DeviceConnectionStatus { disconnected, connecting, connected, awaitingApproval }

final deviceStorageProvider = Provider<DeviceStorage>(
  (ref) => DeviceStorage(),
);

final deviceServiceProvider = Provider<DeviceService>((ref) {
  if (useMocks) {
    return MockDeviceService();
  }
  // BIP86 path: m/86'/coin_type'/0'
  // Using testnet (coin_type=1) by default; will use settings provider later
  const derivationPath = "m/86'/1'/0'";
  return HardwareDeviceService(
    drivers: [TrezorDriver()],
    derivationPath: derivationPath,
  );
});

final deviceConnectionStatusProvider = StateProvider<DeviceConnectionStatus>(
  (ref) => DeviceConnectionStatus.disconnected,
);

final pairedDeviceProvider =
    StateNotifierProvider<PairedDeviceNotifier, AsyncValue<DeviceInfo?>>(
  (ref) => PairedDeviceNotifier(
    ref.watch(deviceServiceProvider),
    ref.watch(deviceStorageProvider),
    ref.read(deviceConnectionStatusProvider.notifier),
  ),
);

class PairedDeviceNotifier extends StateNotifier<AsyncValue<DeviceInfo?>> {
  final DeviceService _service;
  final DeviceStorage _storage;
  final StateController<DeviceConnectionStatus> _connectionStatus;

  PairedDeviceNotifier(this._service, this._storage, this._connectionStatus)
      : super(const AsyncValue.data(null));

  /// Load previously paired device from storage.
  Future<void> loadSavedDevice() async {
    final saved = await _storage.loadPairedDevice();
    if (saved != null) {
      state = AsyncValue.data(saved);
    }
  }

  Future<void> pairDevice(ConnectionMethod method) async {
    state = const AsyncValue.loading();
    _connectionStatus.state = DeviceConnectionStatus.connecting;
    try {
      final device = await _service.pairDevice(method);
      await _storage.savePairedDevice(device);
      state = AsyncValue.data(device);
      _connectionStatus.state = DeviceConnectionStatus.connected;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      _connectionStatus.state = DeviceConnectionStatus.disconnected;
    }
  }

  Future<bool> verifyOnDevice(String message) async {
    _connectionStatus.state = DeviceConnectionStatus.awaitingApproval;
    try {
      final result = await _service.verifyOnDevice(message);
      _connectionStatus.state = DeviceConnectionStatus.connected;
      return result;
    } catch (e) {
      _connectionStatus.state = DeviceConnectionStatus.disconnected;
      rethrow;
    }
  }

  Future<String> signPsbt(String psbtBase64) async {
    _connectionStatus.state = DeviceConnectionStatus.awaitingApproval;
    try {
      final result = await _service.signPsbt(psbtBase64);
      _connectionStatus.state = DeviceConnectionStatus.connected;
      return result;
    } catch (e) {
      _connectionStatus.state = DeviceConnectionStatus.disconnected;
      rethrow;
    }
  }

  void reset() {
    _storage.clearPairedDevice();
    _connectionStatus.state = DeviceConnectionStatus.disconnected;
    state = const AsyncValue.data(null);
  }
}
