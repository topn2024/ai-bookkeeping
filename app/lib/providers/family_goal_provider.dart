import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_savings_goal.dart';
import '../services/family_savings_goal_service.dart';

/// FamilySavingsGoalService Provider
final familySavingsGoalServiceProvider =
    Provider<FamilySavingsGoalService>((ref) {
  return FamilySavingsGoalService();
});

/// 家庭目标列表状态
class FamilyGoalListState {
  final List<FamilySavingsGoal> goals;
  final bool isLoading;
  final String? error;
  final String? ledgerId;

  const FamilyGoalListState({
    this.goals = const [],
    this.isLoading = false,
    this.error,
    this.ledgerId,
  });

  FamilyGoalListState copyWith({
    List<FamilySavingsGoal>? goals,
    bool? isLoading,
    String? error,
    String? ledgerId,
  }) {
    return FamilyGoalListState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      ledgerId: ledgerId ?? this.ledgerId,
    );
  }

  /// 活跃目标
  List<FamilySavingsGoal> get activeGoals =>
      goals.where((g) => g.status == FamilyGoalStatus.active).toList();

  /// 已达成目标
  List<FamilySavingsGoal> get achievedGoals =>
      goals.where((g) => g.status == FamilyGoalStatus.achieved).toList();

  /// 置顶目标
  List<FamilySavingsGoal> get pinnedGoals =>
      goals.where((g) => g.isPinned).toList();
}

/// 家庭目标列表 Notifier
class FamilyGoalListNotifier extends Notifier<FamilyGoalListState> {
  @override
  FamilyGoalListState build() {
    return const FamilyGoalListState();
  }

  FamilySavingsGoalService get _goalService =>
      ref.read(familySavingsGoalServiceProvider);

  /// 加载账本的目标
  Future<void> loadGoals(String ledgerId) async {
    state = state.copyWith(isLoading: true, ledgerId: ledgerId);
    try {
      final goals = await _goalService.getGoalsByLedger(ledgerId);
      state = state.copyWith(goals: goals, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建目标
  Future<FamilySavingsGoal?> createGoal({
    required String ledgerId,
    required String name,
    required double targetAmount,
    required String createdBy,
    String? description,
    String emoji = '🎯',
    DateTime? deadline,
    String? coverImage,
  }) async {
    try {
      final goal = await _goalService.createGoal(
        ledgerId: ledgerId,
        name: name,
        targetAmount: targetAmount,
        createdBy: createdBy,
        description: description,
        emoji: emoji,
        deadline: deadline,
        coverImage: coverImage,
      );

      if (state.ledgerId == ledgerId) {
        state = state.copyWith(goals: [goal, ...state.goals]);
      }

      return goal;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 贡献金额
  Future<FamilySavingsGoal?> contribute({
    required String goalId,
    required String contributorId,
    required String contributorName,
    required double amount,
    String? avatarUrl,
    String? note,
  }) async {
    try {
      final updatedGoal = await _goalService.contribute(
        goalId: goalId,
        contributorId: contributorId,
        contributorName: contributorName,
        amount: amount,
        avatarUrl: avatarUrl,
        note: note,
      );

      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
      }

      return updatedGoal;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 更新目标
  Future<FamilySavingsGoal?> updateGoal(
    String goalId, {
    String? name,
    String? description,
    String? emoji,
    double? targetAmount,
    DateTime? deadline,
    String? coverImage,
    bool? isPinned,
    bool? enableNotifications,
  }) async {
    try {
      final updatedGoal = await _goalService.updateGoal(
        goalId,
        name: name,
        description: description,
        emoji: emoji,
        targetAmount: targetAmount,
        deadline: deadline,
        coverImage: coverImage,
        isPinned: isPinned,
        enableNotifications: enableNotifications,
      );

      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
      }

      return updatedGoal;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 暂停目标
  Future<bool> pauseGoal(String goalId) async {
    try {
      final updatedGoal = await _goalService.pauseGoal(goalId);
      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 恢复目标
  Future<bool> resumeGoal(String goalId) async {
    try {
      final updatedGoal = await _goalService.resumeGoal(goalId);
      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 取消目标
  Future<bool> cancelGoal(String goalId) async {
    try {
      final updatedGoal = await _goalService.cancelGoal(goalId);
      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 删除目标
  Future<bool> deleteGoal(String goalId) async {
    try {
      final success = await _goalService.deleteGoal(goalId);
      if (success) {
        final updatedGoals = state.goals.where((g) => g.id != goalId).toList();
        state = state.copyWith(goals: updatedGoals);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 切换置顶
  Future<bool> togglePin(String goalId) async {
    try {
      final updatedGoal = await _goalService.togglePin(goalId);
      if (updatedGoal != null) {
        final updatedGoals = state.goals.map((g) {
          return g.id == goalId ? updatedGoal : g;
        }).toList();
        state = state.copyWith(goals: updatedGoals);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 家庭目标列表 Provider
final familyGoalListProvider =
    NotifierProvider<FamilyGoalListNotifier, FamilyGoalListState>(
        FamilyGoalListNotifier.new);

/// 单个目标 Provider
final familyGoalProvider =
    FutureProvider.family<FamilySavingsGoal?, String>((ref, goalId) async {
  final goalService = ref.watch(familySavingsGoalServiceProvider);
  return goalService.getGoal(goalId);
});

/// 目标贡献记录 Provider
final goalContributionsProvider =
    FutureProvider.family<List<FamilyGoalContribution>, String>(
        (ref, goalId) async {
  final goalService = ref.watch(familySavingsGoalServiceProvider);
  return goalService.getContributions(goalId);
});

/// 目标统计 Provider
final familyGoalStatisticsProvider =
    FutureProvider.family<FamilyGoalStatistics, String>(
        (ref, ledgerId) async {
  final goalService = ref.watch(familySavingsGoalServiceProvider);
  return goalService.getGoalStatistics(ledgerId);
});
