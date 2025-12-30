import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import 'base/crud_notifier.dart';
import 'transaction_provider.dart';

/// 储蓄目标管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class SavingsGoalNotifier extends SimpleCrudNotifier<SavingsGoal, String> {
  @override
  String get tableName => 'savings_goals';

  @override
  String getId(SavingsGoal entity) => entity.id;

  @override
  Future<List<SavingsGoal>> fetchAll() => db.getSavingsGoals();

  @override
  Future<void> insertOne(SavingsGoal entity) => db.insertSavingsGoal(entity);

  @override
  Future<void> updateOne(SavingsGoal entity) => db.updateSavingsGoal(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteSavingsGoal(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加储蓄目标（保持原有方法名兼容）
  Future<void> addGoal(SavingsGoal goal) => add(goal);

  /// 更新储蓄目标（保持原有方法名兼容）
  Future<void> updateGoal(SavingsGoal goal) => update(goal);

  /// 删除储蓄目标（保持原有方法名兼容）
  Future<void> deleteGoal(String id) => delete(id);

  /// 添加存款到目标
  Future<void> addDeposit(String goalId, double amount, {String? note}) async {
    final goal = state.firstWhere((g) => g.id == goalId);
    final newAmount = goal.currentAmount + amount;
    final isNowComplete = newAmount >= goal.targetAmount && !goal.isCompleted;

    // 如果是定期存款目标，更新下次存款日期
    DateTime? nextDepositDate = goal.nextDepositDate;
    if (goal.isRecurring && goal.recurringFrequency != null) {
      nextDepositDate = goal.recurringFrequency!.getNextDate(DateTime.now());
    }

    final updated = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: isNowComplete ? true : goal.isCompleted,
      completedAt: isNowComplete ? DateTime.now() : goal.completedAt,
      nextDepositDate: nextDepositDate,
    );

    await updateGoal(updated);

    // 记录存款历史
    await db.insertSavingsDeposit(SavingsDeposit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goalId: goalId,
      amount: amount,
      note: note,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    ));
  }

  /// 从目标取出金额
  Future<void> withdrawAmount(String goalId, double amount) async {
    final goal = state.firstWhere((g) => g.id == goalId);
    final newAmount = (goal.currentAmount - amount).clamp(0.0, double.infinity);

    final updated = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: newAmount >= goal.targetAmount,
    );

    await updateGoal(updated);
  }

  /// 标记目标为已完成
  Future<void> markAsCompleted(String id) async {
    final goal = state.firstWhere((g) => g.id == id);
    final updated = goal.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    await updateGoal(updated);
  }

  /// 归档目标
  Future<void> archiveGoal(String id) async {
    final goal = state.firstWhere((g) => g.id == id);
    final updated = goal.copyWith(isArchived: true);
    await updateGoal(updated);
  }

  /// 取消归档
  Future<void> unarchiveGoal(String id) async {
    final goal = state.firstWhere((g) => g.id == id);
    final updated = goal.copyWith(isArchived: false);
    await updateGoal(updated);
  }

  /// 获取存款历史
  Future<List<SavingsDeposit>> getDepositHistory(String goalId) async {
    return await db.getSavingsDeposits(goalId);
  }

  /// 获取活跃目标（未归档）
  List<SavingsGoal> get activeGoals =>
      state.where((g) => !g.isArchived).toList();

  /// 获取已完成目标
  List<SavingsGoal> get completedGoals =>
      state.where((g) => g.isCompleted && !g.isArchived).toList();

  /// 获取进行中目标
  List<SavingsGoal> get inProgressGoals =>
      state.where((g) => !g.isCompleted && !g.isArchived).toList();

  /// 获取已归档目标
  List<SavingsGoal> get archivedGoals =>
      state.where((g) => g.isArchived).toList();

  /// 获取即将到期的目标（7天内）
  List<SavingsGoal> get goalsDueSoon =>
      state.where((g) {
        if (g.isCompleted || g.isArchived) return false;
        final days = g.daysRemaining;
        return days != null && days >= 0 && days <= 7;
      }).toList();

  /// 获取已过期目标
  List<SavingsGoal> get overdueGoals =>
      state.where((g) => g.isOverdue && !g.isArchived).toList();

  /// 获取月度开支控制目标
  List<SavingsGoal> get expenseControlGoals =>
      state.where((g) => g.type == SavingsGoalType.expense && !g.isArchived).toList();

  /// 获取定期存款目标
  List<SavingsGoal> get recurringGoals =>
      state.where((g) => g.isRecurring && !g.isArchived && !g.isCompleted).toList();

  /// 获取今日需要存款的目标
  List<SavingsGoal> get goalsNeedingDeposit =>
      state.where((g) => g.depositDueToday && !g.isArchived && !g.isCompleted).toList();

  /// 总目标金额
  double get totalTargetAmount =>
      activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount);

  /// 总已存金额
  double get totalCurrentAmount =>
      activeGoals.fold(0.0, (sum, g) => sum + g.currentAmount);

  /// 总体进度
  double get overallProgress =>
      totalTargetAmount > 0 ? totalCurrentAmount / totalTargetAmount : 0;

  @override
  SavingsGoal? getById(String id) {
    try {
      return state.firstWhere((g) => g.id == id);
    } catch (e) {
      return null;
    }
  }
}

final savingsGoalProvider =
    NotifierProvider<SavingsGoalNotifier, List<SavingsGoal>>(
        SavingsGoalNotifier.new);

/// 活跃目标Provider
final activeGoalsProvider = Provider<List<SavingsGoal>>((ref) {
  final notifier = ref.watch(savingsGoalProvider.notifier);
  return notifier.activeGoals;
});

/// 进行中目标Provider
final inProgressGoalsProvider = Provider<List<SavingsGoal>>((ref) {
  final notifier = ref.watch(savingsGoalProvider.notifier);
  return notifier.inProgressGoals;
});

/// 储蓄目标汇总信息
class SavingsGoalSummary {
  final double totalTarget;
  final double totalSaved;
  final double overallProgress;
  final int activeCount;
  final int completedCount;
  final int overdueCount;

  SavingsGoalSummary({
    required this.totalTarget,
    required this.totalSaved,
    required this.overallProgress,
    required this.activeCount,
    required this.completedCount,
    required this.overdueCount,
  });

  double get remainingAmount => totalTarget - totalSaved;
}

final savingsGoalSummaryProvider = Provider<SavingsGoalSummary>((ref) {
  final goals = ref.watch(savingsGoalProvider);
  final activeGoals = goals.where((g) => !g.isArchived).toList();

  return SavingsGoalSummary(
    totalTarget: activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount),
    totalSaved: activeGoals.fold(0.0, (sum, g) => sum + g.currentAmount),
    overallProgress: activeGoals.isEmpty
        ? 0
        : activeGoals.fold(0.0, (sum, g) => sum + g.currentAmount) /
            activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount),
    activeCount: activeGoals.where((g) => !g.isCompleted).length,
    completedCount: activeGoals.where((g) => g.isCompleted).length,
    overdueCount: activeGoals.where((g) => g.isOverdue).length,
  );
});

// ============== 月度开支目标相关 Provider ==============

/// 月度开支跟踪数据
class MonthlyExpenseTracking {
  final SavingsGoal goal;
  final double monthlyLimit;      // 月度限额
  final double currentSpent;      // 当前已花费
  final double remaining;         // 剩余额度
  final double percentage;        // 使用百分比
  final int daysInMonth;          // 本月天数
  final int daysPassed;           // 已过天数
  final double dailyAverage;      // 日均开支
  final double suggestedDaily;    // 建议日均开支（剩余额度/剩余天数）

  MonthlyExpenseTracking({
    required this.goal,
    required this.monthlyLimit,
    required this.currentSpent,
    required this.remaining,
    required this.percentage,
    required this.daysInMonth,
    required this.daysPassed,
    required this.dailyAverage,
    required this.suggestedDaily,
  });

  bool get isOverBudget => currentSpent > monthlyLimit;
  bool get isNearLimit => percentage >= 0.8 && !isOverBudget;
  bool get isOnTrack => dailyAverage <= suggestedDaily;
}

/// 获取特定月度开支目标的跟踪数据
final monthlyExpenseTrackingProvider = Provider.family<MonthlyExpenseTracking?, String>((ref, goalId) {
  final goals = ref.watch(savingsGoalProvider);
  final transactions = ref.watch(transactionProvider);

  final goal = goals.where((g) => g.id == goalId).firstOrNull;
  if (goal == null || goal.type != SavingsGoalType.expense) return null;

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);
  final daysInMonth = monthEnd.day;
  final daysPassed = now.day;

  // 计算本月该分类的开支
  double currentSpent = 0;
  if (goal.linkedCategoryId != null) {
    // 如果关联了分类，只统计该分类的开支
    currentSpent = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.category == goal.linkedCategoryId &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  } else {
    // 如果没有关联分类，统计所有开支
    currentSpent = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  final monthlyLimit = goal.monthlyExpenseLimit ?? goal.targetAmount;
  final remaining = (monthlyLimit - currentSpent).clamp(0.0, double.infinity);
  final percentage = monthlyLimit > 0 ? currentSpent / monthlyLimit : 0.0;
  final dailyAverage = daysPassed > 0 ? currentSpent / daysPassed : 0.0;
  final daysRemaining = daysInMonth - daysPassed;
  final suggestedDaily = daysRemaining > 0 ? remaining / daysRemaining : 0.0;

  return MonthlyExpenseTracking(
    goal: goal,
    monthlyLimit: monthlyLimit,
    currentSpent: currentSpent,
    remaining: remaining,
    percentage: percentage,
    daysInMonth: daysInMonth,
    daysPassed: daysPassed,
    dailyAverage: dailyAverage,
    suggestedDaily: suggestedDaily,
  );
});

/// 获取所有月度开支跟踪目标
final allExpenseTrackingsProvider = Provider<List<MonthlyExpenseTracking>>((ref) {
  final goals = ref.watch(savingsGoalProvider);
  final expenseGoals = goals.where((g) =>
      g.type == SavingsGoalType.expense && !g.isArchived).toList();

  return expenseGoals
      .map((goal) => ref.watch(monthlyExpenseTrackingProvider(goal.id)))
      .whereType<MonthlyExpenseTracking>()
      .toList();
});

// ============== 定期存款目标相关 Provider ==============

/// 定期存款进度数据
class RecurringDepositProgress {
  final SavingsGoal goal;
  final double recurringAmount;     // 每次存款金额
  final int totalDeposits;          // 累计存款次数
  final int expectedDeposits;       // 预期存款次数（到目前为止）
  final bool isOnSchedule;          // 是否按计划存款
  final DateTime? nextDepositDate;  // 下次存款日期
  final int? daysUntilNext;         // 距离下次存款天数

  RecurringDepositProgress({
    required this.goal,
    required this.recurringAmount,
    required this.totalDeposits,
    required this.expectedDeposits,
    required this.isOnSchedule,
    this.nextDepositDate,
    this.daysUntilNext,
  });

  bool get depositDueToday => daysUntilNext != null && daysUntilNext! <= 0;
}

/// 获取定期存款目标的进度
final recurringDepositProgressProvider = Provider.family<RecurringDepositProgress?, String>((ref, goalId) {
  final goals = ref.watch(savingsGoalProvider);

  final goal = goals.where((g) => g.id == goalId).firstOrNull;
  if (goal == null || !goal.isRecurring) return null;

  final recurringAmount = goal.recurringAmount ?? 0;
  final totalDeposits = recurringAmount > 0
      ? (goal.currentAmount / recurringAmount).floor()
      : 0;

  // 计算从开始到现在预期应该存了多少次
  int expectedDeposits = 0;
  if (goal.recurringFrequency != null) {
    final daysSinceStart = DateTime.now().difference(goal.startDate).inDays;
    switch (goal.recurringFrequency!) {
      case SavingsFrequency.daily:
        expectedDeposits = daysSinceStart;
        break;
      case SavingsFrequency.weekly:
        expectedDeposits = daysSinceStart ~/ 7;
        break;
      case SavingsFrequency.biweekly:
        expectedDeposits = daysSinceStart ~/ 14;
        break;
      case SavingsFrequency.monthly:
        final monthsDiff = (DateTime.now().year - goal.startDate.year) * 12 +
            (DateTime.now().month - goal.startDate.month);
        expectedDeposits = monthsDiff;
        break;
    }
  }

  return RecurringDepositProgress(
    goal: goal,
    recurringAmount: recurringAmount,
    totalDeposits: totalDeposits,
    expectedDeposits: expectedDeposits,
    isOnSchedule: totalDeposits >= expectedDeposits,
    nextDepositDate: goal.nextDepositDate,
    daysUntilNext: goal.daysUntilNextDeposit,
  );
});

/// 获取所有定期存款进度
final allRecurringProgressProvider = Provider<List<RecurringDepositProgress>>((ref) {
  final goals = ref.watch(savingsGoalProvider);
  final recurringGoals = goals.where((g) =>
      g.isRecurring && !g.isArchived && !g.isCompleted).toList();

  return recurringGoals
      .map((goal) => ref.watch(recurringDepositProgressProvider(goal.id)))
      .whereType<RecurringDepositProgress>()
      .toList();
});

/// 今日需要存款的目标
final depositDueTodayProvider = Provider<List<SavingsGoal>>((ref) {
  final goals = ref.watch(savingsGoalProvider);
  return goals.where((g) => g.depositDueToday && !g.isArchived && !g.isCompleted).toList();
});
