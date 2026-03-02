import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freedom_wallet/domain/models/vault.dart';

class OnboardingState {
  final VaultTemplate? selectedTemplate;
  final String? generatedAddress;
  final bool isPublishing;
  final bool isFunded;

  const OnboardingState({
    this.selectedTemplate,
    this.generatedAddress,
    this.isPublishing = false,
    this.isFunded = false,
  });

  OnboardingState copyWith({
    VaultTemplate? selectedTemplate,
    String? generatedAddress,
    bool? isPublishing,
    bool? isFunded,
  }) {
    return OnboardingState(
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      generatedAddress: generatedAddress ?? this.generatedAddress,
      isPublishing: isPublishing ?? this.isPublishing,
      isFunded: isFunded ?? this.isFunded,
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void selectTemplate(VaultTemplate template) {
    state = state.copyWith(selectedTemplate: template);
  }

  Future<void> publishVault() async {
    state = state.copyWith(isPublishing: true);
    // Simulate address generation
    await Future.delayed(const Duration(seconds: 1));
    state = state.copyWith(
      generatedAddress:
          'bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297',
      isPublishing: false,
    );
  }

  Future<void> simulateFunding() async {
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(isFunded: true);
  }

  void reset() {
    state = const OnboardingState();
  }
}
