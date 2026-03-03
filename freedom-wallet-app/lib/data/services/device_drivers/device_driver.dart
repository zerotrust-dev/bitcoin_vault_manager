import 'package:freedom_wallet/domain/models/device.dart';

/// Internal driver interface implemented per hardware wallet vendor.
///
/// Each driver handles the low-level protocol for one device family
/// (e.g., Trezor Bridge HTTP, Ledger HID, etc.).
abstract class DeviceDriver {
  /// Enumerate available devices. Returns empty list if none found.
  Future<List<DiscoveredDevice>> enumerate();

  /// Open a session with a specific device.
  Future<DeviceSession> openSession(DiscoveredDevice device);
}

/// A device found during enumeration, before a session is opened.
class DiscoveredDevice {
  final String path;
  final String label;
  final DeviceType type;
  final ConnectionMethod connectionMethod;

  const DiscoveredDevice({
    required this.path,
    required this.label,
    required this.type,
    required this.connectionMethod,
  });
}

/// An open, authenticated session with a hardware device.
/// Callers must call [close] when done.
abstract class DeviceSession {
  DeviceType get type;
  ConnectionMethod get connectionMethod;

  /// Get device firmware version and metadata.
  Future<DeviceMetadata> getMetadata();

  /// Export xpub at a BIP86 derivation path.
  ///
  /// [derivationPath] is a BIP32 path string, e.g. "m/86'/0'/0'".
  Future<String> getXpub(String derivationPath);

  /// Ask the user to verify an address on the device screen.
  ///
  /// Returns true if the user confirmed. Throws [DeviceUserDeniedException]
  /// if the user rejected.
  Future<bool> displayAddress(String address, String derivationPath);

  /// Sign a PSBT. Returns the signed PSBT in base64.
  Future<String> signPsbt(String psbtBase64);

  /// Release the device session.
  Future<void> close();
}

/// Metadata returned from the device after opening a session.
class DeviceMetadata {
  final String firmwareVersion;
  final String fingerprint;
  final DeviceType type;
  final String label;
  final bool supportsTaproot;

  const DeviceMetadata({
    required this.firmwareVersion,
    required this.fingerprint,
    required this.type,
    required this.label,
    required this.supportsTaproot,
  });
}
