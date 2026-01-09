import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/smart_feature_recommendation_page.dart';
import '../services/feature_recommendation_service.dart';
import 'transaction_provider.dart';
import 'budget_provider.dart';
import 'savings_goal_provider.dart';

final featureRecommendationServiceProvider = Provider<FeatureRecommendationService>((ref) {
  return FeatureRecommendationService();
});

final featureRecommendationProvider = Provider<List<FeatureRecommendation>>((ref) {
  final service = ref.watch(featureRecommendationServiceProvider);

  final transactions = ref.watch(transactionProvider);
  final budgets = ref.watch(budgetProvider);
  final savingsGoals = ref.watch(savingsGoalProvider);

  // Check if features are enabled
  final hasBudget = budgets.isNotEmpty;
  final hasSavingsGoal = savingsGoals.where((g) => !g.isArchived).isNotEmpty;

  // For now, assume money age is not enabled
  // In a real implementation, this would check if money age data exists
  final hasMoneyAge = false;

  return service.generateRecommendations(
    transactions: transactions,
    hasBudget: hasBudget,
    hasMoneyAge: hasMoneyAge,
    hasSavingsGoal: hasSavingsGoal,
  );
});
