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
| Phase 4 | 2 weeks | Blockchain | Watcher integration, monitoring | Not started |
| Phase 5 | 2 weeks | Recovery | Blockchain scanning, reconstruction | Not started |
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

## Phase 4: Watcher Service (Weeks 9-10)

**Goal:** Backend monitoring and notifications

### Week 9: Watcher Backend

- [ ] Initialize FastAPI project
- [ ] Implement Electrum client
- [ ] Build vault registration API
- [ ] Add UTXO monitoring loop
- [ ] Implement fee estimation endpoint
- [ ] Create broadcast endpoint

### Week 10: Push Notifications

- [ ] Set up Firebase project
- [ ] Implement FCM notification service
- [ ] Add alert triggering logic
- [ ] Build deep link handling in Flutter
- [ ] Create alert UI screens
- [ ] Test notification flow end-to-end

### Deliverables
- Watcher running and monitoring vaults
- Push notifications working
- Flutter app receiving and displaying alerts

---

## Phase 5: Recovery (Weeks 11-12)

**Goal:** Complete blockchain-based recovery

### Week 11: Blockchain Scanning

- [ ] Implement address derivation for scanning
- [ ] Build blockchain query batching
- [ ] Add UTXO detection logic
- [ ] Implement metadata extraction
- [ ] Create vault reconstruction

### Week 12: Recovery UX

- [ ] Build recovery wizard UI
- [ ] Add scanning progress indicators
- [ ] Implement vault verification display
- [ ] Handle edge cases:
  - [ ] No vaults found
  - [ ] Partial recovery
  - [ ] Multiple vaults
- [ ] Write integration tests for recovery

### Deliverables
- Full recovery working from seed phrase
- Recovery taking < 2 minutes
- All edge cases handled gracefully

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

### Low Risk: Watcher Availability

**Risk:** Watcher service downtime
**Mitigation:**
- Support self-hosted watcher
- Local monitoring fallback
- Multiple watcher endpoints

---

## Team Requirements

### Ideal Team Composition

| Role | Count | Focus |
|------|-------|-------|
| Flutter Developer | 1-2 | App UI/UX |
| Rust Developer | 1 | Core library |
| Backend Developer | 1 | Watcher service |
| Security Reviewer | 1 | Audit & testing |

### Solo Developer Path

If building alone:
1. Phase 1-2: Focus on Flutter + Rust core
2. Phase 3: Use existing HWI tooling
3. Phase 4: Minimal watcher, expand later
4. Phase 5-6: Get community security review

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
