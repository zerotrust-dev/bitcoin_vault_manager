import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/mock/mock_device_service.dart';
import 'package:freedom_wallet/domain/models/device.dart';

final deviceServiceProvider = Provider((ref) => MockDeviceService());

final pairedDeviceProvider =
    StateNotifierProvider<PairedDeviceNotifier, AsyncValue<DeviceInfo?>>(
  (ref) => PairedDeviceNotifier(ref.watch(deviceServiceProvider)),
);

class PairedDeviceNotifier extends StateNotifier<AsyncValue<DeviceInfo?>> {
  final MockDeviceService _service;

  PairedDeviceNotifier(this._service)
      : super(const AsyncValue.data(null));

  Future<void> pairDevice(ConnectionMethod method) async {
    state = const AsyncValue.loading();
    try {
      final device = await _service.pairDevice(method);
      state = AsyncValue.data(device);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> verifyOnDevice(String message) async {
    return _service.verifyOnDevice(message);
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
