# Data Models Specification

## Overview

This document defines all data models used across the Freedom Wallet system. Models are defined in both Rust (for the core library) and Dart (for the Flutter app), with JSON as the interchange format.

---

## Core Domain Models

### Vault

The central entity representing a Bitcoin vault.

**Dart Model:**

```dart
// lib/domain/models/vault.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault.freezed.dart';
part 'vault.g.dart';

@freezed
class Vault with _$Vault {
  const factory Vault({
    /// Unique identifier (derived from address)
    required String id,
    
    /// Human-readable name
    required String name,
    
    /// Vault template configuration
    required VaultTemplate template,
    
    /// Current balance in satoshis
    required int balanceSats,
    
    /// Bitcoin address (bc1p...)
    required String address,
    
    /// Output descriptor
    required String descriptor,
    
    /// Vault status
    required VaultStatus status,
    
    /// Primary device info
    required DeviceInfo primaryDevice,
    
    /// Emergency device info (optional)
    DeviceInfo? emergencyDevice,
    
    /// Bitcoin network
    required Network network,
    
    /// Creation timestamp
    required DateTime createdAt,
    
    /// Last activity timestamp
    DateTime? lastActivityAt,
    
    /// Pending transactions
    @Default([]) List<PendingTransaction> pendingTransactions,
  }) = _Vault;
  
  factory Vault.fromJson(Map<String, dynamic> json) => _$VaultFromJson(json);
}

@freezed
class VaultTemplate with _$VaultTemplate {
  const factory VaultTemplate.savings({
    @Default(1008) int delayBlocks,
  }) = SavingsTemplate;
  
  const factory VaultTemplate.spending({
    @Default(144) int delayBlocks,
  }) = SpendingTemplate;
  
  const factory VaultTemplate.custom({
    required int delayBlocks,
    required RecoveryType recoveryType,
  }) = CustomTemplate;
  
  factory VaultTemplate.fromJson(Map<String, dynamic> json) => 
      _$VaultTemplateFromJson(json);
}

enum VaultStatus {
  /// Vault created, awaiting funding
  awaitingFunding,
  
  /// Vault is funded and active
  active,
  
  /// Spending transaction in progress
  pendingSpend,
  
  /// Vault has been swept
  empty,
  
  /// Error state
  error,
}

enum RecoveryType {
  /// Use emergency device for key-path recovery
  emergencyKey,
  
  /// Wait for timelock to expire
  timelockOnly,
  
  /// Multi-signature recovery
  multiSig,
}

enum Network {
  mainnet,
  testnet,
  signet,
  regtest,
}
```

**Rust Model:**

```rust
// src/vault/config.rs

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vault {
    pub id: String,
    pub name: String,
    pub template: VaultTemplate,
    pub balance_sats: u64,
    pub address: String,
    pub descriptor: String,
    pub status: VaultStatus,
    pub primary_device: DeviceInfo,
    pub emergency_device: Option<DeviceInfo>,
    pub network: Network,
    pub created_at: u64,
    pub last_activity_at: Option<u64>,
    pub pending_transactions: Vec<PendingTransaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum VaultTemplate {
    #[serde(rename = "savings")]
    Savings { delay_blocks: u32 },
    
    #[serde(rename = "spending")]
    Spending { delay_blocks: u32 },
    
    #[serde(rename = "custom")]
    Custom {
        delay_blocks: u32,
        recovery_type: RecoveryType,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultStatus {
    AwaitingFunding,
    Active,
    PendingSpend,
    Empty,
    Error,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryType {
    EmergencyKey,
    TimelockOnly,
    MultiSig,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Network {
    Mainnet,
    Testnet,
    Signet,
    Regtest,
}
```

---

### Device

Hardware wallet device information.

**Dart Model:**

```dart
// lib/domain/models/device.dart

@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    /// Device name (e.g., "Trezor Model T")
    required String name,
    
    /// Device type/brand
    required DeviceType type,
    
    /// BIP32 master fingerprint
    required String fingerprint,
    
    /// Extended public key
    required String xpub,
    
    /// Firmware version
    required String firmwareVersion,
    
    /// Device role in vault
    required DeviceRole role,
    
    /// Connection method
    required ConnectionMethod connectionMethod,
    
    /// Whether device supports Taproot
    required bool supportsTaproot,
    
    /// Pairing timestamp
    required DateTime pairedAt,
  }) = _DeviceInfo;
  
  factory DeviceInfo.fromJson(Map<String, dynamic> json) => 
      _$DeviceInfoFromJson(json);
}

enum DeviceType {
  trezor,
  ledger,
  bitbox02,
  coldcard,
  generic,
}

enum DeviceRole {
  /// Primary device for daily operations
  daily,
  
  /// Emergency device for recovery
  emergency,
}

enum ConnectionMethod {
  usb,
  bluetooth,
  qrCode,
}
```

**Rust Model:**

```rust
// src/vault/device.rs

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub name: String,
    pub device_type: DeviceType,
    pub fingerprint: String,
    pub xpub: String,
    pub firmware_version: String,
    pub role: DeviceRole,
    pub connection_method: ConnectionMethod,
    pub supports_taproot: bool,
    pub paired_at: u64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceType {
    Trezor,
    Ledger,
    Bitbox02,
    Coldcard,
    Generic,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceRole {
    Daily,
    Emergency,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConnectionMethod {
    Usb,
    Bluetooth,
    QrCode,
}
```

---

### Transaction

Transaction-related models.

**Dart Model:**

```dart
// lib/domain/models/transaction.dart

@freezed
class SpendIntent with _$SpendIntent {
  const factory SpendIntent({
    /// Source vault ID
    required String vaultId,
    
    /// Destination address
    required String destination,
    
    /// Amount in satoshis (null = sweep all)
    int? amountSats,
    
    /// Fee rate in sat/vB
    required double feeRate,
    
    /// Spend path type
    required SpendPath pathType,
  }) = _SpendIntent;
  
  factory SpendIntent.fromJson(Map<String, dynamic> json) => 
      _$SpendIntentFromJson(json);
}

enum SpendPath {
  /// Script path with CSV delay
  delayed,
  
  /// Key path immediate (emergency)
  emergency,
}

@freezed
class PsbtData with _$PsbtData {
  const factory PsbtData({
    /// Base64-encoded PSBT
    required String psbtBase64,
    
    /// Human-readable summary
    required TransactionSummary summary,
    
    /// Whether PSBT is valid
    required bool isValid,
    
    /// Validation warnings
    @Default([]) List<String> warnings,
  }) = _PsbtData;
  
  factory PsbtData.fromJson(Map<String, dynamic> json) => 
      _$PsbtDataFromJson(json);
}

@freezed
class TransactionSummary with _$TransactionSummary {
  const factory TransactionSummary({
    /// Source vault name
    required String fromVault,
    
    /// Destination address
    required String toAddress,
    
    /// Amount in satoshis
    required int amountSats,
    
    /// Fee in satoshis
    required int feeSats,
    
    /// Spend path type
    required SpendPath pathType,
    
    /// Delay in blocks (for delayed spends)
    int? delayBlocks,
    
    /// Estimated completion time
    DateTime? estimatedCompletion,
  }) = _TransactionSummary;
  
  factory TransactionSummary.fromJson(Map<String, dynamic> json) => 
      _$TransactionSummaryFromJson(json);
}

@freezed
class PendingTransaction with _$PendingTransaction {
  const factory PendingTransaction({
    /// Transaction ID
    required String txid,
    
    /// Amount in satoshis
    required int amountSats,
    
    /// Destination address
    required String destination,
    
    /// Block height when transaction was broadcast
    required int broadcastHeight,
    
    /// Block height when funds can be spent
    required int unlockHeight,
    
    /// Current status
    required PendingStatus status,
    
    /// Whether this can be canceled
    required bool canCancel,
    
    /// Broadcast timestamp
    required DateTime broadcastAt,
  }) = _PendingTransaction;
  
  factory PendingTransaction.fromJson(Map<String, dynamic> json) => 
      _$PendingTransactionFromJson(json);
}

enum PendingStatus {
  /// In mempool, waiting for confirmation
  mempool,
  
  /// Confirmed, in delay period
  delayActive,
  
  /// Delay complete, can be finalized
  ready,
  
  /// Transaction was canceled
  canceled,
  
  /// Transaction completed
  completed,
}

@freezed
class BroadcastResult with _$BroadcastResult {
  const factory BroadcastResult({
    required String txid,
    required bool success,
    String? error,
  }) = _BroadcastResult;
  
  factory BroadcastResult.fromJson(Map<String, dynamic> json) => 
      _$BroadcastResultFromJson(json);
}
```

---

### UTXO

Unspent transaction output information.

**Dart Model:**

```dart
// lib/domain/models/utxo.dart

@freezed
class Utxo with _$Utxo {
  const factory Utxo({
    /// Transaction ID
    required String txid,
    
    /// Output index
    required int vout,
    
    /// Amount in satoshis
    required int valueSats,
    
    /// Script pubkey (hex)
    required String scriptPubkey,
    
    /// Confirmation count
    required int confirmations,
    
    /// Block height (null if unconfirmed)
    int? blockHeight,
  }) = _Utxo;
  
  factory Utxo.fromJson(Map<String, dynamic> json) => _$UtxoFromJson(json);
}
```

---

### Alert

Vault activity alerts.

**Dart Model:**

```dart
// lib/domain/models/alert.dart

@freezed
class Alert with _$Alert {
  const factory Alert({
    /// Unique alert ID
    required String id,
    
    /// Alert type
    required AlertType type,
    
    /// Related vault ID
    required String vaultId,
    
    /// Alert title
    required String title,
    
    /// Alert message
    required String message,
    
    /// Severity level
    required AlertSeverity severity,
    
    /// Alert timestamp
    required DateTime timestamp,
    
    /// Whether alert has been acknowledged
    required bool acknowledged,
    
    /// Related transaction (if applicable)
    PendingTransaction? transaction,
    
    /// Available actions
    @Default([]) List<AlertAction> actions,
  }) = _Alert;
  
  factory Alert.fromJson(Map<String, dynamic> json) => _$AlertFromJson(json);
}

enum AlertType {
  /// Unauthorized spend attempt detected
  spendDetected,
  
  /// Timelock is about to mature
  timelockMaturing,
  
  /// Emergency recovery recommended
  recoveryRecommended,
  
  /// Transaction confirmed
  transactionConfirmed,
  
  /// Vault funded
  vaultFunded,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

@freezed
class AlertAction with _$AlertAction {
  const factory AlertAction({
    /// Action identifier
    required String id,
    
    /// Display label
    required String label,
    
    /// Action type
    required AlertActionType type,
  }) = _AlertAction;
  
  factory AlertAction.fromJson(Map<String, dynamic> json) => 
      _$AlertActionFromJson(json);
}

enum AlertActionType {
  /// Dismiss the alert
  dismiss,
  
  /// Cancel the transaction
  cancelTransaction,
  
  /// View transaction details
  viewDetails,
  
  /// Initiate emergency recovery
  emergencyRecovery,
}
```

---

### Vault Metadata (Blockchain-Encoded)

Metadata stored in Taproot script leaf for recovery.

**Dart Model:**

```dart
// lib/domain/models/vault_metadata.dart

@freezed
class VaultMetadata with _$VaultMetadata {
  const factory VaultMetadata({
    /// Schema version
    required int version,
    
    /// Template identifier
    required String templateId,
    
    /// Delay in blocks
    required int delayBlocks,
    
    /// Destination indices
    required List<int> destinationIndices,
    
    /// Recovery type
    required RecoveryType recoveryType,
    
    /// Creation block height
    required int createdAtBlock,
    
    /// Vault derivation index
    required int vaultIndex,
  }) = _VaultMetadata;
  
  factory VaultMetadata.fromJson(Map<String, dynamic> json) => 
      _$VaultMetadataFromJson(json);
}
```

**Rust Model:**

```rust
// src/taproot/metadata.rs

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultMetadata {
    pub version: u8,
    pub template_id: String,
    pub delay_blocks: u32,
    pub destination_indices: Vec<u8>,
    pub recovery_type: RecoveryType,
    pub created_at_block: u32,
    pub vault_index: u32,
}

impl VaultMetadata {
    /// Encode metadata to bytes for script leaf
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(64);
        
        // Version (1 byte)
        bytes.push(self.version);
        
        // Template ID length + bytes
        let template_bytes = self.template_id.as_bytes();
        bytes.push(template_bytes.len() as u8);
        bytes.extend_from_slice(template_bytes);
        
        // Delay blocks (4 bytes, little-endian)
        bytes.extend_from_slice(&self.delay_blocks.to_le_bytes());
        
        // Destination indices count + bytes
        bytes.push(self.destination_indices.len() as u8);
        bytes.extend_from_slice(&self.destination_indices);
        
        // Recovery type (1 byte)
        bytes.push(match self.recovery_type {
            RecoveryType::EmergencyKey => 0,
            RecoveryType::TimelockOnly => 1,
            RecoveryType::MultiSig => 2,
        });
        
        // Created at block (4 bytes)
        bytes.extend_from_slice(&self.created_at_block.to_le_bytes());
        
        // Vault index (4 bytes)
        bytes.extend_from_slice(&self.vault_index.to_le_bytes());
        
        bytes
    }
    
    /// Decode metadata from bytes
    pub fn from_bytes(data: &[u8]) -> Result<Self, CoreError> {
        // ... decoding logic (reverse of encoding)
    }
}
```

---

### Fee Estimate

Network fee estimation.

**Dart Model:**

```dart
// lib/domain/models/fee_estimate.dart

@freezed
class FeeEstimate with _$FeeEstimate {
  const factory FeeEstimate({
    /// Low priority (next ~6 blocks)
    required FeeLevel low,
    
    /// Medium priority (next ~3 blocks)
    required FeeLevel medium,
    
    /// High priority (next block)
    required FeeLevel high,
    
    /// Timestamp of estimate
    required DateTime timestamp,
  }) = _FeeEstimate;
  
  factory FeeEstimate.fromJson(Map<String, dynamic> json) => 
      _$FeeEstimateFromJson(json);
}

@freezed
class FeeLevel with _$FeeLevel {
  const factory FeeLevel({
    /// Fee rate in sat/vB
    required double satPerVb,
    
    /// Estimated confirmation time in minutes
    required int estimatedMinutes,
    
    /// Target block count
    required int targetBlocks,
  }) = _FeeLevel;
  
  factory FeeLevel.fromJson(Map<String, dynamic> json) => 
      _$FeeLevelFromJson(json);
}
```

---

### Address Info

Address information with validation.

**Dart Model:**

```dart
// lib/domain/models/address_info.dart

@freezed
class AddressInfo with _$AddressInfo {
  const factory AddressInfo({
    /// The address string
    required String address,
    
    /// Address type
    required AddressType type,
    
    /// Network
    required Network network,
    
    /// Whether address is valid
    required bool isValid,
    
    /// Human-readable label (if known)
    String? label,
    
    /// Whether this is a vault address
    @Default(false) bool isVaultAddress,
    
    /// Derivation index (if vault address)
    int? derivationIndex,
  }) = _AddressInfo;
  
  factory AddressInfo.fromJson(Map<String, dynamic> json) => 
      _$AddressInfoFromJson(json);
}

enum AddressType {
  /// Taproot (bc1p...)
  p2tr,
  
  /// Native SegWit (bc1q...)
  p2wpkh,
  
  /// Wrapped SegWit (3...)
  p2shP2wpkh,
  
  /// Legacy (1...)
  p2pkh,
  
  /// Unknown
  unknown,
}
```

---

### Settings

Application settings.

**Dart Model:**

```dart
// lib/domain/models/settings.dart

@freezed
class Settings with _$Settings {
  const factory Settings({
    /// Bitcoin network
    required Network network,
    
    /// Electrum server URL
    required String electrumServer,
    
    /// Watcher service URL
    required String watcherUrl,
    
    /// App lock enabled
    required bool appLockEnabled,
    
    /// Biometric auth enabled
    required bool biometricEnabled,
    
    /// Push notifications enabled
    required bool pushNotificationsEnabled,
    
    /// Display currency (BTC, sats, fiat)
    required DisplayCurrency displayCurrency,
    
    /// Fiat currency for conversion
    required String fiatCurrency,
    
    /// Theme mode
    required ThemeMode themeMode,
  }) = _Settings;
  
  factory Settings.defaults() => const Settings(
    network: Network.mainnet,
    electrumServer: 'ssl://electrum.blockstream.info:50002',
    watcherUrl: 'https://watcher.freedomwallet.app',
    appLockEnabled: true,
    biometricEnabled: false,
    pushNotificationsEnabled: true,
    displayCurrency: DisplayCurrency.btc,
    fiatCurrency: 'USD',
    themeMode: ThemeMode.system,
  );
  
  factory Settings.fromJson(Map<String, dynamic> json) => 
      _$SettingsFromJson(json);
}

enum DisplayCurrency {
  btc,
  sats,
  fiat,
}

enum ThemeMode {
  light,
  dark,
  system,
}
```

---

### Request/Response Models

API request and response models.

**Dart Models:**

```dart
// lib/domain/models/requests.dart

@freezed
class VaultCreationRequest with _$VaultCreationRequest {
  const factory VaultCreationRequest({
    /// Vault name
    required String name,
    
    /// Template to use
    required VaultTemplate template,
    
    /// Primary device info
    required DeviceInfo primaryDevice,
    
    /// Emergency device info (optional)
    DeviceInfo? emergencyDevice,
    
    /// Network
    required Network network,
  }) = _VaultCreationRequest;
  
  factory VaultCreationRequest.fromJson(Map<String, dynamic> json) => 
      _$VaultCreationRequestFromJson(json);
}

@freezed
class RecoveryResult with _$RecoveryResult {
  const factory RecoveryResult({
    /// Whether recovery was successful
    required bool success,
    
    /// Recovered vaults
    required List<Vault> vaults,
    
    /// Addresses scanned
    required int addressesScanned,
    
    /// Time taken in milliseconds
    required int durationMs,
    
    /// Any errors encountered
    @Default([]) List<String> errors,
  }) = _RecoveryResult;
  
  factory RecoveryResult.fromJson(Map<String, dynamic> json) => 
      _$RecoveryResultFromJson(json);
}

@freezed
class HealthCheckResult with _$HealthCheckResult {
  const factory HealthCheckResult({
    required bool deviceConnected,
    required bool networkReachable,
    required bool watcherHealthy,
    required int currentBlockHeight,
    required DateTime timestamp,
  }) = _HealthCheckResult;
  
  factory HealthCheckResult.fromJson(Map<String, dynamic> json) => 
      _$HealthCheckResultFromJson(json);
}
```

---

## JSON Serialization

All models use `freezed` and `json_serializable` for type-safe JSON conversion:

```dart
// Generate with: dart run build_runner build
// This creates .freezed.dart and .g.dart files
```

The Rust core uses `serde` with identical field names (snake_case in Rust, converted to camelCase in Dart).

---

## Validation Rules

### Address Validation
- Mainnet P2TR: starts with `bc1p`, 62 characters
- Testnet P2TR: starts with `tb1p`, 62 characters
- Must pass checksum verification

### Amount Validation
- Must be positive
- Must not exceed available balance
- Minimum: dust limit (546 sats for P2TR)

### Fee Rate Validation
- Minimum: 1 sat/vB
- Maximum: 1000 sat/vB (configurable)
- Must be numeric

### XPub Validation
- Mainnet: starts with `xpub` or `zpub`
- Testnet: starts with `tpub` or `vpub`
- Must be valid Base58Check encoding
