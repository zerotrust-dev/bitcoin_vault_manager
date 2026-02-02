# User Flows Specification

## Overview

This document details the complete user journeys through Freedom Wallet, including happy paths, edge cases, and error handling. Each flow maps directly to screens and API calls.

---

## Flow 1: First-Time Setup

**Goal:** Ricky creates his first vault and funds it.

### Sequence Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Ricky  │     │   App   │     │  Rust   │     │ Hardware│     │Blockchain│
│         │     │         │     │  Core   │     │  Wallet │     │         │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │ Opens app     │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ "Set up vault"│               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │               │ Show pairing  │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ Connect USB   │               │               │               │
     │──────────────>│               │               │               │
     │               │  Get xpub     │               │               │
     │               │───────────────────────────────>               │
     │               │               │               │               │
     │               │<─── xpub + fingerprint ───────│               │
     │               │               │               │               │
     │ Sees device   │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ Select        │               │               │               │
     │ "Savings"     │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │               │  Generate     │               │               │
     │               │  address      │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── address +  │               │               │
     │               │    descriptor │               │               │
     │               │               │               │               │
     │               │  Display      │               │               │
     │               │  address      │               │               │
     │               │───────────────────────────────>               │
     │               │               │               │               │
     │ Verify on     │               │               │               │
     │ device        │               │               │               │
     │──────────────>│               │  User presses │               │
     │               │               │  confirm      │               │
     │               │<──────────────────────────────│               │
     │               │               │               │               │
     │ Send BTC from │               │               │               │
     │ exchange      │               │               │               │
     │─────────────────────────────────────────────────────────────>│
     │               │               │               │               │
     │               │  Register     │               │               │
     │               │  with watcher │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<─ confirmed ──────────────────│               │
     │               │               │               │               │
     │ "Vault ready!"│               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
```

### Detailed Steps

#### Step 1: Welcome Screen
- **Screen:** `WelcomeScreen`
- **User Action:** Taps "Set up my vault"
- **App Action:** Navigate to `/onboarding/pair-device`

#### Step 2: Pair Hardware Wallet
- **Screen:** `PairDeviceScreen`
- **State:** `pairingInProgress`

```dart
// User flow
1. User selects connection method (USB/BLE/QR)
2. App searches for devices
3. Device found → show device card
4. User sees:
   - Device name: "Trezor Model T"
   - Fingerprint: "73c5da0a"
   - Firmware: "2.6.0"
   - Taproot: "Supported ✓"
5. User taps "Continue"
```

- **API Calls:**
```dart
final device = await hardwareWalletService.pairDevice(
  method: ConnectionMethod.usb,
  role: DeviceRole.daily,
  network: Network.mainnet,
);
// Returns: DeviceInfo
```

#### Step 3: Select Template
- **Screen:** `TemplateScreen`
- **User Action:** Taps "Savings Vault" card
- **App Action:** Store selection, navigate to `/onboarding/publish`

#### Step 4: Generate & Verify Address
- **Screen:** `PublishVaultScreen`
- **State:** `generatingAddress`

```dart
// Generate address
final addressResult = await rustFfi.generateVaultAddress(
  primaryXpub: device.xpub,
  emergencyXpub: null,  // Optional
  template: VaultTemplate.savings(),
  vaultIndex: 0,
  network: Network.mainnet,
);

// Display to user
// Address: bc1p8xk7...f9d2
// Show QR code

// Request verification on device
await hardwareWalletService.displayAddress(
  address: addressResult.address,
  deviceFingerprint: device.fingerprint,
);

// User confirms match on device
// Show "Verified on Device ✓" badge
```

#### Step 5: Fund Vault
- **Screen:** `PublishVaultScreen`
- **State:** `awaitingFunding`
- **User Action:** Sends BTC from exchange

```dart
// Register with watcher for monitoring
await watcherService.registerVault(
  vaultId: vault.id,
  descriptor: addressResult.descriptor,
  addresses: [addressResult.address],
  deviceToken: await fcm.getToken(),
);

// Poll or websocket for incoming transaction
watcherService.watchUtxos(vault.id).listen((utxos) {
  if (utxos.isNotEmpty) {
    // Vault funded!
    navigateToDashboard();
  }
});
```

#### Step 6: Success
- **Screen:** `DashboardScreen`
- **User Sees:**
  - Vault card with balance
  - "Secure ✓" status
  - Send/Receive buttons

---

## Flow 2: Spending from Vault

**Goal:** Ricky sends 0.5 BTC to cold storage

### Sequence Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Ricky  │     │   App   │     │  Rust   │     │ Hardware│     │Blockchain│
│         │     │         │     │  Core   │     │  Wallet │     │         │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │ Tap "Send"    │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ Enter details │               │               │               │
     │ Amount: 0.5   │               │               │               │
     │ Dest: bc1q... │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │               │  Validate     │               │               │
     │               │  address      │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── valid ─────│               │               │
     │               │               │               │               │
     │               │  Get UTXOs    │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<── UTXOs ─────────────────────────────────────│
     │               │               │               │               │
     │               │  Build PSBT   │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── PSBT ──────│               │               │
     │               │               │               │               │
     │ See summary:  │               │               │               │
     │ "0.5 BTC to   │               │               │               │
     │  cold storage"│               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ "Confirm on   │               │               │               │
     │  device"      │               │               │               │
     │──────────────>│               │               │               │
     │               │  Send PSBT    │               │               │
     │               │───────────────────────────────>               │
     │               │               │               │               │
     │               │               │  Display:     │               │
     │               │               │  Amount, Dest │               │
     │               │               │  Fee, Path    │               │
     │               │               │               │               │
     │ Approve on    │               │               │               │
     │ device        │               │               │               │
     │───────────────────────────────────────────────>               │
     │               │               │               │               │
     │               │<── Signed ────│               │               │
     │               │    PSBT       │               │               │
     │               │               │               │               │
     │               │  Finalize     │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── tx_hex ────│               │               │
     │               │               │               │               │
     │               │  Broadcast    │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<── txid ──────────────────────────────────────│
     │               │               │               │               │
     │ "Transaction  │               │               │               │
     │  sent! Coins  │               │               │               │
     │  move Feb 3"  │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
```

### Detailed Steps

#### Step 1: Initiate Spend
- **Screen:** `SpendWizardScreen`
- **User Action:** Enters destination and amount

```dart
// Validate destination address
final validation = await rustFfi.validateAddress(
  address: destinationInput,
  network: Network.mainnet,
);

if (!validation.isValid) {
  showError("Invalid Bitcoin address");
  return;
}
```

#### Step 2: Build Transaction
- **State:** `buildingTransaction`

```dart
// Fetch UTXOs from watcher
final utxos = await watcherService.getUtxos(vault.id);

// Build PSBT
final psbt = await rustFfi.buildDelayedSpendPsbt(
  intent: SpendIntent(
    vaultId: vault.id,
    destination: destinationAddress,
    amountSats: amountSats,
    feeRate: selectedFeeRate,
    pathType: SpendPath.delayed,
  ),
  utxos: utxos,
);

// Show summary to user
showTransactionSummary(psbt.summary);
```

#### Step 3: Device Confirmation
- **Screen:** `ConfirmDeviceScreen`
- **State:** `awaitingDeviceConfirmation`

```dart
// Send PSBT to hardware wallet
final signedPsbt = await hardwareWalletService.signPsbt(
  psbtBase64: psbt.psbtBase64,
  deviceFingerprint: vault.primaryDevice.fingerprint,
);

// User sees on device:
// - Destination: Cold Storage
// - Amount: 0.5 BTC
// - Fee: 0.00001 BTC
// - Path: Script-path (1008 blocks)
//
// User presses confirm button on device
```

#### Step 4: Broadcast
- **State:** `broadcasting`

```dart
// Finalize PSBT
final finalizedTx = await rustFfi.finalizePsbt(signedPsbt.psbtBase64);

// Broadcast
final result = await watcherService.broadcast(finalizedTx.txHex);

// Show success
showTransactionSuccess(
  txid: result.txid,
  estimatedCompletion: calculateCompletion(vault.template.delayBlocks),
);
```

#### Step 5: Timeline Display
- **Screen:** `DashboardScreen` (with pending transaction)

```
Transaction sent!

• Initiated: Today, 2:30 PM
• Coins movable: Feb 3, 2025, 2:30 PM

If you didn't authorize this, you can cancel
before the delay period ends.

[View on Explorer]  [Cancel Transaction]
```

---

## Flow 3: Recovery

**Goal:** Ricky's phone breaks, he recovers on new device

### Sequence Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Ricky  │     │ New App │     │  Rust   │     │ Hardware│     │Blockchain│
│         │     │         │     │  Core   │     │  Wallet │     │         │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │ Install app   │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ "I have vault"│               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ Connect wallet│               │               │               │
     │──────────────>│               │               │               │
     │               │  Get xpub     │               │               │
     │               │───────────────────────────────>               │
     │               │               │               │               │
     │               │<── xpub ──────────────────────│               │
     │               │               │               │               │
     │               │  Derive scan  │               │               │
     │               │  addresses    │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── 100 addrs ─│               │               │
     │               │               │               │               │
     │ "Scanning..." │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │               │  Query each   │               │               │
     │               │  address      │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<── UTXOs for  │               │               │
     │               │    addr[42]   │               │               │
     │               │               │               │               │
     │               │  Reconstruct  │               │               │
     │               │  vault from   │               │               │
     │               │  metadata     │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── VaultConfig│               │               │
     │               │               │               │               │
     │ "Found vault: │               │               │               │
     │  1.25 BTC"    │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ "Confirm"     │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ Dashboard     │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
```

### Detailed Steps

#### Step 1: Start Recovery
- **Screen:** `WelcomeScreen` → `RecoveryWizardScreen`
- **User Action:** Taps "I already have a vault"

#### Step 2: Connect Wallet
- **Screen:** `RecoveryWizardScreen` (step 1)

```dart
// Same pairing flow as setup
final device = await hardwareWalletService.pairDevice(
  method: ConnectionMethod.usb,
  role: DeviceRole.daily,
  network: Network.mainnet,
);
```

#### Step 3: Scan Blockchain
- **Screen:** `RecoveryWizardScreen` (step 2)
- **State:** `scanning`

```dart
// Derive all possible vault addresses
final scanAddresses = await rustFfi.deriveScanAddresses(
  xpub: device.xpub,
  startIndex: 0,
  count: 100,  // Check first 100 derivation indices
  network: Network.mainnet,
);

// Query blockchain for each
List<RecoveredVault> found = [];

for (final addr in scanAddresses) {
  final utxos = await watcherService.getUtxosForAddress(addr.address);
  
  if (utxos.isNotEmpty) {
    // Found a vault! Reconstruct it
    final vault = await rustFfi.reconstructVault(
      address: addr.address,
      utxos: utxos,
      xpub: device.xpub,
      network: Network.mainnet,
    );
    found.add(vault);
  }
  
  // Update progress UI
  updateScanProgress(addr.index, scanAddresses.length);
}
```

#### Step 4: Display Results
- **Screen:** `RecoveryWizardScreen` (step 3)

```dart
// Show found vaults
showRecoveredVaults(found);

// User sees:
// ┌─────────────────────────────────┐
// │ Found 2 vaults:                 │
// │                                 │
// │ 💎 Savings Vault                │
// │    Balance: 1.25 BTC            │
// │    Created: Jan 1, 2025         │
// │                                 │
// │ 💳 Spending Vault               │
// │    Balance: 0.25 BTC            │
// │    Created: Jan 15, 2025        │
// └─────────────────────────────────┘
```

#### Step 5: Confirm & Complete
- **User Action:** Taps "Confirm Recovery"

```dart
// Save recovered vaults locally
for (final vault in found) {
  await vaultRepository.saveVault(vault);
}

// Register with watcher
for (final vault in found) {
  await watcherService.registerVault(
    vaultId: vault.id,
    descriptor: vault.descriptor,
    addresses: [vault.address],
    deviceToken: await fcm.getToken(),
  );
}

// Navigate to dashboard
navigateTo('/dashboard');
```

---

## Flow 4: Alert Response (Unauthorized Spend)

**Goal:** Ricky receives alert about unauthorized spend attempt and cancels it

### Sequence Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Ricky  │     │   App   │     │ Watcher │     │ Hardware│     │Blockchain│
│         │     │         │     │         │     │  Wallet │     │         │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │               │
     │               │               │  Detect spend │               │
     │               │               │<──────────────────────────────│
     │               │               │               │               │
     │ Push: "Vault  │               │               │               │
     │  activity!"   │<──────────────│               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ Tap notif     │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │ See alert     │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ "Cancel!"     │               │               │               │
     │──────────────>│               │               │               │
     │               │               │               │               │
     │               │  Get UTXOs    │               │               │
     │               │──────────────>│               │               │
     │               │               │               │               │
     │               │<── UTXOs ─────│               │               │
     │               │               │               │               │
     │               │  Build        │               │               │
     │               │  emergency    │               │               │
     │               │  PSBT         │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<── PSBT ──────────────────────────────────────│
     │               │               │               │               │
     │ "Confirm on   │               │               │               │
     │  EMERGENCY    │               │               │               │
     │  device"      │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
     │ Connect       │               │               │               │
     │ emergency     │               │               │               │
     │ wallet        │               │               │               │
     │──────────────────────────────────────────────>│               │
     │               │               │               │               │
     │               │<── Signed ────────────────────│               │
     │               │               │               │               │
     │               │  Broadcast    │               │               │
     │               │  (key-path)   │               │               │
     │               │───────────────────────────────────────────────>
     │               │               │               │               │
     │               │<── confirmed ─────────────────────────────────│
     │               │               │               │               │
     │ "Canceled!    │               │               │               │
     │  Coins safe"  │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │               │
```

### Detailed Steps

#### Step 1: Receive Alert
- **Trigger:** Push notification from watcher
- **User Action:** Taps notification

```dart
// Deep link handling
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  if (message.data['type'] == 'spend_detected') {
    navigateTo('/alerts/${message.data['vault_id']}');
  }
});
```

#### Step 2: View Alert Details
- **Screen:** `RespondAlertScreen`

```
⚠️ Spending Activity Detected

Your Savings Vault is attempting to spend:

Amount: 1.25 BTC (entire balance)
Destination: bc1q9xy2...unknown
Fee: 0.0001 BTC

Timeline:
• Initiated: Today, 3:45 PM
• Coins move: Feb 3, 2025

Did you authorize this?

[Yes, I did this]  [No! Cancel it]
```

#### Step 3: Initiate Cancel
- **User Action:** Taps "No! Cancel it"
- **State:** `preparingCancel`

```dart
// Build emergency recovery transaction
final psbt = await rustFfi.buildEmergencyPsbt(
  vaultId: vault.id,
  destination: safeDestinationAddress, // Pre-configured or new vault
  feeRate: highFeeRate, // Use high fee for priority
  utxos: await watcherService.getUtxos(vault.id),
);

// Prompt for emergency device
showDialog(
  title: "Connect Emergency Device",
  message: "Connect your emergency hardware wallet "
           "to cancel this unauthorized transaction.",
);
```

#### Step 4: Sign with Emergency Device
- **User Action:** Connects emergency device and approves

```dart
// Pair emergency device
final emergencyDevice = await hardwareWalletService.pairDevice(
  method: ConnectionMethod.usb,
  role: DeviceRole.emergency,
  network: Network.mainnet,
);

// Sign PSBT (key-path spend - immediate)
final signedPsbt = await hardwareWalletService.signPsbt(
  psbtBase64: psbt.psbtBase64,
  deviceFingerprint: emergencyDevice.fingerprint,
);
```

#### Step 5: Broadcast & Confirm
- **State:** `broadcasting`

```dart
// Finalize and broadcast
final finalizedTx = await rustFfi.finalizePsbt(signedPsbt.psbtBase64);
final result = await watcherService.broadcast(finalizedTx.txHex);

// Show success
showCancelSuccess(
  message: "Transaction canceled! Your coins are safe.",
  newBalance: await watcherService.getBalance(vault.id),
);
```

---

## Edge Cases & Error Handling

### Device Disconnected Mid-Flow

```dart
try {
  final signedPsbt = await hardwareWalletService.signPsbt(...);
} on DeviceDisconnectedException {
  showReconnectDialog(
    message: "Device disconnected. Please reconnect to continue.",
    onReconnected: () => retryOperation(),
  );
}
```

### Insufficient Balance

```dart
try {
  final psbt = await rustFfi.buildDelayedSpendPsbt(...);
} on RustCoreException catch (e) {
  if (e.code == ErrorCodes.INSUFFICIENT_FUNDS) {
    showError(
      "Not enough Bitcoin in this vault. "
      "Available: ${formatBtc(available)} BTC"
    );
  }
}
```

### Network Error During Broadcast

```dart
try {
  final result = await watcherService.broadcast(txHex);
} on NetworkException {
  showRetryDialog(
    message: "Can't connect to the network. "
             "Your transaction is saved and will be broadcast "
             "when connection is restored.",
    onRetry: () => retryBroadcast(),
  );
  
  // Save locally for retry
  await pendingTransactionsStore.save(txHex);
}
```

### Recovery Finds No Vaults

```dart
if (foundVaults.isEmpty) {
  showNoVaultsDialog(
    message: "No vaults found for this wallet.\n\n"
             "This could mean:\n"
             "• You haven't created a vault yet\n"
             "• You're using a different hardware wallet\n"
             "• Your vault was fully spent",
    actions: [
      DialogAction("Create New Vault", () => navigateTo('/onboarding')),
      DialogAction("Try Different Wallet", () => restart()),
    ],
  );
}
```
