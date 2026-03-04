# Freedom Wallet (Bitcoin Vault Manager)

**The blockchain IS the backup.**

A Bitcoin vault management application that encodes vault metadata directly into Taproot script leaves, making every vault entirely self-describing on-chain. Recover all your vaults from a single seed phrase — no backup files, no cloud storage, no spreadsheets.

## Overview

Freedom Wallet is built for Bitcoin holders who want robust self-custody without the complexity. It uses time-delayed spending via CSV timelocks to create a cancellation window for unauthorized transactions, and an emergency key-path spend for immediate recovery when needed.

**Core insight:** By storing vault configuration in a never-executed Taproot script leaf, the blockchain itself becomes your backup. A seed phrase is all you need to reconstruct everything.

## Architecture

```
+-----------------------------------------------+
|          Flutter App (Dart)                    |
|  Cross-platform UI: Android, iOS, Desktop     |
+-------+------------------+--------------------+
        |                  |
        | C ABI (JSON)     | HTTP (localhost)
        |                  |
+-------v--------+  +------v-----------------+
| vault-core     |  | Trezor Bridge          |
| (Rust Library) |  | (Hardware Wallet API)  |
+----------------+  +------------------------+
                       |
        +--------------+
        | REST API
        |
+-------v-----------------------------+
|     Esplora API (Blockchain)        |
|  UTXO queries, fee estimates,       |
|  transaction broadcast, monitoring  |
+-------------------------------------+
```

## Key Features

- **Time-delayed spending** — Normal spends require a CSV timelock (1 week for savings, 1 day for spending vaults), giving you a cancellation window if a transaction is unauthorized
- **Emergency recovery** — A secondary hardware wallet can bypass the delay via key-path spend for immediate access
- **Blockchain-encoded metadata** — Vault configuration stored in a Taproot script leaf; seed phrase alone enables full recovery
- **Vault templates** — Savings (1008-block delay), Spending (144-block delay), or Custom configurations
- **Sweep-only transactions** — No change outputs, eliminating an entire class of complexity
- **Active monitoring** — Esplora-based polling detects on-chain activity and generates alerts
- **Deterministic recovery** — Reconstruct all vaults from seed phrase + blockchain scan in under 2 minutes
- **Cross-platform** — Single Flutter codebase for Android, iOS, Windows, macOS, and Linux

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Cryptographic Core | Rust | All Bitcoin operations via native library |
| UI Application | Flutter (Dart) | Cross-platform frontend |
| Blockchain API | Esplora REST API | UTXO queries, fee estimates, broadcast |
| Bitcoin Libraries | BDK 0.30, rust-bitcoin 0.30, miniscript 10.0 | Taproot, PSBT, key handling |
| Key Management | bip39 2.0, secp256k1 0.27 | Mnemonic and EC operations |
| FFI Bridge | libc, dart:ffi | C ABI between Rust and Flutter |
| Local Storage | flutter_secure_storage | Encrypted vault, device, and alert persistence |

## Project Structure

```
bitcoin_vault_manager/
├── design/                     # Specification documents
│   ├── 00_PROJECT_OVERVIEW.md
│   ├── 01_RUST_CORE_SPEC.md
│   ├── 02_FLUTTER_APP_SPEC.md
│   ├── 03_DATA_MODELS.md
│   ├── 04_FFI_INTERFACE.md
│   ├── 05_WATCHER_SERVICE.md
│   ├── 06_USER_FLOWS.md
│   ├── 08_SECURITY_MODEL.md
│   ├── 09_TESTING_STRATEGY.md
│   └── 10_DEVELOPMENT_ROADMAP.md
├── vault-core/                 # Rust cryptographic library
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs              # FFI exports
│       ├── error.rs            # Error types with FFI codes
│       ├── ffi/mod.rs          # C string helpers
│       ├── vault/mod.rs        # Core types (Network, VaultTemplate, etc.)
│       ├── keys/mod.rs         # Key derivation (Phase 2)
│       └── taproot/mod.rs      # Address generation (Phase 2)
├── freedom-wallet-app/         # Flutter application
│   └── lib/
│       ├── data/
│       │   ├── datasources/    # Rust FFI bridge + Esplora client
│       │   ├── local/          # Secure local storage (vaults, devices, alerts)
│       │   ├── mock/           # Mock services for development
│       │   └── services/       # Real service implementations
│       │       └── device_drivers/  # Hardware wallet driver abstraction
│       ├── domain/
│       │   ├── errors/         # Typed exceptions (device, blockchain)
│       │   ├── interfaces/     # Service abstractions
│       │   └── models/         # Domain models (vault, utxo, recovery, etc.)
│       └── presentation/       # Screens, widgets, providers
└── README.md
```

## Getting Started

### Prerequisites

- [Rust](https://rustup.rs/) (stable toolchain)
- [Flutter](https://flutter.dev/docs/get-started/install) (for the app, Phase 1)

### Building vault-core

```bash
cd vault-core
cargo build
cargo test
```

This produces the native library (`vault_core.dll` / `libvault_core.so` / `libvault_core.dylib`) used by the Flutter app via FFI.

## Current Status

**Phase:** Post-Phase 5 (Recovery system complete)

### Implemented

- Complete design specification (10 documents)
- vault-core Rust library (14 FFI exports, 37 tests passing):
  - Key derivation: BIP86 paths, xpub validation, child pubkey derivation
  - Taproot addresses: P2TR generation with spending script + metadata leaf
  - PSBT construction: delayed spend (CSV timelock) and emergency (key-path)
  - Policy verification, PSBT finalization, metadata encoding/decoding
  - Error system with structured error codes
- Flutter app with full UI and Rust FFI integration:
  - Dart FFI bridge binding all 14 Rust functions
  - Service abstraction layer (interfaces + mock/real implementations)
  - Real Taproot address generation in onboarding flow
  - Local vault persistence via secure storage
  - Toggle between mock and real services for development
- Hardware wallet integration (Phase 3, 20 tests):
  - Trezor Bridge HTTP API communication
  - DeviceDriver abstraction layer (ready for Ledger/Coldcard)
  - xpub export, address display, PSBT signing via Trezor
  - Encrypted device persistence and typed error handling
- Blockchain integration (Phase 4, 18 tests):
  - Esplora REST API client (mainnet, testnet, signet)
  - WatcherService with 60-second polling for vault address activity
  - AlertService with local persistence and action buttons (dismiss, view, cancel)
  - Spend wizard auto-fetches UTXOs and fee estimates from blockchain
  - Transaction broadcast through Esplora API
  - Dashboard lifecycle-aware polling (start/stop on app resume/pause)
- Recovery system (Phase 5, 10 tests):
  - Blockchain scanning via deterministic address derivation (same xpub + index = same address)
  - Gap limit scanning (20 consecutive empty indices) across savings and spending templates
  - RecoveryService with Esplora integration and 100ms rate limiting
  - Recovery wizard UI with 4 steps: Connect, Scan, Review, Confirm
  - Edge cases: no vaults found, user cancellation, Esplora errors, duplicate prevention

### Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| Phase 1 | Flutter UI with mocks | **Complete** |
| Phase 2 | Rust core integration (addresses, PSBT) | **Complete** |
| Phase 3 | Hardware wallet integration (Trezor) | **Complete** |
| Phase 4 | Blockchain integration (Esplora API) | **Complete** |
| Phase 5 | Recovery system (blockchain scanning) | **Complete** |
| Phase 6 | Polish and security audit | Not started |

See [design/10_DEVELOPMENT_ROADMAP.md](design/10_DEVELOPMENT_ROADMAP.md) for the full 14-week plan.

## License

TBD
