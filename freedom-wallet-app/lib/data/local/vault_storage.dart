import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

const _vaultsKey = 'vault_list';
const _nextIndexKey = 'next_vault_index';

class VaultStorage {
  final FlutterSecureStorage _storage;

  VaultStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<Vault>> loadVaults() async {
    final json = await _storage.read(key: _vaultsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => _vaultFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveVaults(List<Vault> vaults) async {
    final json = jsonEncode(vaults.map(_vaultToJson).toList());
    await _storage.write(key: _vaultsKey, value: json);
  }

  Future<int> loadNextVaultIndex() async {
    final value = await _storage.read(key: _nextIndexKey);
    return value != null ? int.parse(value) : 0;
  }

  Future<void> saveNextVaultIndex(int index) async {
    await _storage.write(key: _nextIndexKey, value: index.toString());
  }

  // ═══════════════════════════════════════════════════════════════════
  //                    JSON SERIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _vaultToJson(Vault v) => {
        'id': v.id,
        'name': v.name,
        'template_type': v.template.type,
        'template_delay_blocks': v.template.delayBlocks,
        'template_recovery_type': v.template.recoveryType?.index,
        'balance_sats': v.balanceSats,
        'address': v.address,
        'descriptor': v.descriptor,
        'status': v.status.index,
        'primary_device_fingerprint': v.primaryDevice.fingerprint,
        'primary_device_name': v.primaryDevice.name,
        'emergency_device_fingerprint': v.emergencyDevice?.fingerprint,
        'emergency_device_name': v.emergencyDevice?.name,
        'network': v.network.index,
        'created_at': v.createdAt.toIso8601String(),
        'last_activity_at': v.lastActivityAt?.toIso8601String(),
      };

  static Vault _vaultFromJson(Map<String, dynamic> j) {
    final recoveryTypeIndex = j['template_recovery_type'] as int?;
    return Vault(
      id: j['id'] as String,
      name: j['name'] as String,
      template: VaultTemplate(
        type: j['template_type'] as String,
        delayBlocks: j['template_delay_blocks'] as int,
        recoveryType: recoveryTypeIndex != null
            ? RecoveryType.values[recoveryTypeIndex]
            : null,
      ),
      balanceSats: j['balance_sats'] as int,
      address: j['address'] as String,
      descriptor: j['descriptor'] as String,
      status: VaultStatus.values[j['status'] as int],
      primaryDevice: DeviceRef(
        fingerprint: j['primary_device_fingerprint'] as String,
        name: j['primary_device_name'] as String,
      ),
      emergencyDevice: j['emergency_device_fingerprint'] != null
          ? DeviceRef(
              fingerprint: j['emergency_device_fingerprint'] as String,
              name: j['emergency_device_name'] as String,
            )
          : null,
      network: Network.values[j['network'] as int],
      createdAt: DateTime.parse(j['created_at'] as String),
      lastActivityAt: j['last_activity_at'] != null
          ? DateTime.parse(j['last_activity_at'] as String)
          : null,
    );
  }
}
