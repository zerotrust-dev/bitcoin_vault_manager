import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/data/datasources/rust_ffi_datasource.dart';
import 'package:freedom_wallet/domain/models/vault.dart';
import 'package:freedom_wallet/presentation/providers/vault_provider.dart';

class OnboardingState {
  final VaultTemplate? selectedTemplate;
  final String? generatedAddress;
  final bool isPublishing;
  final bool isFunded;
  final String? error;

  const OnboardingState({
    this.selectedTemplate,
    this.generatedAddress,
    this.isPublishing = false,
    this.isFunded = false,
    this.error,
  });

  OnboardingState copyWith({
    VaultTemplate? selectedTemplate,
    String? generatedAddress,
    bool? isPublishing,
    bool? isFunded,
    String? error,
  }) {
    return OnboardingState(
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      generatedAddress: generatedAddress ?? this.generatedAddress,
      isPublishing: isPublishing ?? this.isPublishing,
      isFunded: isFunded ?? this.isFunded,
      error: error,
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(ref.read(rustFfiProvider)),
);

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final RustFfi _ffi;

  OnboardingNotifier(this._ffi) : super(const OnboardingState());

  void selectTemplate(VaultTemplate template) {
    state = state.copyWith(selectedTemplate: template);
  }

  /// Generate a real Taproot vault address via the Rust core.
  ///
  /// Uses a test xpub for now; in Phase 3 this will come from the paired
  /// hardware wallet device.
  Future<void> publishVault({String? primaryXpub}) async {
    state = state.copyWith(isPublishing: true, error: null);
    try {
      final template = state.selectedTemplate;
      if (template == null) {
        state = state.copyWith(
          isPublishing: false,
          error: 'No template selected',
        );
        return;
      }

      // Build the Rust-compatible template JSON
      final rustTemplate = <String, dynamic>{'type': template.type};
      if (template.type == 'custom') {
        rustTemplate['delay_blocks'] = template.delayBlocks;
        rustTemplate['recovery_type'] = 'timelock_only';
      }

      // Use provided xpub, or fall back to a well-known test xpub
      // (In Phase 3, this comes from the paired hardware wallet)
      final xpub = primaryXpub ??
          'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8';

      final result = _ffi.generateVaultAddress(
        primaryXpub: xpub,
        template: rustTemplate,
        vaultIndex: 0,
        network: 0, // mainnet; will use settings network in Phase 3
      );

      state = state.copyWith(
        generatedAddress: result['address'] as String,
        isPublishing: false,
      );
    } on RustCoreException catch (e) {
      state = state.copyWith(
        isPublishing: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> simulateFunding() async {
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(isFunded: true);
  }

  void reset() {
    state = const OnboardingState();
  }
}
