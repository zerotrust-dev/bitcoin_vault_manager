# Development Roadmap

## Overview

This document outlines the phased implementation plan for Freedom Wallet, from MVP to production-ready release.

---

## Phase Summary

| Phase | Duration | Focus | Deliverable |
|-------|----------|-------|-------------|
| Phase 1 | 2 weeks | Foundation | Clickable prototype with mocks |
| Phase 2 | 3 weeks | Core Integration | Rust FFI working, real addresses |
| Phase 3 | 3 weeks | Hardware Wallet | Device pairing and signing |
| Phase 4 | 2 weeks | Blockchain | Watcher integration, monitoring |
| Phase 5 | 2 weeks | Recovery | Blockchain scanning, reconstruction |
| Phase 6 | 2 weeks | Polish | Testing, UX refinement, security audit |

**Total: ~14 weeks to production MVP**

---

## Phase 1: Foundation (Weeks 1-2)

**Goal:** Build complete UI/UX with mocked backend

### Week 1: Project Setup & Core Screens

- [ ] Initialize Flutter project structure
- [ ] Configure dependencies (Riverpod, GoRouter, etc.)
- [ ] Implement theme and design system
- [ ] Create mock service interfaces
- [ ] Build screens:
  - [ ] Welcome screen
  - [ ] Pair device screen (mocked)
  - [ ] Template selection screen
  - [ ] Publish vault screen

### Week 2: Dashboard & Flows

- [ ] Build screens:
  - [ ] Dashboard
  - [ ] Vault detail
  - [ ] Spend wizard
  - [ ] Backup center
- [ ] Implement navigation flows
- [ ] Add mock data generators
- [ ] Write widget tests for all screens

### Deliverables
- Clickable prototype running on desktop/mobile
- All screens navigable with mock data
- Widget tests passing

---

## Phase 2: Rust Core Integration (Weeks 3-5)

**Goal:** Replace mocks with real Rust cryptographic operations

### Week 3: Rust Project Setup

- [ ] Initialize Rust library structure
- [ ] Add dependencies (bdk, bitcoin, serde)
- [ ] Implement FFI string helpers
- [ ] Create basic types:
  - [ ] Network enum
  - [ ] VaultTemplate struct
  - [ ] VaultMetadata struct
- [ ] Build desktop library (.dll/.so/.dylib)
- [ ] Connect Flutter FFI bridge (version check)

### Week 4: Address Generation

- [ ] Implement key derivation from xpub
- [ ] Build Taproot address generation
- [ ] Implement metadata encoding in script leaf
- [ ] Add descriptor generation
- [ ] FFI functions:
  - [ ] `generate_vault_address`
  - [ ] `decode_metadata_leaf`
  - [ ] `validate_address`
- [ ] Unit tests for address generation

### Week 5: Transaction Building

- [ ] Implement PSBT construction
- [ ] Add CSV delay scripts
- [ ] Implement emergency (key-path) spend
- [ ] Add fee calculation
- [ ] FFI functions:
  - [ ] `build_delayed_spend_psbt`
  - [ ] `build_emergency_psbt`
  - [ ] `verify_psbt_policy`
  - [ ] `finalize_psbt`
- [ ] Integration tests for transaction flows

### Deliverables
- Rust library generating real Taproot addresses
- PSBT construction working
- Flutter app using Rust core via FFI

---

## Phase 3: Hardware Wallet Integration (Weeks 6-8)

**Goal:** Real hardware wallet pairing and signing

### Week 6: Device Communication Foundation

- [ ] Research HWI/device protocols
- [ ] Implement device discovery:
  - [ ] USB enumeration
  - [ ] BLE scanning
- [ ] Create device abstraction layer
- [ ] Build Trezor driver (first target)

### Week 7: Pairing & Key Export

- [ ] Implement xpub export from device
- [ ] Add device fingerprint extraction
- [ ] Build WYSIWYS address display flow
- [ ] Handle connection state management
- [ ] Add reconnection logic

### Week 8: Signing

- [ ] Implement PSBT signing via device
- [ ] Add progress indicators for device operations
- [ ] Handle multi-round signing if needed
- [ ] Test with real Trezor on testnet
- [ ] Document supported devices

### Deliverables
- Trezor integration working
- Create vault → fund → spend flow on testnet
- Device communication robust

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
