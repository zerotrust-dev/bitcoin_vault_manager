/// Base class for all hardware device errors.
abstract class DeviceException implements Exception {
  final String message;
  const DeviceException(this.message);

  @override
  String toString() => message;
}

/// Device not found — not connected or bridge not running.
class DeviceNotFoundException extends DeviceException {
  const DeviceNotFoundException([super.message = 'No device found']);
}

/// Device disconnected mid-operation.
class DeviceDisconnectedException extends DeviceException {
  const DeviceDisconnectedException([super.message = 'Device disconnected']);
}

/// User rejected the operation on the device (pressed cancel/reject button).
class DeviceUserDeniedException extends DeviceException {
  const DeviceUserDeniedException([super.message = 'User rejected on device']);
}

/// Device is locked and needs PIN entry.
class DeviceLockedError extends DeviceException {
  const DeviceLockedError([super.message = 'Device is locked']);
}

/// Device does not support Taproot / BIP86.
class DeviceTaprootUnsupportedException extends DeviceException {
  const DeviceTaprootUnsupportedException(
      [super.message = 'Device does not support Taproot']);
}

/// Trezor Bridge HTTP server not reachable.
class TrezorBridgeUnavailableException extends DeviceException {
  const TrezorBridgeUnavailableException(
      [super.message = 'Trezor Bridge not running. Please start Trezor Suite.']);
}

/// PSBT signing failed on device.
class SigningFailedException extends DeviceException {
  const SigningFailedException([super.message = 'Signing failed on device']);
}
