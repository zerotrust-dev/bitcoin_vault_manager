# Testing Strategy

## Overview

Freedom Wallet requires comprehensive testing across all layers due to the financial nature of the application. A bug could result in fund loss, so testing is critical.

---

## Testing Pyramid

```
                    ┌─────────────┐
                    │   Manual    │  
                    │   Testing   │  ← User acceptance, exploratory
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │     E2E     │  ← Full user journeys
                    │    Tests    │  
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │     Integration Tests    │  ← Component interactions
              │                          │  
              └────────────┬─────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │           Unit Tests               │  ← Individual functions
         │                                    │  
         └────────────────────────────────────┘

Target Coverage:
- Unit Tests: 80%+
- Integration Tests: Key flows covered
- E2E Tests: Critical user journeys
```

---

## Unit Testing

### Rust Core Tests

```rust
// src/taproot/address_tests.rs

#[cfg(test)]
mod tests {
    use super::*;
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADDRESS GENERATION
    // ═══════════════════════════════════════════════════════════════
    
    #[test]
    fn test_generate_taproot_address_testnet() {
        let xpub = "tpub..."; // Test vector xpub
        
        let result = generate_taproot_address(
            xpub,
            None,
            &VaultTemplate::savings(),
            0,
            Network::Testnet,
        ).unwrap();
        
        assert!(result.address.starts_with("tb1p"));
        assert_eq!(result.address.len(), 62);
    }
    
    #[test]
    fn test_generate_taproot_address_mainnet() {
        let xpub = "xpub..."; // Test vector xpub
        
        let result = generate_taproot_address(
            xpub,
            None,
            &VaultTemplate::savings(),
            0,
            Network::Mainnet,
        ).unwrap();
        
        assert!(result.address.starts_with("bc1p"));
    }
    
    #[test]
    fn test_address_derivation_deterministic() {
        let xpub = "tpub...";
        
        let result1 = generate_taproot_address(
            xpub, None, &VaultTemplate::savings(), 0, Network::Testnet,
        ).unwrap();
        
        let result2 = generate_taproot_address(
            xpub, None, &VaultTemplate::savings(), 0, Network::Testnet,
        ).unwrap();
        
        assert_eq!(result1.address, result2.address);
        assert_eq!(result1.descriptor, result2.descriptor);
    }
    
    #[test]
    fn test_different_indices_different_addresses() {
        let xpub = "tpub...";
        
        let addr0 = generate_taproot_address(
            xpub, None, &VaultTemplate::savings(), 0, Network::Testnet,
        ).unwrap();
        
        let addr1 = generate_taproot_address(
            xpub, None, &VaultTemplate::savings(), 1, Network::Testnet,
        ).unwrap();
        
        assert_ne!(addr0.address, addr1.address);
    }
    
    #[test]
    fn test_invalid_xpub_returns_error() {
        let result = generate_taproot_address(
            "invalid_xpub",
            None,
            &VaultTemplate::savings(),
            0,
            Network::Testnet,
        );
        
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), CoreError::InvalidXpub(_)));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    METADATA ENCODING
    // ═══════════════════════════════════════════════════════════════
    
    #[test]
    fn test_metadata_roundtrip() {
        let original = VaultMetadata {
            version: 1,
            template_id: "savings_v1".to_string(),
            delay_blocks: 1008,
            destination_indices: vec![0, 1],
            recovery_type: RecoveryType::EmergencyKey,
            created_at_block: 830000,
            vault_index: 42,
        };
        
        let encoded = original.to_bytes();
        let decoded = VaultMetadata::from_bytes(&encoded).unwrap();
        
        assert_eq!(original.version, decoded.version);
        assert_eq!(original.template_id, decoded.template_id);
        assert_eq!(original.delay_blocks, decoded.delay_blocks);
        assert_eq!(original.destination_indices, decoded.destination_indices);
        assert_eq!(original.vault_index, decoded.vault_index);
    }
    
    #[test]
    fn test_metadata_size_within_limits() {
        let metadata = VaultMetadata {
            version: 1,
            template_id: "savings_v1".to_string(),
            delay_blocks: 1008,
            destination_indices: vec![0; 10],
            recovery_type: RecoveryType::EmergencyKey,
            created_at_block: 830000,
            vault_index: 0,
        };
        
        let encoded = metadata.to_bytes();
        assert!(encoded.len() < 520); // Script size limit
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    PSBT CONSTRUCTION
    // ═══════════════════════════════════════════════════════════════
    
    #[test]
    fn test_build_delayed_spend_psbt() {
        let intent = SpendIntent {
            vault_id: "vault_123".to_string(),
            destination: "tb1q...".to_string(),
            amount_sats: Some(50000),
            fee_rate: 5.0,
            path_type: SpendPath::Delayed,
        };
        
        let utxos = vec![
            Utxo {
                txid: "abc123...".to_string(),
                vout: 0,
                value_sats: 100000,
                script_pubkey: "5120...".to_string(),
                confirmations: 6,
                block_height: Some(830000),
            },
        ];
        
        let result = build_delayed_spend_psbt(intent, &utxos).unwrap();
        
        assert!(!result.psbt_base64.is_empty());
        assert!(result.is_valid);
        assert_eq!(result.summary.amount_sats, 50000);
    }
    
    #[test]
    fn test_psbt_insufficient_funds() {
        let intent = SpendIntent {
            vault_id: "vault_123".to_string(),
            destination: "tb1q...".to_string(),
            amount_sats: Some(200000), // More than available
            fee_rate: 5.0,
            path_type: SpendPath::Delayed,
        };
        
        let utxos = vec![
            Utxo {
                txid: "abc123...".to_string(),
                vout: 0,
                value_sats: 100000,
                // ...
            },
        ];
        
        let result = build_delayed_spend_psbt(intent, &utxos);
        
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), CoreError::InsufficientFunds { .. }));
    }
}
```

### Flutter Unit Tests

```dart
// test/domain/models/vault_test.dart

void main() {
  group('Vault', () {
    test('creates with correct defaults', () {
      final vault = Vault(
        id: 'test_vault',
        name: 'Test Vault',
        template: const VaultTemplate.savings(),
        balanceSats: 100000,
        address: 'tb1p...',
        descriptor: 'tr(...)',
        status: VaultStatus.active,
        primaryDevice: testDevice,
        network: Network.testnet,
        createdAt: DateTime.now(),
      );
      
      expect(vault.id, 'test_vault');
      expect(vault.template.delayBlocks, 1008);
      expect(vault.status, VaultStatus.active);
    });
    
    test('serializes to JSON and back', () {
      final original = createTestVault();
      final json = original.toJson();
      final restored = Vault.fromJson(json);
      
      expect(restored, equals(original));
    });
  });
  
  group('VaultTemplate', () {
    test('savings has 1008 block delay', () {
      const template = VaultTemplate.savings();
      expect(template.delayBlocks, 1008);
    });
    
    test('spending has 144 block delay', () {
      const template = VaultTemplate.spending();
      expect(template.delayBlocks, 144);
    });
    
    test('custom allows arbitrary delay', () {
      const template = VaultTemplate.custom(
        delayBlocks: 500,
        recoveryType: RecoveryType.emergencyKey,
      );
      expect(template.delayBlocks, 500);
    });
  });
}

// test/presentation/providers/vault_provider_test.dart

void main() {
  late ProviderContainer container;
  late MockVaultService mockVaultService;
  
  setUp(() {
    mockVaultService = MockVaultService();
    container = ProviderContainer(
      overrides: [
        vaultServiceProvider.overrideWithValue(mockVaultService),
      ],
    );
  });
  
  tearDown(() {
    container.dispose();
  });
  
  test('creates vault and updates state', () async {
    final request = VaultCreationRequest(
      name: 'Test Vault',
      template: const VaultTemplate.savings(),
      primaryDevice: testDevice,
      network: Network.testnet,
    );
    
    when(mockVaultService.createVault(request))
        .thenAnswer((_) async => testVault);
    
    final notifier = container.read(vaultNotifierProvider.notifier);
    await notifier.createVault(request);
    
    final state = container.read(vaultNotifierProvider);
    expect(state.value, contains(testVault));
  });
}
```

---

## Integration Tests

### Rust + Flutter Integration

```dart
// integration_test/rust_ffi_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  late RustFfi ffi;
  
  setUpAll(() {
    ffi = RustFfi.instance;
    ffi.initialize(Network.testnet);
  });
  
  testWidgets('full vault creation flow', (tester) async {
    // 1. Generate address
    final addressResult = await ffi.generateVaultAddress(
      primaryXpub: testXpub,
      template: const VaultTemplate.savings(),
      vaultIndex: 0,
      network: Network.testnet,
    );
    
    expect(addressResult.address, startsWith('tb1p'));
    
    // 2. Decode metadata (simulating recovery)
    final metadata = await ffi.decodeMetadata(addressResult.metadataScript);
    
    expect(metadata.delayBlocks, 1008);
    expect(metadata.vaultIndex, 0);
    
    // 3. Build PSBT
    final psbt = await ffi.buildDelayedSpendPsbt(
      intent: SpendIntent(
        vaultId: 'test',
        destination: 'tb1q...',
        amountSats: 50000,
        feeRate: 5.0,
        pathType: SpendPath.delayed,
      ),
      utxos: [testUtxo],
    );
    
    expect(psbt.isValid, isTrue);
  });
}
```

### Watcher Integration

```python
# tests/test_watcher_integration.py

import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_vault_registration_and_monitoring():
    async with AsyncClient(app=app, base_url="http://test") as client:
        # 1. Register vault
        response = await client.post("/vaults/register", json={
            "vault_id": "test_vault",
            "descriptor": "tr(tpub...)",
            "addresses": ["tb1p..."],
            "device_token": "test_token",
            "user_id": "test_user",
        })
        
        assert response.status_code == 200
        assert response.json()["success"] is True
        
        # 2. Check status
        response = await client.get("/vaults/test_vault")
        assert response.status_code == 200
        assert response.json()["vault_id"] == "test_vault"
        
        # 3. Get UTXOs
        response = await client.get("/vaults/test_vault/utxos")
        assert response.status_code == 200
        assert "utxos" in response.json()
        
        # 4. Unregister
        response = await client.delete("/vaults/test_vault")
        assert response.status_code == 200

@pytest.mark.asyncio
async def test_fee_estimation():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/fees")
        
        assert response.status_code == 200
        data = response.json()
        assert "low" in data
        assert "medium" in data
        assert "high" in data
        assert data["low"]["sat_per_vb"] < data["high"]["sat_per_vb"]
```

---

## End-to-End Tests

### Happy Path: Create and Fund Vault

```dart
// integration_test/e2e_create_vault_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('user creates and funds vault', (tester) async {
    await tester.pumpWidget(const FreedomWalletApp());
    await tester.pumpAndSettle();
    
    // 1. Welcome screen - tap "Set up my vault"
    expect(find.text('Set up my vault'), findsOneWidget);
    await tester.tap(find.text('Set up my vault'));
    await tester.pumpAndSettle();
    
    // 2. Pair device screen - simulate device connection
    expect(find.text('Connect your hardware wallet'), findsOneWidget);
    
    // Mock device discovered
    await simulateDeviceDiscovery(tester);
    await tester.pumpAndSettle();
    
    expect(find.text('Trezor Model T'), findsOneWidget);
    expect(find.text('Taproot: Supported'), findsOneWidget);
    
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    
    // 3. Template selection
    expect(find.text('Savings Vault'), findsOneWidget);
    await tester.tap(find.text('Savings Vault'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Continue with Savings Vault'));
    await tester.pumpAndSettle();
    
    // 4. Publish vault
    expect(find.text('Fund your vault'), findsOneWidget);
    expect(find.textContaining('tb1p'), findsOneWidget); // Testnet address
    
    // Verify QR code present
    expect(find.byType(QrImageView), findsOneWidget);
    
    // Mock funding
    await simulateVaultFunding(tester);
    await tester.pumpAndSettle();
    
    // 5. Dashboard
    expect(find.text('Your Vaults'), findsOneWidget);
    expect(find.text('Savings Vault'), findsOneWidget);
    expect(find.text('Secure'), findsOneWidget);
  });
}
```

### Happy Path: Recovery

```dart
testWidgets('user recovers vault on new device', (tester) async {
  await tester.pumpWidget(const FreedomWalletApp());
  await tester.pumpAndSettle();
  
  // 1. Welcome - tap recovery
  await tester.tap(find.text('I already have a vault'));
  await tester.pumpAndSettle();
  
  // 2. Connect wallet
  await simulateDeviceDiscovery(tester);
  await tester.pumpAndSettle();
  
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  
  // 3. Scanning - wait for completion
  expect(find.text('Scanning the blockchain'), findsOneWidget);
  
  await simulateBlockchainScan(tester, vaultsFound: 2);
  await tester.pumpAndSettle();
  
  // 4. Results
  expect(find.text('Found 2 vaults'), findsOneWidget);
  expect(find.text('Savings Vault'), findsOneWidget);
  
  await tester.tap(find.text('Confirm Recovery'));
  await tester.pumpAndSettle();
  
  // 5. Dashboard with recovered vaults
  expect(find.text('Your Vaults'), findsOneWidget);
  expect(find.byType(VaultCard), findsNWidgets(2));
});
```

---

## Test Data & Fixtures

### Test Vectors

```dart
// test/fixtures/test_vectors.dart

const testXpub = 'tpubDCdDtzAG7LqoFJunyLZ9DDPyrE6cEvDT1yX1dF3wNJJvuV7RkjpfBhSHm'
    'F3FTQg4aA9m8JE3R6cWvYKx8bzVDXAqxjUQT1ZwPUPxGz1R5P';

const testDevice = DeviceInfo(
  name: 'Test Trezor',
  type: DeviceType.trezor,
  fingerprint: '73c5da0a',
  xpub: testXpub,
  firmwareVersion: '2.6.0',
  role: DeviceRole.daily,
  connectionMethod: ConnectionMethod.usb,
  supportsTaproot: true,
  pairedAt: DateTime(2025, 1, 1),
);

const testUtxo = Utxo(
  txid: 'abc123def456789012345678901234567890123456789012345678901234abcd',
  vout: 0,
  valueSats: 100000,
  scriptPubkey: '5120...',
  confirmations: 6,
  blockHeight: 830000,
);

Vault createTestVault({
  String? id,
  int? balanceSats,
  VaultStatus? status,
}) {
  return Vault(
    id: id ?? 'vault_${DateTime.now().millisecondsSinceEpoch}',
    name: 'Test Vault',
    template: const VaultTemplate.savings(),
    balanceSats: balanceSats ?? 100000,
    address: 'tb1ptest...',
    descriptor: 'tr(tpub...)',
    status: status ?? VaultStatus.active,
    primaryDevice: testDevice,
    network: Network.testnet,
    createdAt: DateTime.now(),
  );
}
```

---

## Test Environments

### Local Development
- Network: Testnet/Regtest
- Watcher: Mock or local instance
- Hardware: Simulator or real testnet device

### CI/CD Pipeline
- Network: Regtest (isolated)
- Watcher: Mocked
- Hardware: Mocked

### Staging
- Network: Testnet
- Watcher: Staging instance
- Hardware: Real devices

### Production
- Network: Mainnet
- Watcher: Production cluster
- Hardware: Real devices

---

## Coverage Requirements

| Component | Target Coverage | Critical Paths |
|-----------|-----------------|----------------|
| Rust Core | 85% | Address generation, PSBT, recovery |
| Flutter Domain | 80% | All models, services |
| Flutter UI | 70% | All screens render |
| Watcher | 80% | Registration, monitoring |

---

## Continuous Integration

```yaml
# .github/workflows/test.yml

name: Tests

on: [push, pull_request]

jobs:
  rust-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo test --all-features
      - run: cargo clippy -- -D warnings
  
  flutter-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - run: flutter analyze
  
  integration-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter drive --driver=test_driver/integration_test.dart
                          --target=integration_test/app_test.dart
```
