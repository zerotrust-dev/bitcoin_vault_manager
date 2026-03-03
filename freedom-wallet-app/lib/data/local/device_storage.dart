import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freedom_wallet/domain/models/device.dart';

const _deviceKey = 'paired_device_info';

/// Persists paired device information in encrypted local storage.
class DeviceStorage {
  final FlutterSecureStorage _storage;

  DeviceStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<DeviceInfo?> loadPairedDevice() async {
    final json = await _storage.read(key: _deviceKey);
    if (json == null) return null;
    return _fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> savePairedDevice(DeviceInfo device) async {
    final json = jsonEncode(_toJson(device));
    await _storage.write(key: _deviceKey, value: json);
  }

  Future<void> clearPairedDevice() async {
    await _storage.delete(key: _deviceKey);
  }

  static Map<String, dynamic> _toJson(DeviceInfo d) => {
        'name': d.name,
        'type': d.type.index,
        'fingerprint': d.fingerprint,
        'xpub': d.xpub,
        'firmware_version': d.firmwareVersion,
        'role': d.role.index,
        'connection_method': d.connectionMethod.index,
        'supports_taproot': d.supportsTaproot,
        'paired_at': d.pairedAt.toIso8601String(),
      };

  static DeviceInfo _fromJson(Map<String, dynamic> j) => DeviceInfo(
        name: j['name'] as String,
        type: DeviceType.values[j['type'] as int],
        fingerprint: j['fingerprint'] as String,
        xpub: j['xpub'] as String,
        firmwareVersion: j['firmware_version'] as String,
        role: DeviceRole.values[j['role'] as int],
        connectionMethod: ConnectionMethod.values[j['connection_method'] as int],
        supportsTaproot: j['supports_taproot'] as bool,
        pairedAt: DateTime.parse(j['paired_at'] as String),
      );
}
