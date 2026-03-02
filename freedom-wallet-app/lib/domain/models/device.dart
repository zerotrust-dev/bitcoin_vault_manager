enum DeviceType {
  trezor,
  ledger,
  bitbox02,
  coldcard,
  generic,
}

enum DeviceRole {
  daily,
  emergency,
}

enum ConnectionMethod {
  usb,
  bluetooth,
  qrCode,
}

class DeviceInfo {
  final String name;
  final DeviceType type;
  final String fingerprint;
  final String xpub;
  final String firmwareVersion;
  final DeviceRole role;
  final ConnectionMethod connectionMethod;
  final bool supportsTaproot;
  final DateTime pairedAt;

  const DeviceInfo({
    required this.name,
    required this.type,
    required this.fingerprint,
    required this.xpub,
    required this.firmwareVersion,
    required this.role,
    required this.connectionMethod,
    required this.supportsTaproot,
    required this.pairedAt,
  });

  String get typeDisplayName {
    switch (type) {
      case DeviceType.trezor:
        return 'Trezor';
      case DeviceType.ledger:
        return 'Ledger';
      case DeviceType.bitbox02:
        return 'BitBox02';
      case DeviceType.coldcard:
        return 'Coldcard';
      case DeviceType.generic:
        return 'Generic';
    }
  }

  String get connectionDisplayName {
    switch (connectionMethod) {
      case ConnectionMethod.usb:
        return 'USB-C';
      case ConnectionMethod.bluetooth:
        return 'Bluetooth';
      case ConnectionMethod.qrCode:
        return 'QR Code';
    }
  }
}
