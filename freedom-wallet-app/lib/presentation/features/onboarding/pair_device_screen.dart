import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:freedom_wallet/domain/errors/device_errors.dart';
import 'package:freedom_wallet/domain/models/device.dart';
import 'package:freedom_wallet/presentation/providers/device_provider.dart';
import 'package:freedom_wallet/presentation/common/widgets/device_card.dart';

class PairDeviceScreen extends ConsumerStatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  ConnectionMethod _selectedMethod = ConnectionMethod.usb;
  bool _verified = false;

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(pairedDeviceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pair Device')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect your hardware wallet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to connect your device',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            // Connection method tabs
            SegmentedButton<ConnectionMethod>(
              segments: const [
                ButtonSegment(
                  value: ConnectionMethod.usb,
                  label: Text('USB-C'),
                  icon: Icon(Icons.usb),
                ),
                ButtonSegment(
                  value: ConnectionMethod.bluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: ConnectionMethod.qrCode,
                  label: Text('QR Code'),
                  icon: Icon(Icons.qr_code),
                ),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (methods) {
                setState(() => _selectedMethod = methods.first);
              },
            ),
            const SizedBox(height: 32),
            // Device state
            Expanded(
              child: deviceState.when(
                data: (device) {
                  if (device == null) {
                    return _SearchButton(
                      method: _selectedMethod,
                      onSearch: () {
                        ref
                            .read(pairedDeviceProvider.notifier)
                            .pairDevice(_selectedMethod);
                      },
                    );
                  }
                  return SingleChildScrollView(
                    child: DeviceCard(
                      device: device,
                      verified: _verified,
                      onVerify: () async {
                        final notifier =
                            ref.read(pairedDeviceProvider.notifier);
                        final ok = await notifier
                            .verifyOnDevice('Verify device pairing');
                        if (ok && mounted) {
                          setState(() => _verified = true);
                        }
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching for device...'),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        e is TrezorBridgeUnavailableException
                            ? Icons.cloud_off
                            : Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage(e),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            ref.read(pairedDeviceProvider.notifier).reset(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Continue button
            if (deviceState.valueOrNull != null && _verified)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/template'),
                  child: const Text('Continue'),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object e) {
    if (e is TrezorBridgeUnavailableException) {
      return 'Trezor Bridge is not running.\nPlease start Trezor Suite.';
    }
    if (e is DeviceNotFoundException) {
      return 'No device found.\nCheck your USB connection and try again.';
    }
    if (e is DeviceTaprootUnsupportedException) {
      return 'Your device firmware is too old.\nUpdate to 2.4.0 or later for Taproot support.';
    }
    if (e is DeviceLockedError) {
      return 'Your device is locked.\nEnter your PIN on the device and try again.';
    }
    if (e is DeviceException) {
      return e.message;
    }
    return 'Error: $e';
  }
}

class _SearchButton extends StatelessWidget {
  final ConnectionMethod method;
  final VoidCallback onSearch;

  const _SearchButton({required this.method, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            method == ConnectionMethod.usb
                ? Icons.usb
                : method == ConnectionMethod.bluetooth
                    ? Icons.bluetooth
                    : Icons.qr_code,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            method == ConnectionMethod.usb
                ? 'Connect your device via USB-C'
                : method == ConnectionMethod.bluetooth
                    ? 'Enable Bluetooth on your device'
                    : 'Show QR code on your device',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            label: const Text('Search for Device'),
          ),
        ],
      ),
    );
  }
}
