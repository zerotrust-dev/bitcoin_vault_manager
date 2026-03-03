import 'package:flutter_test/flutter_test.dart';
import 'package:freedom_wallet/data/services/device_drivers/device_driver.dart';
import 'package:freedom_wallet/data/services/hardware_device_service.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/models/device.dart';

/// A fake driver for testing HardwareDeviceService without real hardware.
class FakeDeviceDriver implements DeviceDriver {
  final List<DiscoveredDevice> _devices;
  final FakeDeviceSession Function(DiscoveredDevice)? _sessionFactory;

  FakeDeviceDriver({
    List<DiscoveredDevice>? devices,
    FakeDeviceSession Function(DiscoveredDevice)? sessionFactory,
  })  : _devices = devices ?? [],
        _sessionFactory = sessionFactory;

  @override
  Future<List<DiscoveredDevice>> enumerate() async => _devices;

  @override
  Future<DeviceSession> openSession(DiscoveredDevice device) async {
    if (_sessionFactory != null) return _sessionFactory(device);
    return FakeDeviceSession();
  }
}

class FakeDeviceSession implements DeviceSession {
  bool closed = false;
  final DeviceMetadata _metadata;
  final String _xpub;
  final String? _signedPsbt;
  final bool _displayMatch;

  FakeDeviceSession({
    DeviceMetadata? metadata,
    String? xpub,
    String? signedPsbt,
    bool displayMatch = true,
  })  : _metadata = metadata ??
            const DeviceMetadata(
              firmwareVersion: '2.6.3',
              fingerprint: 'a1b2c3d4',
              type: DeviceType.trezor,
              label: 'Test Trezor',
              supportsTaproot: true,
            ),
        _xpub = xpub ?? 'xpub6TestXpubValue',
        _signedPsbt = signedPsbt,
        _displayMatch = displayMatch;

  @override
  DeviceType get type => DeviceType.trezor;

  @override
  ConnectionMethod get connectionMethod => ConnectionMethod.usb;

  @override
  Future<DeviceMetadata> getMetadata() async => _metadata;

  @override
  Future<String> getXpub(String derivationPath) async => _xpub;

  @override
  Future<bool> displayAddress(String address, String derivationPath) async =>
      _displayMatch;

  @override
  Future<String> signPsbt(String psbtBase64) async =>
      _signedPsbt ?? 'signed_$psbtBase64';

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  group('HardwareDeviceService', () {
    test('pairDevice succeeds with a connected device', () async {
      final fakeSession = FakeDeviceSession();
      final driver = FakeDeviceDriver(
        devices: [
          const DiscoveredDevice(
            path: 'test-path',
            label: 'Trezor',
            type: DeviceType.trezor,
            connectionMethod: ConnectionMethod.usb,
          ),
        ],
        sessionFactory: (_) => fakeSession,
      );

      final service = HardwareDeviceService(
        drivers: [driver],
        derivationPath: "m/86'/1'/0'",
      );

      final device = await service.pairDevice(ConnectionMethod.usb);
      expect(device.name, 'Test Trezor');
      expect(device.fingerprint, 'a1b2c3d4');
      expect(device.xpub, 'xpub6TestXpubValue');
      expect(device.type, DeviceType.trezor);
      expect(device.supportsTaproot, true);
      expect(device.connectionMethod, ConnectionMethod.usb);
    });

    test('pairDevice throws DeviceNotFoundException when no devices', () async {
      final driver = FakeDeviceDriver(devices: []);

      final service = HardwareDeviceService(
        drivers: [driver],
        derivationPath: "m/86'/1'/0'",
      );

      expect(
        () => service.pairDevice(ConnectionMethod.usb),
        throwsA(isA<DeviceNotFoundException>()),
      );
    });

    test('pairDevice throws when device lacks Taproot support', () async {
      final driver = FakeDeviceDriver(
        devices: [
          const DiscoveredDevice(
            path: 'old-device',
            label: 'Old Trezor',
            type: DeviceType.trezor,
            connectionMethod: ConnectionMethod.usb,
          ),
        ],
        sessionFactory: (_) => FakeDeviceSession(
          metadata: const DeviceMetadata(
            firmwareVersion: '2.3.0',
            fingerprint: 'old12345',
            type: DeviceType.trezor,
            label: 'Old Trezor',
            supportsTaproot: false,
          ),
        ),
      );

      final service = HardwareDeviceService(
        drivers: [driver],
        derivationPath: "m/86'/1'/0'",
      );

      expect(
        () => service.pairDevice(ConnectionMethod.usb),
        throwsA(isA<DeviceTaprootUnsupportedException>()),
      );
    });

    test('signPsbt works after pairing', () async {
      final driver = FakeDeviceDriver(
        devices: [
          const DiscoveredDevice(
            path: 'dev',
            label: 'Trezor',
            type: DeviceType.trezor,
            connectionMethod: ConnectionMethod.usb,
          ),
        ],
        sessionFactory: (_) => FakeDeviceSession(signedPsbt: 'signed_result'),
      );

      final service = HardwareDeviceService(
        drivers: [driver],
        derivationPath: "m/86'/1'/0'",
      );

      await service.pairDevice(ConnectionMethod.usb);
      final result = await service.signPsbt('unsigned_psbt');
      expect(result, 'signed_result');
    });

    test('signPsbt throws when not paired', () async {
      final service = HardwareDeviceService(
        drivers: [],
        derivationPath: "m/86'/1'/0'",
      );

      expect(
        () => service.signPsbt('any_psbt'),
        throwsA(isA<DeviceNotFoundException>()),
      );
    });

    test('verifyOnDevice works after pairing', () async {
      final driver = FakeDeviceDriver(
        devices: [
          const DiscoveredDevice(
            path: 'dev',
            label: 'Trezor',
            type: DeviceType.trezor,
            connectionMethod: ConnectionMethod.usb,
          ),
        ],
        sessionFactory: (_) => FakeDeviceSession(displayMatch: true),
      );

      final service = HardwareDeviceService(
        drivers: [driver],
        derivationPath: "m/86'/1'/0'",
      );

      await service.pairDevice(ConnectionMethod.usb);
      final verified = await service.verifyOnDevice('bc1ptestaddress');
      expect(verified, true);
    });

    test('tries multiple drivers until one has devices', () async {
      final emptyDriver = FakeDeviceDriver(devices: []);
      final driverWithDevice = FakeDeviceDriver(
        devices: [
          const DiscoveredDevice(
            path: 'found',
            label: 'Trezor',
            type: DeviceType.trezor,
            connectionMethod: ConnectionMethod.usb,
          ),
        ],
      );

      final service = HardwareDeviceService(
        drivers: [emptyDriver, driverWithDevice],
        derivationPath: "m/86'/1'/0'",
      );

      final device = await service.pairDevice(ConnectionMethod.usb);
      expect(device.name, 'Test Trezor');
    });
  });
}
