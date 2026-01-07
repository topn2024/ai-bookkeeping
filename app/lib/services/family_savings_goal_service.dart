import 'package:uuid/uuid.dart';
import '../models/family_savings_goal.dart';

/// 家庭储蓄目标服务
class FamilySavingsGoalService {
  static final FamilySavingsGoalService _instance =
      FamilySavingsGoalService._internal();
  factory FamilySavingsGoalService() => _instance;
  FamilySavingsGoalService._internal();

  final _uuid = const Uuid();

  // 临时存储（实际应使用数据库）
  final Map<String, FamilySavingsGoal> _goals = {};
  final Map<String, List<FamilyGoalContribution>> _contributions = {};

  /// 创建家庭储蓄目标
  Future<FamilySavingsGoal> createGoal({
    required String ledgerId,
    required String name,
    required double targetAmount,
    required String createdBy,
    String? description,
    String emoji = '🎯',
    DateTime? deadline,
    String? coverImage,
  }) async {
    final goalId = _uuid.v4();
    final now = DateTime.now();

    final goal = FamilySavingsGoal(
      id: goalId,
      ledgerId: ledgerId,
      name: name,
      description: description,
      emoji: emoji,
      targetAmount: targetAmount,
      currentAmount: 0,
      deadline: deadline,
      contributors: [],
      status: FamilyGoalStatus.active,
      createdBy: createdBy,
      createdAt: now,
      coverImage: coverImage,
    );

    _goals[goalId] = goal;
    _contributions[goalId] = [];

    return goal;
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
    final goal = _goals[goalId];
    if (goal == null) return null;
    if (!goal.canContribute) return null;

    final now = DateTime.now();
    final contributionId = _uuid.v4();

    // 创建贡献记录
    final contribution = FamilyGoalContribution(
      id: contributionId,
      goalId: goalId,
      contributorId: contributorId,
      contributorName: contributorName,
      amount: amount,
      note: note,
      createdAt: now,
    );

    _contributions.putIfAbsent(goalId, () => []).add(contribution);

    // 更新贡献者列表
    final contributors = List<FamilyGoalContributor>.from(goal.contributors);
    final existingIndex =
        contributors.indexWhere((c) => c.memberId == contributorId);

    if (existingIndex >= 0) {
      // 更新现有贡献者
      final existing = contributors[existingIndex];
      contributors[existingIndex] = existing.copyWith(
        contribution: existing.contribution + amount,
        contributionCount: existing.contributionCount + 1,
        lastContributionAt: now,
      );
    } else {
      // 添加新贡献者
      contributors.add(FamilyGoalContributor(
        memberId: contributorId,
        memberName: contributorName,
        avatarUrl: avatarUrl,
        contribution: amount,
        percentage: 0, // 稍后计算
        contributionCount: 1,
        lastContributionAt: now,
      ));
    }

    // 更新金额
    final newAmount = goal.currentAmount + amount;

    // 重新计算百分比
    final updatedContributors = contributors.map((c) {
      final percentage = newAmount > 0 ? c.contribution / newAmount * 100 : 0.0;
      return c.copyWith(percentage: percentage.toDouble());
    }).toList();

    // 检查是否达成目标
    FamilyGoalStatus newStatus = goal.status;
    DateTime? achievedAt;

    if (newAmount >= goal.targetAmount) {
      newStatus = FamilyGoalStatus.achieved;
      achievedAt = now;
    }

    final updatedGoal = goal.copyWith(
      currentAmount: newAmount,
      contributors: updatedContributors,
      status: newStatus,
      achievedAt: achievedAt,
    );

    _goals[goalId] = updatedGoal;

    return updatedGoal;
  }

  /// 获取目标
  Future<FamilySavingsGoal?> getGoal(String goalId) async {
    return _goals[goalId];
  }

  /// 获取账本的所有目标
  Future<List<FamilySavingsGoal>> getGoalsByLedger(
    String ledgerId, {
    FamilyGoalStatus? status,
    bool includeArchived = false,
  }) async {
    var goals = _goals.values.where((g) => g.ledgerId == ledgerId).toList();

    if (status != null) {
      goals = goals.where((g) => g.status == status).toList();
    }

    // 置顶的排在前面，然后按创建时间倒序
    goals.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return goals;
  }

  /// 获取活跃的目标
  Future<List<FamilySavingsGoal>> getActiveGoals(String ledgerId) async {
    return getGoalsByLedger(ledgerId, status: FamilyGoalStatus.active);
  }

  /// 获取已达成的目标
  Future<List<FamilySavingsGoal>> getAchievedGoals(String ledgerId) async {
    return getGoalsByLedger(ledgerId, status: FamilyGoalStatus.achieved);
  }

  /// 获取目标的贡献记录
  Future<List<FamilyGoalContribution>> getContributions(
    String goalId, {
    int? limit,
  }) async {
    var contributions = _contributions[goalId] ?? [];
    contributions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit != null && contributions.length > limit) {
      contributions = contributions.take(limit).toList();
    }

    return contributions;
  }

  /// 获取成员的贡献记录
  Future<List<FamilyGoalContribution>> getMemberContributions(
    String memberId, {
    String? ledgerId,
  }) async {
    final allContributions = <FamilyGoalContribution>[];

    for (final goalContributions in _contributions.values) {
      for (final contribution in goalContributions) {
        if (contribution.contributorId == memberId) {
          if (ledgerId == null) {
            allContributions.add(contribution);
          } else {
            final goal = _goals[contribution.goalId];
            if (goal?.ledgerId == ledgerId) {
              allContributions.add(contribution);
            }
          }
        }
      }
    }

    allContributions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allContributions;
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
    final goal = _goals[goalId];
    if (goal == null) return null;

    final updatedGoal = goal.copyWith(
      name: name,
      description: description,
      emoji: emoji,
      targetAmount: targetAmount,
      deadline: deadline,
      coverImage: coverImage,
      isPinned: isPinned,
      enableNotifications: enableNotifications,
    );

    _goals[goalId] = updatedGoal;
    return updatedGoal;
  }

  /// 暂停目标
  Future<FamilySavingsGoal?> pauseGoal(String goalId) async {
    final goal = _goals[goalId];
    if (goal == null) return null;
    if (goal.status != FamilyGoalStatus.active) return null;

    final updatedGoal = goal.copyWith(status: FamilyGoalStatus.paused);
    _goals[goalId] = updatedGoal;
    return updatedGoal;
  }

  /// 恢复目标
  Future<FamilySavingsGoal?> resumeGoal(String goalId) async {
    final goal = _goals[goalId];
    if (goal == null) return null;
    if (goal.status != FamilyGoalStatus.paused) return null;

    final updatedGoal = goal.copyWith(status: FamilyGoalStatus.active);
    _goals[goalId] = updatedGoal;
    return updatedGoal;
  }

  /// 取消目标
  Future<FamilySavingsGoal?> cancelGoal(String goalId) async {
    final goal = _goals[goalId];
    if (goal == null) return null;
    if (goal.status == FamilyGoalStatus.achieved ||
        goal.status == FamilyGoalStatus.cancelled) {
      return null;
    }

    final updatedGoal = goal.copyWith(status: FamilyGoalStatus.cancelled);
    _goals[goalId] = updatedGoal;
    return updatedGoal;
  }

  /// 删除目标
  Future<bool> deleteGoal(String goalId) async {
    if (_goals.containsKey(goalId)) {
      _goals.remove(goalId);
      _contributions.remove(goalId);
      return true;
    }
    return false;
  }

  /// 切换置顶状态
  Future<FamilySavingsGoal?> togglePin(String goalId) async {
    final goal = _goals[goalId];
    if (goal == null) return null;

    final updatedGoal = goal.copyWith(isPinned: !goal.isPinned);
    _goals[goalId] = updatedGoal;
    return updatedGoal;
  }

  /// 检查里程碑
  Future<FamilyGoalMilestone?> checkMilestone(String goalId) async {
    final goal = _goals[goalId];
    if (goal == null) return null;

    final milestones = FamilyGoalMilestone.defaultMilestones(goal.targetAmount);
    final progress = goal.progressPercentage;

    // 找到刚刚达成的里程碑
    for (final milestone in milestones) {
      if (progress >= milestone.percentage && !milestone.isReached) {
        return FamilyGoalMilestone(
          percentage: milestone.percentage,
          amount: milestone.amount,
          isReached: true,
          reachedAt: DateTime.now(),
          celebrationMessage: milestone.celebrationMessage,
        );
      }
    }

    return null;
  }

  /// 获取目标统计
  Future<FamilyGoalStatistics> getGoalStatistics(String ledgerId) async {
    final goals = await getGoalsByLedger(ledgerId);

    int activeCount = 0;
    int achievedCount = 0;
    double totalTarget = 0;
    double totalProgress = 0;

    for (final goal in goals) {
      switch (goal.status) {
        case FamilyGoalStatus.active:
          activeCount++;
          break;
        case FamilyGoalStatus.achieved:
          achievedCount++;
          break;
        default:
          break;
      }
      totalTarget += goal.targetAmount;
      totalProgress += goal.currentAmount;
    }

    return FamilyGoalStatistics(
      totalGoals: goals.length,
      activeGoals: activeCount,
      achievedGoals: achievedCount,
      totalTargetAmount: totalTarget,
      totalProgressAmount: totalProgress,
      overallProgress: totalTarget > 0 ? totalProgress / totalTarget * 100 : 0,
    );
  }

  /// 清空数据（测试用）
  void clearAll() {
    _goals.clear();
    _contributions.clear();
  }
}

/// 家庭目标统计
class FamilyGoalStatistics {
  final int totalGoals;
  final int activeGoals;
  final int achievedGoals;
  final double totalTargetAmount;
  final double totalProgressAmount;
  final double overallProgress;

  const FamilyGoalStatistics({
    required this.totalGoals,
    required this.activeGoals,
    required this.achievedGoals,
    required this.totalTargetAmount,
    required this.totalProgressAmount,
    required this.overallProgress,
  });
}
