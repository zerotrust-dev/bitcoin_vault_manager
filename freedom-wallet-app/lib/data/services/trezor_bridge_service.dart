import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:freedom_wallet/domain/errors/device_errors.dart';

const _bridgeUrl = 'http://127.0.0.1:21325';

/// Low-level HTTP client for the Trezor Bridge REST API.
///
/// Trezor Bridge runs on localhost:21325 and provides a JSON-based API
/// for communicating with Trezor hardware wallets.
class TrezorBridgeClient {
  final http.Client _http;

  TrezorBridgeClient({http.Client? client}) : _http = client ?? http.Client();

  /// Check that Trezor Bridge is running.
  Future<void> checkBridge() async {
    try {
      final response = await _http
          .post(Uri.parse('$_bridgeUrl/'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw const TrezorBridgeUnavailableException();
      }
    } catch (e) {
      if (e is TrezorBridgeUnavailableException) rethrow;
      throw const TrezorBridgeUnavailableException();
    }
  }

  /// List connected Trezor devices.
  Future<List<TrezorBridgeDevice>> enumerate() async {
    try {
      final response = await _http
          .post(Uri.parse('$_bridgeUrl/enumerate'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw const DeviceNotFoundException('Bridge enumerate failed');
      }
      final list = jsonDecode(response.body) as List;
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return TrezorBridgeDevice(
          path: map['path'] as String,
          session: map['session'] as String?,
          vendor: map['vendor'] as int? ?? 0,
          product: map['product'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      if (e is DeviceException) rethrow;
      throw const TrezorBridgeUnavailableException();
    }
  }

  /// Acquire a session for a device path. Returns a session ID string.
  Future<String> acquire(String path, {String? previousSession}) async {
    final prev = previousSession ?? 'null';
    final response = await _http
        .post(Uri.parse('$_bridgeUrl/acquire/$path/$prev'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const DeviceNotFoundException('Failed to acquire device session');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['session'] as String;
  }

  /// Release a session.
  Future<void> release(String session) async {
    await _http
        .post(Uri.parse('$_bridgeUrl/release/$session'), headers: _headers)
        .timeout(const Duration(seconds: 5));
  }

  /// Send a protobuf-encoded message to the device via Bridge.
  ///
  /// [session] is the acquired session ID.
  /// [type] is the Trezor message type name (e.g. "Initialize", "GetPublicKey").
  /// [body] is the JSON-encoded message payload.
  ///
  /// Returns the decoded response message as a map with a "type" key indicating
  /// the response message type.
  Future<Map<String, dynamic>> call(
    String session,
    String type,
    Map<String, dynamic> body,
  ) async {
    final payload = jsonEncode({'type': type, ...body});
    try {
      final response = await _http
          .post(
            Uri.parse('$_bridgeUrl/call/$session'),
            headers: _headers,
            body: payload,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw DeviceDisconnectedException(
            'Bridge call failed: ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (e is DeviceException) rethrow;
      throw DeviceDisconnectedException('Bridge communication error: $e');
    }
  }

  void dispose() {
    _http.close();
  }

  static const _headers = {
    'Content-Type': 'application/json',
    'Origin': 'https://freedom-wallet.local',
  };
}

/// A Trezor device as reported by Bridge enumeration.
class TrezorBridgeDevice {
  final String path;
  final String? session;
  final int vendor;
  final int product;

  const TrezorBridgeDevice({
    required this.path,
    this.session,
    required this.vendor,
    required this.product,
  });

  bool get isInUse => session != null;
}
