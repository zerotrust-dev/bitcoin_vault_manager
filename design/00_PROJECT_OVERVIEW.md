# Freedom Wallet - Project Overview

## Executive Summary

Freedom Wallet is a Bitcoin vault management application designed for "Average Ricky" - the paranoid Bitcoin holder who owns a hardware wallet but doesn't trust themselves to use it correctly. The solution solves three fundamental fears:

1. **Fear of Theft**: 1-week vault delay + emergency escape mechanism
2. **Fear of Loss**: Seed phrase + blockchain = deterministic recovery (ZERO additional backups)
3. **Fear of Complexity**: Plain English UX + automatic recovery

## The Breakthrough Innovation

**The blockchain IS the backup.**

By encoding vault metadata in a Taproot script leaf (never-used spending condition), every vault becomes a complete, self-describing unit of information. The blockchain stores it immutably. Recovery reads it deterministically.

**Ricky only backs up what he already backs up: the seed phrase.**

---

## Project Structure

This project consists of **two repositories** that work together:

### Repository 1: `vault-core` (Rust Library)
The cryptographic engine that handles all sensitive Bitcoin operations.

**Responsibilities:**
- BIP32/BIP39 key derivation
- Taproot address generation with metadata leaves
- PSBT construction and validation
- Descriptor management
- Transaction building (delayed spend, cancel, emergency recovery)
- Metadata encoding/decoding

**Output:** Compiled library (.dll/.so/.dylib) exposed via FFI

### Repository 2: `freedom-wallet-app` (Flutter Application)
The cross-platform UI/UX application that users interact with.

**Responsibilities:**
- Hardware wallet pairing (USB, BLE, QR)
- Vault creation wizard
- Dashboard and vault management
- WYSIWYS verification flows
- Recovery wizard
- Alert system UI
- Communication with Watcher backend

**Platforms:** Android, iOS, Windows, macOS, Linux

### Backend Service: `vault-watcher` (FastAPI)
A lightweight monitoring service for vault activity.

**Responsibilities:**
- Monitor blockchain for vault address activity
- Send push notifications when spends are detected
- Accept cancel/recovery instructions
- Health checks

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                             │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │   SETUP          │  │   SPENDING       │  │   RECOVERY       │  │
│  │   Day 1          │  │   Day X          │  │   Day 1000       │  │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
└───────────┼──────────────────────┼──────────────────────┼───────────┘
            │                      │                      │
            ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP (UI/UX)                            │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │ Onboarding  │  │  Dashboard  │  │   Backup    │  │   Alerts   │ │
│  │   Wizard    │  │             │  │   Center    │  │   Center   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
└─────────┼────────────────┼────────────────┼───────────────┼─────────┘
          │                │                │               │
          ▼                ▼                ▼               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RUST CORE (via FFI)                            │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   Key       │  │  Taproot    │  │    PSBT     │  │  Metadata  │ │
│  │ Derivation  │  │  Address    │  │  Building   │  │  Encoding  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
          │                │                │               │
          ▼                ▼                ▼               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SYSTEMS                                  │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │  Hardware   │  │  Bitcoin    │  │   Watcher   │  │   Push     │ │
│  │   Wallet    │  │  Blockchain │  │   Backend   │  │  Service   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## User Personas

### Primary: "Average Ricky"
- Owns Bitcoin and a hardware wallet
- Understands seed phrase backups
- Fears theft, loss, and complexity
- Wants peace of mind without technical complexity
- Needs plain English explanations

### Secondary: "Technical Tom"
- Power user who wants custom vault configurations
- Understands Taproot, descriptors, PSBTs
- Wants full control and verification capabilities

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Setup time | < 10 minutes |
| Recovery time | < 10 minutes |
| Additional backups required | ZERO |
| Recovery reliability | 100% deterministic |
| Ricky's fear level | From HIGH to VERY LOW |

---

## Document Index

| Document | Purpose |
|----------|---------|
| `01_RUST_CORE_SPEC.md` | Complete Rust core library specification |
| `02_FLUTTER_APP_SPEC.md` | Flutter app architecture and screens |
| `03_DATA_MODELS.md` | All data models and types |
| `04_FFI_INTERFACE.md` | FFI bridge between Rust and Dart |
| `05_WATCHER_SERVICE.md` | Backend watcher service specification |
| `06_USER_FLOWS.md` | Detailed user journey flows |
| `07_API_CONTRACTS.md` | API contracts and mock implementations |
| `08_SECURITY_MODEL.md` | Security architecture and threat model |
| `09_TESTING_STRATEGY.md` | Testing approach and scenarios |
| `10_DEVELOPMENT_ROADMAP.md` | Phased implementation plan |

---

## Key Technical Decisions

1. **Rust for cryptographic core**: Battle-tested Bitcoin libraries (BDK, rust-bitcoin)
2. **Flutter for UI**: Single codebase for all platforms
3. **FFI bridge**: Direct native calls, no overhead
4. **Metadata in Taproot leaves**: Blockchain as immutable backup
5. **WYSIWYS verification**: Hardware wallet displays match app
6. **Sweep-only transactions**: No change output complexity
7. **Template-based vaults**: Pre-defined security configurations

---

## Getting Started

1. Read this overview document
2. Review the architecture in `01_RUST_CORE_SPEC.md`
3. Understand data models in `03_DATA_MODELS.md`
4. Follow the development roadmap in `10_DEVELOPMENT_ROADMAP.md`

**Remember:** Every design decision flows from solving Ricky's three fears.
