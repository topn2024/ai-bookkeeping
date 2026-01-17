import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';
import '../services/voice_navigation_executor.dart';
import 'onboarding_welcome_page.dart';
import 'onboarding_features_page.dart';
import 'onboarding_first_transaction_page.dart';
import 'onboarding_complete_page.dart';
import 'enhanced_voice_assistant_page.dart';
import 'budget_management_page.dart';
import 'import_page.dart';

/// Onboarding flow coordinator
/// Manages navigation through the onboarding pages
class OnboardingFlowPage extends ConsumerStatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  ConsumerState<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends ConsumerState<OnboardingFlowPage> {
  int _currentStep = 0;

  void _goToNextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _skipToComplete() {
    setState(() {
      _currentStep = 3; // Jump to complete page
    });
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as completed
    // main.dart will automatically switch to MainNavigation based on state change
    await ref.read(onboardingProvider.notifier).completeOnboarding();
  }

  Future<void> _completeAndNavigateToVoice() async {
    // Mark onboarding as completed first
    await ref.read(onboardingProvider.notifier).completeOnboarding();

    // Wait for state change to propagate, then navigate using global navigator
    await Future.delayed(const Duration(milliseconds: 100));
    final navigatorKey = VoiceNavigationExecutor.instance.navigatorKey;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const EnhancedVoiceAssistantPage()),
    );
  }

  Future<void> _completeAndNavigateToBudget() async {
    // Mark onboarding as completed first
    await ref.read(onboardingProvider.notifier).completeOnboarding();

    // Wait for state change to propagate, then navigate using global navigator
    await Future.delayed(const Duration(milliseconds: 100));
    final navigatorKey = VoiceNavigationExecutor.instance.navigatorKey;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
    );
  }

  Future<void> _completeAndNavigateToImport() async {
    // Mark onboarding as completed first
    await ref.read(onboardingProvider.notifier).completeOnboarding();

    // Wait for state change to propagate, then navigate using global navigator
    await Future.delayed(const Duration(milliseconds: 100));
    final navigatorKey = VoiceNavigationExecutor.instance.navigatorKey;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ImportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_currentStep) {
      0 => OnboardingWelcomePage(onNext: _goToNextStep),
      1 => OnboardingFeaturesPage(
          onNext: _goToNextStep,
          onSkip: _skipToComplete,
        ),
      2 => OnboardingFirstTransactionPage(
          onComplete: _goToNextStep,
          onSkip: _skipToComplete,
        ),
      3 => OnboardingCompletePage(
          onGoHome: _completeOnboarding,
          onTryVoice: _completeAndNavigateToVoice,
          onSetBudget: _completeAndNavigateToBudget,
          onImportBills: _completeAndNavigateToImport,
        ),
      _ => OnboardingWelcomePage(onNext: _goToNextStep),
    };
  }
}
