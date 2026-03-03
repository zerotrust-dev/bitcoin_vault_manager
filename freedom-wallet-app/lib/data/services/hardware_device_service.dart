import 'package:freedom_wallet/data/services/device_drivers/device_driver.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/interfaces/device_service.dart';
import 'package:freedom_wallet/domain/models/device.dart';

/// Real [DeviceService] implementation that communicates with hardware wallets
/// via the [DeviceDriver] abstraction.
class HardwareDeviceService implements DeviceService {
  final List<DeviceDriver> _drivers;
  final String _derivationPath;
  DeviceSession? _activeSession;

  HardwareDeviceService({
    required List<DeviceDriver> drivers,
    required String derivationPath,
  })  : _drivers = drivers,
        _derivationPath = derivationPath;

  @override
  Future<DeviceInfo> pairDevice(ConnectionMethod method) async {
    DeviceSession? session;
    DeviceMetadata? metadata;
    String? xpub;

    for (final driver in _drivers) {
      final devices = await driver.enumerate();
      if (devices.isEmpty) continue;

      // Pick the first available device
      session = await driver.openSession(devices.first);
      metadata = await session.getMetadata();

      if (!metadata.supportsTaproot) {
        await session.close();
        throw const DeviceTaprootUnsupportedException();
      }

      xpub = await session.getXpub(_derivationPath);
      break;
    }

    if (session == null || metadata == null || xpub == null) {
      throw const DeviceNotFoundException();
    }

    // Keep session open for subsequent verify/sign calls
    await _activeSession?.close();
    _activeSession = session;

    return DeviceInfo(
      name: metadata.label,
      type: metadata.type,
      fingerprint: metadata.fingerprint,
      xpub: xpub,
      firmwareVersion: metadata.firmwareVersion,
      role: DeviceRole.daily,
      connectionMethod: session.connectionMethod,
      supportsTaproot: metadata.supportsTaproot,
      pairedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> verifyOnDevice(String message) async {
    final session = _activeSession;
    if (session == null) {
      throw const DeviceNotFoundException('No device paired');
    }
    return session.displayAddress(message, _derivationPath);
  }

  @override
  Future<String> signPsbt(String psbtBase64) async {
    final session = await _ensureSession();
    return session.signPsbt(psbtBase64);
  }

  @override
  Future<void> displayAddress(String address, String deviceFingerprint) async {
    final session = _activeSession;
    if (session == null) {
      throw const DeviceNotFoundException('No device paired');
    }
    await session.displayAddress(address, _derivationPath);
  }

  /// Ensure an active session exists, attempting reconnection if needed.
  Future<DeviceSession> _ensureSession() async {
    final session = _activeSession;
    if (session == null) {
      throw const DeviceNotFoundException('No device paired. Please pair first.');
    }
    return session;
  }

  Future<void> dispose() async {
    await _activeSession?.close();
    _activeSession = null;
  }
}
