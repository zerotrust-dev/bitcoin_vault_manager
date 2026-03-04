# Freedom Wallet

Bitcoin vault management app with hardware wallet integration. Self-custody made simple.

## Overview

Freedom Wallet solves three fears for Bitcoin holders:
1. **Fear of Theft** - 1-week vault delay + emergency escape mechanism
2. **Fear of Loss** - Seed phrase + blockchain = deterministic recovery (zero additional backups)
3. **Fear of Complexity** - Plain English UX + automatic recovery

## Architecture

```
Flutter App (UI/UX)  -->  Rust Core (via FFI)  -->  Esplora REST API  -->  Bitcoin Network
         |                                              |
         v                                              v
  Hardware Wallet  <-- Trezor Bridge HTTP API     UTXO monitoring, fee estimates, broadcast
```

- **vault-core/** - Rust library: key derivation, Taproot addresses, PSBT construction (14 FFI exports, 37 tests)
- **freedom-wallet-app/** - Flutter app: Riverpod state management, GoRouter navigation
- **design/** - 10 specification documents

## Prerequisites

- Flutter SDK ^3.11.0
- Rust toolchain (for building vault-core)
- Trezor Suite / Trezor Bridge (for hardware wallet communication)
- Windows: Developer Mode enabled

## Building

### Rust Core
```bash
cd vault-core
cargo build --release
# Produces: target/release/vault_core.dll (Windows)
```

### Flutter App
```bash
cd freedom-wallet-app
flutter pub get
flutter run -d windows
```

The DLL is copied automatically via CMake rule in `windows/CMakeLists.txt`.

## Configuration

Toggle between mock and real hardware wallet services via the `useMocks` constant in `lib/presentation/providers/vault_provider.dart`.

- `useMocks = true` - UI development without hardware (uses mock device/vault services)
- `useMocks = false` - Real Trezor Bridge + Rust FFI (requires Trezor connected)

## Hardware Wallet Support

| Device | Status | Connection |
|--------|--------|------------|
| Trezor (Model T, Safe 3/5) | Supported | USB via Trezor Bridge |
| Ledger | Planned (v1.1) | - |
| Coldcard | Planned | QR code |
| BitBox02 | Planned | - |

**Requirements:** Trezor firmware 2.4.0+ (Taproot/BIP86 support)

## Project Structure

```
lib/
  data/
    datasources/        # Rust FFI bridge + Esplora REST client
    local/              # Encrypted storage (vaults, devices, alerts)
    mock/               # Mock services for UI development
    services/
      device_drivers/   # Hardware wallet driver abstraction
      hardware_device_service.dart
      rust_vault_service.dart
      trezor_bridge_service.dart
      esplora_watcher_service.dart
      blockchain_alert_service.dart
      recovery_service_impl.dart
  domain/
    errors/             # Typed exceptions (device, blockchain)
    interfaces/         # Service contracts
    models/             # Data models (vault, utxo, fee estimates, recovery)
  presentation/
    common/widgets/     # Shared UI components
    features/           # Screen implementations
    providers/          # Riverpod state management
```

## Testing

```bash
# Run all tests (48 total: 20 Phase 3 + 18 Phase 4 + 10 Phase 5)
flutter test

# Run Phase 3 hardware wallet tests
flutter test test/data/services/trezor_bridge_client_test.dart
flutter test test/data/services/hardware_device_service_test.dart

# Run Phase 4 blockchain integration tests
flutter test test/data/services/esplora_watcher_service_test.dart
flutter test test/data/services/blockchain_alert_service_test.dart

# Run Phase 5 recovery tests
flutter test test/data/services/recovery_service_test.dart
```

## Development Phases

| Phase | Status | Focus |
|-------|--------|-------|
| Phase 1 | Complete | Flutter UI with mocks |
| Phase 2 | Complete | Rust core + FFI bridge |
| Phase 3 | Complete | Hardware wallet integration (Trezor) |
| Phase 4 | Complete | Blockchain integration (Esplora API) |
| Phase 5 | Complete | Recovery from blockchain scanning |
| Phase 6 | Not started | Polish + security audit |
