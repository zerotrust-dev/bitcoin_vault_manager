# Flutter App Specification

## Overview

The `freedom-wallet-app` is a cross-platform Flutter application that provides the user interface for managing Bitcoin vaults. It communicates with hardware wallets, calls the Rust core via FFI, and interacts with the blockchain through the watcher service.

---

## Project Structure

```
freedom-wallet-app/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart                      # App entry point
│   ├── app/
│   │   ├── app.dart                   # MaterialApp configuration
│   │   ├── router.dart                # GoRouter navigation
│   │   └── theme.dart                 # App theme (colors, typography)
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # App-wide constants
│   │   │   └── bitcoin_constants.dart # Bitcoin-specific constants
│   │   ├── errors/
│   │   │   ├── app_error.dart         # Base error types
│   │   │   └── error_handler.dart     # Global error handling
│   │   └── utils/
│   │       ├── formatters.dart        # BTC formatting, dates
│   │       └── validators.dart        # Input validation
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── rust_ffi_datasource.dart    # Rust core FFI bridge
│   │   │   ├── hardware_wallet_datasource.dart
│   │   │   └── blockchain_datasource.dart
│   │   ├── repositories/
│   │   │   ├── vault_repository.dart
│   │   │   ├── device_repository.dart
│   │   │   └── settings_repository.dart
│   │   └── local/
│   │       └── secure_storage.dart    # Encrypted local storage
│   │
│   ├── domain/
│   │   ├── models/
│   │   │   ├── vault.dart
│   │   │   ├── device.dart
│   │   │   ├── transaction.dart
│   │   │   └── alert.dart
│   │   ├── services/
│   │   │   ├── vault_service.dart
│   │   │   ├── hardware_wallet_service.dart
│   │   │   └── watcher_service.dart
│   │   └── interfaces/
│   │       ├── i_vault_orchestrator.dart
│   │       └── i_hardware_wallet.dart
│   │
│   ├── presentation/
│   │   ├── common/
│   │   │   ├── widgets/               # Shared widgets
│   │   │   └── dialogs/               # Common dialogs
│   │   ├── features/
│   │   │   ├── onboarding/
│   │   │   │   ├── welcome_screen.dart
│   │   │   │   ├── pair_device_screen.dart
│   │   │   │   ├── template_screen.dart
│   │   │   │   └── publish_vault_screen.dart
│   │   │   ├── dashboard/
│   │   │   │   ├── dashboard_screen.dart
│   │   │   │   └── widgets/
│   │   │   ├── backup/
│   │   │   │   ├── backup_center_screen.dart
│   │   │   │   └── recovery_wizard_screen.dart
│   │   │   ├── spend/
│   │   │   │   ├── spend_wizard_screen.dart
│   │   │   │   └── confirm_device_screen.dart
│   │   │   ├── alerts/
│   │   │   │   ├── alerts_screen.dart
│   │   │   │   └── respond_alert_screen.dart
│   │   │   └── settings/
│   │   │       └── settings_screen.dart
│   │   └── providers/
│   │       ├── vault_provider.dart
│   │       ├── device_provider.dart
│   │       └── settings_provider.dart
│   │
│   └── rust_libs/                     # Native libraries (gitignored)
│       ├── android/
│       ├── ios/
│       ├── windows/
│       ├── macos/
│       └── linux/
│
├── android/
├── ios/
├── windows/
├── macos/
├── linux/
└── test/
```

---

## Dependencies

```yaml
# pubspec.yaml
name: freedom_wallet
description: Bitcoin Vault Manager - Self-custody made simple
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Navigation
  go_router: ^12.0.0
  
  # FFI
  ffi: ^2.1.0
  
  # Local Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0
  
  # Networking
  dio: ^5.3.0
  web_socket_channel: ^2.4.0
  
  # Push Notifications
  firebase_messaging: ^14.7.0
  firebase_core: ^2.24.0
  
  # Hardware Wallet Communication
  flutter_blue_plus: ^1.28.0  # BLE
  usb_serial: ^0.5.0          # USB
  mobile_scanner: ^3.5.0      # QR codes
  
  # UI Components
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  
  # Utilities
  intl: ^0.18.0
  uuid: ^4.2.0
  equatable: ^2.0.5
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  
  # Biometrics
  local_auth: ^2.1.0
  
  # Deep Links
  uni_links: ^0.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```

---

## Screen Specifications

### 1. Welcome Screen

**Route:** `/`  
**Purpose:** Entry point for new and returning users

```dart
class WelcomeScreen extends ConsumerWidget {
  // Primary job: Help user choose setup or recovery path
  // 
  // Key actions:
  // - "Set up my vault" → /onboarding/pair-device
  // - "I already have a vault" → /recovery
  //
  // States: 
  // - Default (two buttons)
  // - Loading (checking for existing vaults)
}
```

**UI Elements:**
- App logo and tagline
- "Set up my vault" button (primary, prominent)
- "I already have a vault" link (secondary)
- Version number footer

**Copy:**
```
Welcome to Freedom Wallet

Your Bitcoin savings, protected by time.

[Set up my vault]

Already have a vault? [Recover it here]
```

---

### 2. Pair Device Screen

**Route:** `/onboarding/pair-device`  
**Purpose:** Connect hardware wallet and extract xpub

```dart
class PairDeviceScreen extends ConsumerWidget {
  // Primary job: Successfully pair hardware wallet
  // 
  // Key actions:
  // - Select connection method (USB/BLE/QR)
  // - Initiate pairing
  // - Verify device fingerprint
  //
  // States:
  // - Connection method selection
  // - Pairing in progress
  // - Success (show device info)
  // - Error (retry option)
}
```

**Flow:**
1. User selects connection method
2. App initiates connection
3. Device responds with xpub
4. App displays device fingerprint for verification
5. User confirms → proceed to template selection

**UI Elements:**
- Connection method tabs (USB-C, Bluetooth, QR Scan)
- Device search animation
- Found device card (name, fingerprint, firmware)
- "Verified on Device" badge
- Continue button

**Copy:**
```
Connect your hardware wallet

Your hardware wallet keeps your keys safe.
We'll use it to protect your vault.

[USB-C]  [Bluetooth]  [QR Code]

Searching for devices...

---

Found: Trezor Model T
Fingerprint: 73c5da0a
Firmware: 2.6.0 ✓
Taproot: Supported ✓

Your private keys never leave this device.

[Continue]
```

---

### 3. Template Selection Screen

**Route:** `/onboarding/template`  
**Purpose:** Choose vault security configuration

```dart
class TemplateScreen extends ConsumerWidget {
  // Primary job: Select appropriate vault template
  //
  // Key actions:
  // - View template options
  // - See plain-English explanation
  // - Select template
  //
  // States:
  // - Template selection
  // - Custom configuration (advanced)
}
```

**Templates:**

| Template | Delay | Description |
|----------|-------|-------------|
| Savings Vault | 1 week | Maximum security for long-term storage |
| Spending Vault | 1 day | Balanced security for regular use |
| Custom | Variable | Advanced configuration |

**UI Elements:**
- Template cards with icons
- Plain-English explanation panel
- "What does this mean?" expandable
- Continue button

**Copy:**
```
Choose your vault's protection

How long should your vault wait before 
allowing Bitcoin to move?

┌─────────────────────────────────────┐
│ 💎 Savings Vault                    │
│                                     │
│ 1 week delay                        │
│                                     │
│ Best for: Long-term savings         │
│ "I want maximum protection"         │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 💳 Spending Vault                   │
│                                     │
│ 1 day delay                         │
│                                     │
│ Best for: Regular use               │
│ "I spend from this sometimes"       │
└─────────────────────────────────────┘

What does "delay" mean?
▼ When you try to spend, your vault waits
  before releasing Bitcoin. This gives you
  time to cancel if something looks wrong.

[Continue with Savings Vault]
```

---

### 4. Publish Vault Screen

**Route:** `/onboarding/publish`  
**Purpose:** Generate address and fund the vault

```dart
class PublishVaultScreen extends ConsumerWidget {
  // Primary job: Create vault address and guide funding
  //
  // Key actions:
  // - Generate vault address
  // - Display for WYSIWYS verification
  // - Copy address for funding
  // - Monitor for incoming transaction
  //
  // States:
  // - Generating address
  // - Ready to fund (show address)
  // - Waiting for funding
  // - Funded (success)
}
```

**Flow:**
1. App generates Taproot address with metadata
2. User verifies address on hardware wallet
3. User funds address from external source
4. App monitors for incoming transaction
5. Confirmation → Dashboard

**UI Elements:**
- Address display (large, scannable QR)
- "Verify on Device" button
- Copy address button
- Funding status indicator
- "Verified on Device ✓" badge

**Copy:**
```
Fund your vault

Send Bitcoin to this address to activate 
your vault.

┌─────────────────────────────────────┐
│         [QR CODE]                   │
│                                     │
│  bc1p8xk7...f9d2                    │
│                                     │
│  [Copy]  [Verify on Device]         │
└─────────────────────────────────────┘

✓ Verified on Device

⏳ Waiting for funding...

Once you send Bitcoin to this address,
your vault will be active.

You don't need to backup anything else.
The blockchain remembers your vault forever.
```

---

### 5. Dashboard Screen

**Route:** `/dashboard`  
**Purpose:** Main hub for vault management

```dart
class DashboardScreen extends ConsumerWidget {
  // Primary job: Overview of all vaults and quick actions
  //
  // Key actions:
  // - View vault balances
  // - See pending transactions
  // - Access spend/receive
  // - View alerts
  //
  // States:
  // - Loading
  // - Empty (no vaults)
  // - Normal (vaults displayed)
  // - Alert active (banner)
}
```

**UI Elements:**
- Total balance header
- Vault cards (name, balance, status)
- Quick actions (Send, Receive)
- Alert banner (if active)
- Settings access

**Copy:**
```
Your Vaults

Total Balance: 1.50 BTC

┌─────────────────────────────────────┐
│ 💎 Savings Vault                    │
│                                     │
│ 1.25 BTC                            │
│ Protection: 1 week delay            │
│ Status: Secure ✓                    │
│                                     │
│ [Send]  [Receive]  [Details]        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 💳 Spending Vault                   │
│                                     │
│ 0.25 BTC                            │
│ Protection: 1 day delay             │
│ Status: Secure ✓                    │
│                                     │
│ [Send]  [Receive]  [Details]        │
└─────────────────────────────────────┘
```

---

### 6. Spend Wizard Screen

**Route:** `/spend/:vaultId`  
**Purpose:** Guide user through spending from vault

```dart
class SpendWizardScreen extends ConsumerWidget {
  // Primary job: Complete a spend transaction safely
  //
  // Steps:
  // 1. Enter destination and amount
  // 2. Review plain-English summary
  // 3. Approve on hardware wallet
  // 4. Broadcast transaction
  // 5. Show timeline
  //
  // States:
  // - Input (destination, amount)
  // - Building PSBT
  // - Awaiting device confirmation
  // - Broadcasting
  // - Success (show timeline)
  // - Error
}
```

**Flow:**
1. User enters destination address
2. User enters amount (or "sweep all")
3. App builds PSBT and shows summary
4. User approves on hardware wallet
5. App broadcasts transaction
6. App shows timeline with expected completion

**UI Elements:**
- Destination input with validation
- Amount input with BTC/fiat toggle
- Fee selector (low/medium/high)
- Plain-English summary card
- Device confirmation waiting state
- Timeline visualization

**Copy:**
```
Send Bitcoin

From: Savings Vault (1.25 BTC available)

┌─────────────────────────────────────┐
│ To:                                 │
│ [bc1q... or paste address]          │
│                                     │
│ Amount:                             │
│ [0.5 BTC] or [Sweep All]            │
│                                     │
│ Network Fee:                        │
│ ○ Low (~$0.50)   ○ Medium (~$1)     │
│ ● High (~$2)                        │
└─────────────────────────────────────┘

---

Ready to send

From: Your Savings Vault
To: bc1qxy2...7p6h
Amount: 0.5 BTC ($32,500)
Fee: 0.00001 BTC ($0.65)

Timeline:
• Today: Transaction enters delay
• Feb 3, 2025: Coins arrive at destination
  (unless you cancel)

[Confirm on Device →]

---

Confirm on your Trezor

Your device will show:
• Destination address
• Amount: 0.5 BTC
• Fee: 0.00001 BTC

Press the button on your device to approve.

[Waiting for confirmation...]
```

---

### 7. Backup Center Screen

**Route:** `/backup`  
**Purpose:** Educate user about backup model and verify

```dart
class BackupCenterScreen extends ConsumerWidget {
  // Primary job: Give confidence about backup status
  //
  // Key messages:
  // - Your only backup is your seed phrase
  // - The blockchain stores your vault info
  // - Recovery is automatic
  //
  // Actions:
  // - View seed backup checklist
  // - Test recovery (simulation)
  // - Export descriptor (advanced)
}
```

**UI Elements:**
- Backup status summary
- Seed phrase checklist
- "Test Recovery" button
- Educational explainer
- Advanced options (hidden by default)

**Copy:**
```
Backup Center

✓ Your vault is backed up by the blockchain

What you need to keep safe:

┌─────────────────────────────────────┐
│ 🔑 Your Hardware Wallet Seed        │
│                                     │
│ This is your ONLY backup.           │
│ Without it, you lose access.        │
│                                     │
│ ✓ I have my seed phrase stored      │
│   safely in multiple locations      │
└─────────────────────────────────────┘

What you DON'T need to backup:
• ✓ Vault configuration (on blockchain)
• ✓ Transaction history (on blockchain)
• ✓ Metadata (encoded in address)

Why? Your vault information is stored
immutably on the Bitcoin blockchain.

[Test Recovery] - Simulate recovering 
your vault on a new device

──────────────────────────────────────
Advanced (for experts)
▼ Export vault descriptor
```

---

### 8. Recovery Wizard Screen

**Route:** `/recovery`  
**Purpose:** Recover vaults from seed phrase

```dart
class RecoveryWizardScreen extends ConsumerWidget {
  // Primary job: Automatically recover all vaults
  //
  // Steps:
  // 1. Connect hardware wallet
  // 2. Scan blockchain for vaults
  // 3. Display recovered vaults
  // 4. Confirm and proceed
  //
  // States:
  // - Connect wallet
  // - Scanning blockchain
  // - Found vaults
  // - No vaults found
  // - Error
}
```

**Flow:**
1. User connects hardware wallet
2. App derives xpub
3. App scans blockchain for vault addresses
4. App reconstructs vault configs from metadata
5. User confirms recovered vaults

**UI Elements:**
- Hardware wallet connection
- Scanning progress
- Recovered vault cards
- Confirm button

**Copy:**
```
Recover Your Vaults

Step 1: Connect your hardware wallet
[Same pairing flow]

---

Step 2: Scanning the blockchain...

Looking for your vaults...
Checked 50 of 100 addresses...

This may take 1-2 minutes.

---

Step 3: Found your vaults!

We found 2 vaults on the blockchain:

┌─────────────────────────────────────┐
│ 💎 Savings Vault                    │
│ Balance: 1.25 BTC                   │
│ Protection: 1 week delay            │
│ Created: Jan 1, 2025                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 💳 Spending Vault                   │
│ Balance: 0.25 BTC                   │
│ Protection: 1 day delay             │
│ Created: Jan 15, 2025               │
└─────────────────────────────────────┘

[Confirm Recovery]
```

---

### 9. Alerts Screen

**Route:** `/alerts`  
**Purpose:** Show vault activity alerts

```dart
class AlertsScreen extends ConsumerWidget {
  // Primary job: Display and manage vault alerts
  //
  // Alert types:
  // - Spend detected
  // - Timelock maturing
  // - Recovery needed
  //
  // Actions:
  // - View alert details
  // - Take action (cancel, ignore)
}
```

**Alert Example:**
```
⚠️ Spending Activity Detected

Your Savings Vault is attempting to 
spend 0.5 BTC.

Timeline:
• Initiated: Today, 3:45 PM
• Coins move: Feb 3, 2025

Did you authorize this?

[Yes, I did this]  [No! Cancel it]

If you didn't do this, tap "Cancel" 
to move your coins to safety using 
your emergency device.
```

---

## State Management

### Providers (Riverpod)

```dart
// vault_provider.dart
@riverpod
class VaultNotifier extends _$VaultNotifier {
  @override
  Future<List<Vault>> build() async {
    return ref.read(vaultRepositoryProvider).getAllVaults();
  }
  
  Future<void> createVault(VaultCreationRequest request) async {
    state = const AsyncLoading();
    try {
      final vault = await ref.read(vaultServiceProvider).createVault(request);
      state = AsyncData([...state.value ?? [], vault]);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// device_provider.dart
@riverpod
class ConnectedDevice extends _$ConnectedDevice {
  @override
  DeviceInfo? build() => null;
  
  Future<void> pairDevice(ConnectionMethod method) async {
    final device = await ref.read(hardwareWalletServiceProvider).pair(method);
    state = device;
  }
}

// settings_provider.dart  
@riverpod
class AppSettings extends _$AppSettings {
  @override
  Settings build() => Settings.defaults();
  
  void updateNetwork(Network network) {
    state = state.copyWith(network: network);
  }
}
```

---

## Navigation (GoRouter)

```dart
// router.dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/pair-device',
        builder: (context, state) => const PairDeviceScreen(),
      ),
      GoRoute(
        path: '/onboarding/template',
        builder: (context, state) => const TemplateScreen(),
      ),
      GoRoute(
        path: '/onboarding/publish',
        builder: (context, state) => const PublishVaultScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/spend/:vaultId',
        builder: (context, state) => SpendWizardScreen(
          vaultId: state.pathParameters['vaultId']!,
        ),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupCenterScreen(),
      ),
      GoRoute(
        path: '/recovery',
        builder: (context, state) => const RecoveryWizardScreen(),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) async {
      // Check if user has vaults, redirect accordingly
      final hasVaults = await ref.read(vaultRepositoryProvider).hasVaults();
      if (hasVaults && state.matchedLocation == '/') {
        return '/dashboard';
      }
      return null;
    },
  );
});
```

---

## Theme

```dart
// theme.dart
class AppTheme {
  static const primaryColor = Color(0xFF2962FF);  // Trust blue
  static const successColor = Color(0xFF00C853);   // Verified green
  static const warningColor = Color(0xFFFF6D00);   // Alert orange
  static const errorColor = Color(0xFFD50000);     // Danger red
  static const backgroundColor = Color(0xFFF5F5F5);
  static const cardColor = Colors.white;
  
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    // ... typography, component themes
  );
  
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
  );
}
```

---

## Copy Guidelines

**Voice:** Calm, confident, plain English

**Rules:**
1. Never use jargon without explanation
2. Always explain "why" not just "what"
3. Use absolute dates ("Feb 3, 2025") not relative ("in 7 days")
4. Provide reassurance after actions
5. Avoid technical terms: "descriptor", "UTXO", "script"

**Substitutions:**
| Technical | Plain English |
|-----------|---------------|
| UTXO | coins / balance |
| Descriptor | vault configuration |
| PSBT | transaction |
| Script path | vault delay |
| Key path | emergency access |
| CSV | time delay |

---

## Accessibility

- Minimum touch targets: 48x48 dp
- Color contrast: WCAG AA minimum
- Screen reader labels on all interactive elements
- Keyboard navigation support
- Focus management on dialogs

---

## Error Handling

```dart
// Global error handler
class AppErrorHandler {
  static String getUserFriendlyMessage(AppError error) {
    return switch (error) {
      NetworkError() => "Can't connect to the internet. Please check your connection.",
      DeviceNotFoundError() => "Hardware wallet not found. Make sure it's connected.",
      InsufficientFundsError() => "Not enough Bitcoin in this vault.",
      PolicyViolationError() => "This action isn't allowed by your vault's settings.",
      _ => "Something went wrong. Please try again.",
    };
  }
}
```

---

## Testing Strategy

### Unit Tests
- Provider logic
- Formatters and validators
- Repository methods (mocked)

### Widget Tests
- Screen layouts
- User interactions
- State changes

### Integration Tests
- Full user flows
- Hardware wallet simulation
- Recovery scenarios
