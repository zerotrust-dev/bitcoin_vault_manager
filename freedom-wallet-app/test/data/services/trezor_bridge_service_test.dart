import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freedom_wallet/data/services/trezor_bridge_service.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';

void main() {
  group('TrezorBridgeClient', () {
    test('checkBridge succeeds when bridge is running', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/') {
          return http.Response('{"version": "2.0.27"}', 200);
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      await bridge.checkBridge();
    });

    test('checkBridge throws when bridge is not running', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      expect(
        () => bridge.checkBridge(),
        throwsA(isA<TrezorBridgeUnavailableException>()),
      );
    });

    test('enumerate returns list of devices', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/enumerate') {
          return http.Response(
            jsonEncode([
              {'path': '1', 'session': null, 'vendor': 0x534c, 'product': 1},
            ]),
            200,
          );
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final devices = await bridge.enumerate();
      expect(devices, hasLength(1));
      expect(devices.first.path, '1');
      expect(devices.first.isInUse, false);
    });

    test('enumerate returns empty list when no devices', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/enumerate') {
          return http.Response('[]', 200);
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final devices = await bridge.enumerate();
      expect(devices, isEmpty);
    });

    test('acquire returns session ID', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/acquire/1/null') {
          return http.Response('{"session": "abc123"}', 200);
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final session = await bridge.acquire('1');
      expect(session, 'abc123');
    });

    test('call sends message and returns response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/call/abc123') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['type'], 'Initialize');
          return http.Response(
            jsonEncode({
              'type': 'Features',
              'major_version': 2,
              'minor_version': 6,
              'patch_version': 3,
              'label': 'My Trezor',
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      final bridge = TrezorBridgeClient(client: mockClient);
      final response = await bridge.call('abc123', 'Initialize', {});
      expect(response['type'], 'Features');
      expect(response['major_version'], 2);
      expect(response['label'], 'My Trezor');
    });
  });
}
