import 'package:freedom_wallet/data/mock/mock_data.dart';
import 'package:freedom_wallet/domain/models/device.dart';

class MockDeviceService {
  Future<DeviceInfo> pairDevice(ConnectionMethod method) async {
    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));
    return MockData.trezorDevice;
  }

  Future<bool> verifyOnDevice(String message) async {
    // Simulate user verification on hardware wallet
    await Future.delayed(const Duration(seconds: 3));
    return true;
  }

  Future<String> signPsbt(String psbtBase64) async {
    // Simulate signing on device
    await Future.delayed(const Duration(seconds: 3));
    return psbtBase64; // Return "signed" PSBT
  }
}
