# Development Roadmap

## Overview

This document outlines the phased implementation plan for Freedom Wallet, from MVP to production-ready release.

---

## Phase Summary

| Phase | Duration | Focus | Deliverable | Status |
|-------|----------|-------|-------------|--------|
| Phase 1 | 2 weeks | Foundation | Clickable prototype with mocks | **Complete** |
| Phase 2 | 3 weeks | Core Integration | Rust FFI working, real addresses | **Complete** |
| Phase 3 | 3 weeks | Hardware Wallet | Device pairing and signing | **Complete** |
| Phase 4 | 2 weeks | Blockchain | Esplora integration, monitoring | **Complete** |
| Phase 5 | 2 weeks | Recovery | Blockchain scanning, reconstruction | **Complete** |
| Phase 6 | 2 weeks | Polish | Testing, UX refinement, security audit | Not started |

**Total: ~14 weeks to production MVP**

---

## Phase 1: Foundation (Weeks 1-2) — COMPLETE

**Goal:** Build complete UI/UX with mocked backend

### Week 1: Project Setup & Core Screens

- [x] Initialize Flutter project structure
- [x] Configure dependencies (Riverpod, GoRouter, etc.)
- [x] Implement theme and design system
- [x] Create mock service interfaces
- [x] Build screens:
  - [x] Welcome screen
  - [x] Pair device screen (mocked)
  - [x] Template selection screen
  - [x] Publish vault screen

### Week 2: Dashboard & Flows

- [x] Build screens:
  - [x] Dashboard
  - [x] Vault detail
  - [x] Spend wizard
  - [x] Backup center
- [x] Implement navigation flows
- [x] Add mock data generators
- [x] Write widget tests for all screens

### Deliverables
- Clickable prototype running on desktop/mobile
- All screens navigable with mock data
- Widget tests passing

---

## Phase 2: Rust Core Integration (Weeks 3-5) — COMPLETE

**Goal:** Replace mocks with real Rust cryptographic operations

### Week 3: Rust Project Setup

- [x] Initialize Rust library structure
- [x] Add dependencies (bdk, bitcoin, serde)
- [x] Implement FFI string helpers
- [x] Create basic types:
  - [x] Network enum
  - [x] VaultTemplate struct
  - [x] VaultMetadata struct
- [x] Build desktop library (.dll/.so/.dylib)
- [x] Connect Flutter FFI bridge (version check)

### Week 4: Address Generation

- [x] Implement key derivation from xpub
- [x] Build Taproot address generation
- [x] Implement metadata encoding in script leaf
- [x] Add descriptor generation
- [x] FFI functions:
  - [x] `generate_vault_address`
  - [x] `decode_metadata_leaf`
  - [x] `validate_address`
- [x] Unit tests for address generation

### Week 5: Transaction Building

- [x] Implement PSBT construction
- [x] Add CSV delay scripts
- [x] Implement emergency (key-path) spend
- [x] Add fee calculation
- [x] FFI functions:
  - [x] `build_delayed_spend_psbt`
  - [x] `build_emergency_psbt`
  - [x] `verify_psbt_policy`
  - [x] `finalize_psbt`
- [x] Integration tests for transaction flows

### Deliverables
- Rust library generating real Taproot addresses (14 FFI exports, 37 tests)
- PSBT construction working
- Flutter app using Rust core via FFI

---

## Phase 3: Hardware Wallet Integration (Weeks 6-8) — COMPLETE

**Goal:** Real hardware wallet pairing and signing

**Implementation:** Trezor Bridge HTTP API (localhost:21325) with DeviceDriver abstraction layer.

### Week 6: Device Communication Foundation

- [x] Research HWI/device protocols (chose Trezor Bridge HTTP API)
- [x] Implement device discovery:
  - [x] USB enumeration (via Trezor Bridge)
  - [ ] BLE scanning (deferred — Trezor Safe 5 BLE support planned)
- [x] Create device abstraction layer (`DeviceDriver` / `DeviceSession`)
- [x] Build Trezor driver (first target)

### Week 7: Pairing & Key Export

- [x] Implement xpub export from device (`GetPublicKey` with BIP86 path)
- [x] Add device fingerprint extraction
- [x] Build WYSIWYS address display flow (`displayAddress` via `GetAddress`)
- [x] Handle connection state management (`DeviceConnectionStatus` provider)
- [x] Add device persistence (`DeviceStorage` with `FlutterSecureStorage`)
- [x] Fix xpub bug in `DeviceRef` / `RustVaultService`

### Week 8: Signing

- [x] Implement PSBT signing via device (`signPsbt` on `TrezorSession`)
- [x] Add progress indicators for device operations
- [x] Wire spend wizard with real PSBT build → device sign → finalize flow
- [x] Add manual UTXO input for testnet (txid:vout:amount_sats format)
- [x] Add typed error handling (`DeviceException` hierarchy, 7 error types)
- [x] Write 20 unit tests (TrezorBridgeClient, TrezorDriver, HardwareDeviceService)
- [ ] Test with real Trezor on testnet (requires Trezor hardware)

### Deliverables
- Trezor integration working via Trezor Bridge HTTP API
- `DeviceDriver` abstraction ready for Ledger/Coldcard drivers
- Create vault → fund → spend flow wired with real PSBT + device signing
- Device communication with typed errors and connection state management
- 20 Phase 3 tests passing

### Key Files Added
- `lib/data/services/trezor_bridge_service.dart` — Trezor Bridge HTTP client
- `lib/data/services/device_drivers/device_driver.dart` — Abstract driver interface
- `lib/data/services/device_drivers/trezor_driver.dart` — Trezor implementation
- `lib/data/services/hardware_device_service.dart` — Real `DeviceService`
- `lib/data/local/device_storage.dart` — Encrypted device persistence
- `lib/domain/errors/device_errors.dart` — Typed exception hierarchy

---

## Phase 4: Blockchain Integration (Weeks 9-10) — COMPLETE

**Goal:** Direct blockchain monitoring and alerts via Esplora REST API (no backend server required)

**Implementation:** Esplora REST API with network-aware base URLs (mainnet=blockstream.info/api, testnet=blockstream.info/testnet/api, signet=mempool.space/signet/api). Polling-based monitoring with local alert persistence.

### Week 9: Esplora Client & Watcher

- [x] Implement Esplora REST client (`EsploraClient`)
- [x] Build UTXO query for vault addresses
- [x] Implement fee estimation endpoint
- [x] Create transaction broadcast endpoint
- [x] Extract `WatcherService` interface + `EsploraWatcherService` real implementation
- [x] Add `MockWatcherService` for development
- [x] Wire spend wizard to auto-fetch UTXOs from blockchain (manual UTXO as collapsed fallback)

### Week 10: Alert System & Monitoring

- [x] Extract `AlertService` interface from `MockAlertService`
- [x] Implement `BlockchainAlertService` with local persistence (`AlertStorage`)
- [x] Build `VaultMonitorNotifier` with 60-second polling loop
- [x] Generate alerts on balance changes (deposits, withdrawals, unauthorized spends)
- [x] Wire alert action buttons: dismiss, view details, cancel transaction
- [x] Add dashboard lifecycle-aware polling (start/stop on app resume/pause via `WidgetsBindingObserver`)
- [x] Add typed error handling (`BlockchainException` hierarchy)
- [x] Write 18 unit tests (`EsploraWatcherService`, `BlockchainAlertService`)

### Deliverables
- Direct Esplora API integration (no backend server needed)
- Vault address monitoring with configurable polling interval
- Local alert system with persistence and action buttons
- Auto-UTXO fetching and fee estimates in spend wizard
- Transaction broadcast through Esplora
- 18 Phase 4 tests passing (38 total with Phase 3)

### Key Files Added
- `lib/data/datasources/esplora_client.dart` — Esplora REST API client
- `lib/data/services/esplora_watcher_service.dart` — Real `WatcherService`
- `lib/data/services/blockchain_alert_service.dart` — Real `AlertService` with persistence
- `lib/data/mock/mock_watcher_service.dart` — Mock `WatcherService`
- `lib/data/local/alert_storage.dart` — Local alert persistence
- `lib/domain/interfaces/watcher_service.dart` — Watcher interface
- `lib/domain/interfaces/alert_service.dart` — Alert interface
- `lib/domain/errors/blockchain_errors.dart` — Typed exception hierarchy
- `lib/domain/models/utxo.dart` — UTXO and FeeEstimates models
- `lib/presentation/providers/watcher_provider.dart` — VaultMonitorNotifier

---

## Phase 5: Recovery (Weeks 11-12) — COMPLETE

**Goal:** Complete blockchain-based recovery

**Implementation:** Composes existing Rust FFI functions (`generateVaultAddress` + `getUtxos`) in a scanning loop — no new FFI functions needed. Deterministic address derivation (same xpub + index = same address) with gap limit scanning via Esplora API.

### Week 11: Blockchain Scanning

- [x] Implement address derivation for scanning (reuses `generateVaultAddress` via Rust FFI)
- [x] Build blockchain query with rate limiting (100ms delay between Esplora requests)
- [x] Add UTXO detection logic (per-address via Esplora `getUtxos`)
- [x] Implement gap limit scanning (GAP_LIMIT=20 consecutive empty indices)
- [x] Create vault reconstruction (`importRecoveredVault` on `VaultService`)

### Week 12: Recovery UX

- [x] Build recovery wizard UI (ConsumerStatefulWidget with 4 steps: Connect → Scan → Review → Confirm)
- [x] Add scanning progress indicators (`RecoveryNotifier`: idle → scanning → reviewing → confirming → complete)
- [x] Implement vault verification display (review step with discovered vaults)
- [x] Handle edge cases:
  - [x] No vaults found
  - [x] User cancellation
  - [x] Esplora errors
  - [x] Duplicate prevention
- [x] Write 10 unit tests for recovery (48 total with Phases 3-4)

### Deliverables
- Full recovery from seed phrase via blockchain scanning
- Recovery uses deterministic address derivation (same xpub + index = same address)
- Scanning completes in seconds (GAP_LIMIT=20, 2 templates = ~40 requests with 100ms delay)
- Edge cases handled: no vaults found, user cancellation, Esplora errors, duplicate prevention
- 10 Phase 5 tests passing (48 total with Phases 3-4)

### Key Files Added
- `lib/domain/models/recovery.dart` — RecoveredVault, RecoveryProgress, RecoveryResult models
- `lib/domain/interfaces/recovery_service.dart` — Abstract recovery interface
- `lib/data/services/recovery_service_impl.dart` — Core scanning logic (gap limit, rate limiting)
- `lib/data/mock/mock_recovery_service.dart` — Mock for development
- `lib/presentation/providers/recovery_provider.dart` — RecoveryNotifier state management

### Key Files Modified
- `lib/domain/interfaces/vault_service.dart` — Added `importRecoveredVault` method
- `lib/data/services/rust_vault_service.dart` — Implemented `importRecoveredVault`, made `templateToRustJson` public
- `lib/data/mock/mock_vault_service.dart` — Implemented `importRecoveredVault`
- `lib/presentation/features/backup/recovery_wizard_screen.dart` — Full rewrite with real Riverpod-driven UI

---

## Phase 6: Polish & Security (Weeks 13-14)

**Goal:** Production-ready quality

### Week 13: Testing & Fixes

- [ ] Complete unit test coverage (>80%)
- [ ] Write integration test suite
- [ ] Perform security review
- [ ] Fix identified issues
- [ ] Add error reporting (Sentry)
- [ ] Implement analytics (privacy-respecting)

### Week 14: Documentation & Release

- [ ] Write user documentation
- [ ] Create video tutorials
- [ ] Prepare App Store listings
- [ ] Build reproducible release
- [ ] Submit for testnet beta
- [ ] Plan mainnet launch

### Deliverables
- All tests passing
- Security review complete
- Beta release ready

---

## Technical Milestones

### Milestone 1: First Vault Created (Week 5)
- User can create vault with real Taproot address
- Address verifiable on block explorer (testnet)
- Metadata correctly encoded

### Milestone 2: First Spend Signed (Week 8)
- User can sign PSBT with hardware wallet
- Transaction broadcasts successfully
- Delay mechanism works correctly

### Milestone 3: First Recovery (Week 12)
- User can recover vault on new device
- Recovery is 100% deterministic
- All vault data reconstructed

### Milestone 4: Production Ready (Week 14)
- All features working on mainnet
- Security audit passed
- App Store ready

---

## Risk Mitigation

### High Risk: Hardware Wallet Compatibility

**Risk:** Different devices have different APIs
**Mitigation:**
- Start with one device (Trezor)
- Abstract device layer for future additions
- Document device requirements clearly

### Medium Risk: Taproot Script Complexity

**Risk:** Script construction errors could lock funds
**Mitigation:**
- Extensive test coverage
- Testnet-only until audited
- Deterministic address verification

### Medium Risk: Recovery Failure

**Risk:** Metadata decoding could fail
**Mitigation:**
- Version field for future compatibility
- Fallback to manual descriptor import
- Regular recovery testing

### Low Risk: Esplora API Availability

**Risk:** Esplora endpoint downtime
**Mitigation:**
- Network-aware base URLs with multiple providers
- Local monitoring with configurable polling interval
- Graceful degradation when API unreachable

---

## Team Requirements

### Ideal Team Composition

| Role | Count | Focus |
|------|-------|-------|
| Flutter Developer | 1-2 | App UI/UX |
| Rust Developer | 1 | Core library |
| Backend Developer | 0-1 | Optional (Esplora API used directly) |
| Security Reviewer | 1 | Audit & testing |

### Solo Developer Path

If building alone:
1. Phase 1-2: Focus on Flutter + Rust core (done)
2. Phase 3: Use existing HWI tooling (done — Trezor Bridge)
3. Phase 4: Direct Esplora API, no backend server (done)
4. Phase 5: Compose existing FFI for recovery scanning (done)
5. Phase 6: Get community security review

---

## Success Criteria

### MVP Success
- [ ] Create vault in < 10 minutes
- [ ] Recover vault in < 5 minutes
- [ ] Zero additional backup files
- [ ] Successful testnet transactions
- [ ] Hardware wallet signing works

### Production Success
- [ ] 100 users on mainnet
- [ ] Zero fund losses
- [ ] < 1% error rate
- [ ] 4+ star app rating
- [ ] Security audit passed

---

## Post-MVP Roadmap

### Version 1.1: Multi-Device
- Second hardware wallet support (Ledger)
- Multi-signature vaults
- 2-of-3 threshold signing

### Version 1.2: Advanced Features
- Custom delay periods
- Multiple vault types
- Batch operations

### Version 1.3: Network
- Lightning Network integration
- Fiat on-ramp partnerships
- Social recovery (optional)

### Version 2.0: Covenants
- When Bitcoin supports OP_CTV/OP_VAULT
- Native covenant-based vaults
- Enhanced security features
