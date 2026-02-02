# Security Model

## Overview

Freedom Wallet is designed with a defense-in-depth security model. The core principle is: **no single point of failure can result in fund loss**.

---

## Threat Model

### Assets to Protect

1. **Bitcoin funds** - User's savings in vaults
2. **Private keys** - Never exposed to app
3. **Vault metadata** - Encoded on blockchain
4. **User privacy** - Transaction patterns

### Threat Actors

| Actor | Capability | Goal |
|-------|------------|------|
| Phone Malware | Full device access | Steal funds |
| Phishing Attack | Social engineering | Trick user |
| Network Attacker | MITM, packet injection | Redirect transactions |
| Physical Theft | Device possession | Access funds |
| Insider (App Dev) | Code modification | Backdoor |

---

## Security Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 1: Hardware Wallet                        │
│                                                                      │
│  • Private keys NEVER leave device                                  │
│  • User confirms every transaction visually                         │
│  • Tamper-resistant hardware                                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 2: Time Delay                            │
│                                                                      │
│  • All spends require CSV timelock (default: 1 week)               │
│  • User can cancel during delay period                              │
│  • Emergency device can bypass delay                                │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 3: Active Monitoring                     │
│                                                                      │
│  • Watcher monitors all vault activity                              │
│  • Push notifications for any spend attempt                         │
│  • User has time to respond to unauthorized activity               │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 4: Verification                          │
│                                                                      │
│  • WYSIWYS: Address verified on hardware device                     │
│  • All destinations pre-approved                                    │
│  • Blockchain transparency                                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Attack Scenarios & Mitigations

### Scenario 1: Phone Compromised by Malware

**Attack Vector:**
1. Malware gains root access
2. Modifies app to change destination address
3. Tricks user into signing to attacker address

**Mitigations:**

| Layer | Mitigation |
|-------|------------|
| Hardware Wallet | Device displays actual destination - user sees mismatch |
| Time Delay | Even if signed, 1-week delay allows detection |
| Monitoring | Watcher alerts user of spend to unknown address |
| Verification | WYSIWYS ensures user verifies on trusted device |

**User Action:** Cancel transaction via emergency device

### Scenario 2: Phishing Attack

**Attack Vector:**
1. Attacker sends fake "security alert" email
2. Links to malicious app/website
3. User enters seed phrase

**Mitigations:**

| Mitigation | Explanation |
|------------|-------------|
| Seed in hardware | User never types seed phrase in app |
| No backup export | App cannot export seeds or keys |
| Education | Clear warnings never to share seed |

**User Action:** Ignore phishing, app never asks for seed

### Scenario 3: Man-in-the-Middle Attack

**Attack Vector:**
1. Attacker intercepts watcher communication
2. Suppresses alerts
3. User unaware of unauthorized spend

**Mitigations:**

| Mitigation | Explanation |
|------------|-------------|
| TLS pinning | Certificate validation prevents MITM |
| Multiple channels | Email/SMS backup notifications |
| Self-hosted option | User runs own watcher |
| Time delay | User can manually check blockchain |

**User Action:** Periodically verify vault on block explorer

### Scenario 4: Physical Device Theft (Phone)

**Attack Vector:**
1. Thief steals phone
2. Attempts to access app
3. Tries to spend funds

**Mitigations:**

| Mitigation | Explanation |
|------------|-------------|
| App lock | PIN/biometric required |
| No keys on phone | Signing requires hardware wallet |
| Time delay | User has time to cancel |
| Emergency recovery | Use emergency device to sweep funds |

**User Action:** Use emergency device to recover to new vault

### Scenario 5: Physical Device Theft (Hardware Wallet)

**Attack Vector:**
1. Thief steals hardware wallet
2. Doesn't have PIN
3. Cannot access funds

**Mitigations:**

| Mitigation | Explanation |
|------------|-------------|
| Device PIN | Wallet requires PIN |
| Wipe after attempts | Device wipes after failed PINs |
| Emergency device | Second device can recover |

**User Action:** Use emergency device to sweep to new vault

### Scenario 6: Malicious App Update

**Attack Vector:**
1. Developer compromised
2. Malicious update pushed
3. Update steals or redirects funds

**Mitigations:**

| Mitigation | Explanation |
|------------|-------------|
| Open source | Code auditable by anyone |
| Reproducible builds | Users can verify builds match source |
| Hardware signing | Keys never touch app |
| Time delay | Allows detection of malicious behavior |

**User Action:** Verify builds, wait for community verification

---

## Key Management

### What the App Knows

| Data | Storage | Risk Level |
|------|---------|------------|
| Vault addresses | Local + Blockchain | Low (public) |
| Vault descriptors | Local + Blockchain | Low (watch-only) |
| xpub | Local (encrypted) | Medium |
| Device fingerprints | Local | Low |

### What the App NEVER Knows

| Data | Location | Protected By |
|------|----------|--------------|
| Seed phrase | Hardware wallet only | Secure element |
| Private keys | Hardware wallet only | Secure element |
| Signing material | Hardware wallet only | Secure element |

### Key Derivation Paths

```
m/86'/0'/0'/0/*  - Vault receive addresses (Taproot BIP86)
m/86'/0'/0'/1/*  - Vault change addresses (unused - sweep-only)

Primary device: Controls delayed spending path
Emergency device: Controls key-path (immediate recovery)
```

---

## Secure Storage

### Local Storage (Flutter)

```dart
// lib/data/local/secure_storage.dart

class SecureStorageService {
  final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Use Android Keystore
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // Use iOS Keychain
    ),
  );
  
  // Store sensitive but non-key data
  Future<void> storeXpub(String vaultId, String xpub) async {
    await _storage.write(key: 'xpub_$vaultId', value: xpub);
  }
  
  // Never store: seeds, private keys, or signing material
}
```

### Data Classification

| Classification | Examples | Storage |
|---------------|----------|---------|
| Public | Addresses, txids | Plain storage |
| Sensitive | xpubs, fingerprints | Encrypted storage |
| Critical | Seeds, private keys | NEVER stored in app |

---

## Network Security

### TLS Configuration

```dart
// Enforce TLS 1.2+, certificate pinning
class SecureHttpClient {
  static Dio create() {
    return Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            // Validate certificate against pinned public key
            return validateCertPin(cert, expectedPins[host]);
          };
          return client;
        },
      );
  }
}
```

### Certificate Pinning

Pin certificates for:
- Watcher service endpoints
- Electrum servers (if using directly)
- Firebase services

---

## Code Security

### Rust Core Safety

```rust
// Defensive coding practices

// 1. Validate all inputs
fn create_vault(request: VaultCreationRequest) -> Result<Vault, CoreError> {
    // Validate xpub format
    validate_xpub(&request.primary_xpub, request.network)?;
    
    // Validate template parameters
    if request.template.delay_blocks() < MIN_DELAY_BLOCKS {
        return Err(CoreError::PolicyViolation(
            "Delay too short".into()
        ));
    }
    
    // ... rest of implementation
}

// 2. Never expose raw key material
pub struct PrivateKey {
    inner: secp256k1::SecretKey,
}

impl PrivateKey {
    // No method to export raw bytes
    // Only method is sign()
    pub fn sign(&self, message: &[u8]) -> Signature {
        // ...
    }
}

// 3. Zeroize sensitive data
use zeroize::Zeroize;

struct SensitiveData {
    data: Vec<u8>,
}

impl Drop for SensitiveData {
    fn drop(&mut self) {
        self.data.zeroize();
    }
}
```

### Memory Safety

- Rust prevents buffer overflows
- All FFI boundaries validate inputs
- Strings properly freed after FFI calls

---

## Audit Checklist

### Pre-Release Audit Items

- [ ] Key derivation matches BIP86 specification
- [ ] Taproot addresses generated correctly
- [ ] CSV timelocks enforced in scripts
- [ ] PSBT construction follows BIP174/370
- [ ] No key material logged
- [ ] FFI memory management correct
- [ ] TLS properly configured
- [ ] Local storage properly encrypted
- [ ] Error messages don't leak sensitive data
- [ ] Recovery process is deterministic

### Ongoing Security Practices

- [ ] Dependency updates reviewed
- [ ] Security advisories monitored
- [ ] Penetration testing (quarterly)
- [ ] Bug bounty program active
- [ ] Incident response plan documented

---

## User Security Guidance

### DO

✅ Keep seed phrase in multiple secure locations
✅ Verify addresses on hardware wallet before funding
✅ Test recovery process with small amounts first
✅ Enable push notifications for alerts
✅ Keep hardware wallet firmware updated
✅ Use emergency device as true cold storage

### DON'T

❌ Never enter seed phrase in any app or website
❌ Never share seed phrase with anyone
❌ Never ignore security alerts
❌ Never skip address verification
❌ Never use untrusted hardware wallets
❌ Never disable time delays

---

## Incident Response

### If User Suspects Compromise

1. **Immediately:** Use emergency device to sweep to new vault
2. **Within 1 hour:** Review all recent activity
3. **Within 24 hours:** Generate new vault with new addresses
4. **Document:** Report incident for analysis

### If Vulnerability Discovered

1. **Disclosure:** Responsible disclosure to security@freedomwallet.app
2. **Assessment:** Team evaluates severity within 24 hours
3. **Mitigation:** Hotfix deployed for critical issues
4. **Communication:** User notification if affected
5. **Reward:** Bug bounty payment if applicable
