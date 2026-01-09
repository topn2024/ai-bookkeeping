import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding state
class OnboardingState {
  final bool isCompleted;
  final bool isLoading;

  const OnboardingState({
    required this.isCompleted,
    this.isLoading = false,
  });

  OnboardingState copyWith({
    bool? isCompleted,
    bool? isLoading,
  }) {
    return OnboardingState(
      isCompleted: isCompleted ?? this.isCompleted,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Onboarding provider
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  OnboardingNotifier() : super(const OnboardingState(isCompleted: false, isLoading: true)) {
    _loadOnboardingStatus();
  }

  /// Load onboarding status from SharedPreferences
  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;
      state = OnboardingState(isCompleted: isCompleted, isLoading: false);
    } catch (e) {
      state = const OnboardingState(isCompleted: false, isLoading: false);
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, true);
      state = state.copyWith(isCompleted: true);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Reset onboarding status (for testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, false);
      state = state.copyWith(isCompleted: false);
    } catch (e) {
      // Handle error silently
    }
  }
}

/// Onboarding provider instance
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
