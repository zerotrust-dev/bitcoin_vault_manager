import 'package:freedom_wallet/data/services/device_drivers/device_driver.dart';
import 'package:freedom_wallet/data/services/trezor_bridge_service.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/models/device.dart';

/// Trezor hardware wallet driver using the Trezor Bridge HTTP API.
class TrezorDriver implements DeviceDriver {
  final TrezorBridgeClient _bridge;

  TrezorDriver({TrezorBridgeClient? bridge})
      : _bridge = bridge ?? TrezorBridgeClient();

  @override
  Future<List<DiscoveredDevice>> enumerate() async {
    await _bridge.checkBridge();
    final devices = await _bridge.enumerate();
    return devices.map((d) => DiscoveredDevice(
          path: d.path,
          label: 'Trezor',
          type: DeviceType.trezor,
          connectionMethod: ConnectionMethod.usb,
        )).toList();
  }

  @override
  Future<DeviceSession> openSession(DiscoveredDevice device) async {
    final sessionId = await _bridge.acquire(
      device.path,
      previousSession: null,
    );
    return TrezorSession(_bridge, sessionId);
  }
}

/// An active session with a Trezor device via Bridge.
class TrezorSession implements DeviceSession {
  final TrezorBridgeClient _bridge;
  final String _session;
  bool _initialized = false;

  TrezorSession(this._bridge, this._session);

  @override
  DeviceType get type => DeviceType.trezor;

  @override
  ConnectionMethod get connectionMethod => ConnectionMethod.usb;

  @override
  Future<DeviceMetadata> getMetadata() async {
    final response = await _bridge.call(_session, 'Initialize', {});
    _throwIfFailure(response);
    _initialized = true;

    final major = response['major_version'] as int? ?? 0;
    final minor = response['minor_version'] as int? ?? 0;
    final patch = response['patch_version'] as int? ?? 0;
    final version = '$major.$minor.$patch';

    // Extract master key fingerprint if available
    final fingerprint = _extractFingerprint(response);

    return DeviceMetadata(
      firmwareVersion: version,
      fingerprint: fingerprint,
      type: DeviceType.trezor,
      label: response['label'] as String? ?? 'Trezor',
      supportsTaproot: _checkTaprootSupport(major, minor),
    );
  }

  @override
  Future<String> getXpub(String derivationPath) async {
    if (!_initialized) await getMetadata();

    final addressN = _parseDerivationPath(derivationPath);
    final response = await _bridge.call(_session, 'GetPublicKey', {
      'address_n': addressN,
      'coin_name': 'Bitcoin',
      'script_type': 'SPENDTAPROOT',
      'show_display': false,
    });
    _throwIfFailure(response);

    final xpub = response['xpub'] as String?;
    if (xpub == null) {
      throw const DeviceDisconnectedException('Device did not return xpub');
    }
    return xpub;
  }

  @override
  Future<bool> displayAddress(String address, String derivationPath) async {
    if (!_initialized) await getMetadata();

    final addressN = _parseDerivationPath(derivationPath);
    final response = await _bridge.call(_session, 'GetAddress', {
      'address_n': addressN,
      'coin_name': 'Bitcoin',
      'script_type': 'SPENDTAPROOT',
      'show_display': true,
    });
    _throwIfFailure(response);

    final deviceAddress = response['address'] as String?;
    return deviceAddress == address;
  }

  @override
  Future<String> signPsbt(String psbtBase64) async {
    if (!_initialized) await getMetadata();

    final response = await _bridge.call(_session, 'SignTx', {
      'psbt': psbtBase64,
      'coin_name': 'Bitcoin',
    });
    _throwIfFailure(response);

    final signedPsbt = response['psbt'] as String?;
    if (signedPsbt == null) {
      throw const SigningFailedException('Device did not return signed PSBT');
    }
    return signedPsbt;
  }

  @override
  Future<void> close() async {
    try {
      await _bridge.release(_session);
    } catch (_) {
      // Best-effort release; device may already be disconnected
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //                      HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Parse "m/86'/0'/0'" into Trezor address_n format [0x80000056, 0x80000000, 0x80000000].
  static List<int> _parseDerivationPath(String path) {
    final segments = path
        .replaceAll('m/', '')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    return segments.map((segment) {
      final hardened = segment.endsWith("'") || segment.endsWith('h');
      final index = int.parse(segment.replaceAll(RegExp("[h']"), ''));
      return hardened ? index | 0x80000000 : index;
    }).toList();
  }

  /// Extract the master fingerprint from the Features/Initialize response.
  String _extractFingerprint(Map<String, dynamic> response) {
    // Trezor Bridge may return this as part of the Features message
    // or it may need to be derived from the root public key.
    if (response['root_fingerprint'] != null) {
      return response['root_fingerprint'] as String;
    }
    // Fallback: use device_id as a pseudo-fingerprint
    final deviceId = response['device_id'] as String?;
    if (deviceId != null && deviceId.length >= 8) {
      return deviceId.substring(0, 8).toLowerCase();
    }
    return '00000000';
  }

  /// Taproot (BIP86) signing support was added in Trezor firmware 2.4.0.
  bool _checkTaprootSupport(int major, int minor) {
    return major > 2 || (major == 2 && minor >= 4);
  }

  /// Check if the response is a Failure message and throw the appropriate error.
  void _throwIfFailure(Map<String, dynamic> response) {
    final messageType = response['type'] as String?;
    if (messageType == 'Failure') {
      final code = response['code'] as String? ?? '';
      final message = response['message'] as String? ?? 'Unknown device error';

      if (code == 'Failure_ActionCancelled' ||
          code == 'Failure_PinCancelled') {
        throw const DeviceUserDeniedException();
      }
      if (code == 'Failure_PinExpected') {
        throw const DeviceLockedError();
      }
      throw DeviceDisconnectedException(message);
    }
  }
}
