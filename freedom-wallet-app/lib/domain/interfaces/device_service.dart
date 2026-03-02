import 'package:freedom_wallet/domain/models/device.dart';

abstract class DeviceService {
  Future<DeviceInfo> pairDevice(ConnectionMethod method);
  Future<bool> verifyOnDevice(String message);
  Future<String> signPsbt(String psbtBase64);
}
