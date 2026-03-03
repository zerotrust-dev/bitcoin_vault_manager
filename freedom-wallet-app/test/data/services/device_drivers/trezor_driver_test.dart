import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freedom_wallet/data/services/device_drivers/trezor_driver.dart';
import 'package:freedom_wallet/data/services/trezor_bridge_service.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/models/device.dart';

void main() {
  group('TrezorDriver', () {
    late MockClient mockHttpClient;
    late TrezorBridgeClient bridgeClient;
    late TrezorDriver driver;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/') {
          return http.Response('{"version": "2.0.27"}', 200);
        }
        if (path == '/enumerate') {
          return http.Response(
            jsonEncode([
              {'path': 'device1', 'session': null, 'vendor': 0x534c, 'product': 1},
            ]),
            200,
          );
        }
        if (path.startsWith('/acquire/')) {
          return http.Response('{"session": "sess1"}', 200);
        }
        if (path.startsWith('/release/')) {
          return http.Response('{}', 200);
        }
        if (path.startsWith('/call/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final type = body['type'] as String;

          if (type == 'Initialize') {
            return http.Response(
              jsonEncode({
                'type': 'Features',
                'major_version': 2,
                'minor_version': 6,
                'patch_version': 3,
                'device_id': 'a1b2c3d4e5f6',
                'label': 'Test Trezor',
              }),
              200,
            );
          }
          if (type == 'GetPublicKey') {
            return http.Response(
              jsonEncode({
                'type': 'PublicKey',
                'xpub': 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtyPWKiKbERr4d5qkSmQGgRFmDBRK2HAFD99bazG3M9spqkzmraLke4YGpMtBX3X1m4SwcoAm8kDBvvhCJLk3',
              }),
              200,
            );
          }
          if (type == 'GetAddress') {
            return http.Response(
              jsonEncode({
                'type': 'Address',
                'address': 'bc1ptestaddress',
              }),
              200,
            );
          }
          if (type == 'SignTx') {
            return http.Response(
              jsonEncode({
                'type': 'SignedPsbt',
                'psbt': 'signed_psbt_base64_data',
              }),
              200,
            );
          }
        }
        return http.Response('', 404);
      });

      bridgeClient = TrezorBridgeClient(client: mockHttpClient);
      driver = TrezorDriver(bridge: bridgeClient);
    });

    test('enumerate discovers Trezor devices', () async {
      final devices = await driver.enumerate();
      expect(devices, hasLength(1));
      expect(devices.first.type, DeviceType.trezor);
      expect(devices.first.connectionMethod, ConnectionMethod.usb);
      expect(devices.first.path, 'device1');
    });

    test('openSession and getMetadata returns correct device info', () async {
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);

      final metadata = await session.getMetadata();
      expect(metadata.firmwareVersion, '2.6.3');
      expect(metadata.type, DeviceType.trezor);
      expect(metadata.label, 'Test Trezor');
      expect(metadata.supportsTaproot, true);

      await session.close();
    });

    test('getXpub returns xpub from device', () async {
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);
      await session.getMetadata(); // Initialize first

      final xpub = await session.getXpub("m/86'/0'/0'");
      expect(xpub, startsWith('xpub'));

      await session.close();
    });

    test('displayAddress returns match result', () async {
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);
      await session.getMetadata();

      final matches =
          await session.displayAddress('bc1ptestaddress', "m/86'/0'/0'");
      expect(matches, true);

      final noMatch =
          await session.displayAddress('bc1pwrongaddress', "m/86'/0'/0'");
      expect(noMatch, false);

      await session.close();
    });

    test('signPsbt returns signed PSBT', () async {
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);
      await session.getMetadata();

      final signed = await session.signPsbt('unsigned_psbt_base64');
      expect(signed, 'signed_psbt_base64_data');

      await session.close();
    });
  });

  group('TrezorSession failure handling', () {
    test('throws DeviceUserDeniedException on ActionCancelled', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/') return http.Response('{"version": "2.0.27"}', 200);
        if (path == '/enumerate') {
          return http.Response(
            jsonEncode([
              {'path': 'dev1', 'session': null, 'vendor': 0x534c, 'product': 1},
            ]),
            200,
          );
        }
        if (path.startsWith('/acquire/')) {
          return http.Response('{"session": "s1"}', 200);
        }
        if (path.startsWith('/call/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['type'] == 'Initialize') {
            return http.Response(
              jsonEncode({
                'type': 'Features',
                'major_version': 2,
                'minor_version': 6,
                'patch_version': 0,
                'device_id': 'test1234',
                'label': 'Trezor',
              }),
              200,
            );
          }
          // Return Failure for sign
          return http.Response(
            jsonEncode({
              'type': 'Failure',
              'code': 'Failure_ActionCancelled',
              'message': 'User cancelled',
            }),
            200,
          );
        }
        if (path.startsWith('/release/')) {
          return http.Response('{}', 200);
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final driver = TrezorDriver(bridge: bridge);
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);
      await session.getMetadata();

      expect(
        () => session.signPsbt('test_psbt'),
        throwsA(isA<DeviceUserDeniedException>()),
      );

      await session.close();
    });

    test('throws DeviceLockedError on PinExpected', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/') return http.Response('{"version": "2.0.27"}', 200);
        if (path == '/enumerate') {
          return http.Response(
            jsonEncode([
              {'path': 'dev1', 'session': null, 'vendor': 0x534c, 'product': 1},
            ]),
            200,
          );
        }
        if (path.startsWith('/acquire/')) {
          return http.Response('{"session": "s1"}', 200);
        }
        if (path.startsWith('/call/')) {
          return http.Response(
            jsonEncode({
              'type': 'Failure',
              'code': 'Failure_PinExpected',
              'message': 'PIN expected',
            }),
            200,
          );
        }
        if (path.startsWith('/release/')) {
          return http.Response('{}', 200);
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final driver = TrezorDriver(bridge: bridge);
      final devices = await driver.enumerate();
      final session = await driver.openSession(devices.first);

      expect(
        () => session.getMetadata(),
        throwsA(isA<DeviceLockedError>()),
      );

      await session.close();
    });
  });
}
