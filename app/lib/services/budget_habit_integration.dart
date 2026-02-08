import '../models/budget_vault.dart';
import 'vault_repository.dart';

/// 习惯任务类别
enum HabitCategory {
  /// 储蓄类
  savings,

  /// 消费控制类
  spending,

  /// 预算执行类
  budgeting,

  /// 记账习惯类
  recording,
}

extension HabitCategoryExtension on HabitCategory {
  String get displayName {
    switch (this) {
      case HabitCategory.savings:
        return '储蓄挑战';
      case HabitCategory.spending:
        return '节约挑战';
      case HabitCategory.budgeting:
        return '预算挑战';
      case HabitCategory.recording:
        return '记账习惯';
    }
  }

  String get iconName {
    switch (this) {
      case HabitCategory.savings:
        return 'savings';
      case HabitCategory.spending:
        return 'trending_down';
      case HabitCategory.budgeting:
        return 'account_balance_wallet';
      case HabitCategory.recording:
        return 'edit_note';
    }
  }
}

/// 习惯任务
class HabitTask {
  final String id;
  final String title;
  final String description;
  final int reward;
  final HabitCategory category;
  final DateTime? deadline;
  final double? targetAmount;
  final double? currentProgress;
  final bool isCompleted;
  final String? relatedVaultId;

  const HabitTask({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.category,
    this.deadline,
    this.targetAmount,
    this.currentProgress,
    this.isCompleted = false,
    this.relatedVaultId,
  });

  double get progressPercentage {
    if (targetAmount == null || targetAmount == 0) return 0;
    if (currentProgress == null) return 0;
    return (currentProgress! / targetAmount!).clamp(0.0, 1.0);
  }

  HabitTask copyWith({
    double? currentProgress,
    bool? isCompleted,
  }) {
    return HabitTask(
      id: id,
      title: title,
      description: description,
      reward: reward,
      category: category,
      deadline: deadline,
      targetAmount: targetAmount,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      relatedVaultId: relatedVaultId,
    );
  }
}

/// 习惯成就
class HabitAchievement {
  final String id;
  final String title;
  final String description;
  final int points;
  final DateTime achievedAt;
  final String? iconName;

  const HabitAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.achievedAt,
    this.iconName,
  });
}

/// 习惯任务服务接口
abstract class HabitTaskService {
  Future<void> completeTask(String taskId);
  Future<void> awardPoints(int points);
  Future<int> getTotalPoints();
  Future<List<HabitAchievement>> getAchievements();
}

/// 预算习惯集成统计
class BudgetHabitStats {
  final int totalTasks;
  final int completedTasks;
  final int totalPointsEarned;
  final int currentStreak;
  final int longestStreak;
  final List<HabitAchievement> recentAchievements;

  const BudgetHabitStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalPointsEarned,
    required this.currentStreak,
    required this.longestStreak,
    required this.recentAchievements,
  });

  double get completionRate =>
      totalTasks > 0 ? completedTasks / totalTasks : 0;
}

/// 预算系统与习惯培养的集成服务
///
/// 将预算执行转化为习惯任务，通过游戏化机制激励用户
/// - 储蓄目标 → 储蓄挑战任务
/// - 超支小金库 → 节约挑战任务
/// - 预算达标 → 成就奖励
class BudgetHabitIntegration {
  final VaultRepository _vaultRepo;
  final HabitTaskService? _habitService;

  // 内部状态
  int _totalPointsAwarded = 0;
  final List<HabitAchievement> _achievements = [];
  final Map<String, bool> _completedTasks = {};

  BudgetHabitIntegration(
    this._vaultRepo, [
    this._habitService,
  ]);

  /// 生成预算相关的习惯任务
  Future<List<HabitTask>> generateBudgetTasks() async {
    final vaults = await _vaultRepo.getEnabled();
    final tasks = <HabitTask>[];

    for (final vault in vaults) {
      // 储蓄目标类小金库 → 储蓄挑战任务
      if (vault.type == VaultType.savings && vault.progress < 1.0) {
        final remaining = vault.targetAmount - vault.allocatedAmount;
        tasks.add(HabitTask(
          id: 'savings_${vault.id}',
          title: '${vault.name}储蓄挑战',
          description: '距离目标还差¥${remaining.toStringAsFixed(0)}',
          reward: _calculateSavingsReward(vault),
          category: HabitCategory.savings,
          targetAmount: vault.targetAmount,
          currentProgress: vault.allocatedAmount,
          isCompleted: _completedTasks['savings_${vault.id}'] ?? false,
          relatedVaultId: vault.id,
        ));
      }

      // 弹性支出类小金库超支 → 节约挑战任务
      if (vault.type == VaultType.flexible && vault.isOverSpent) {
        tasks.add(HabitTask(
          id: 'reduce_${vault.id}',
          title: '${vault.name}节约挑战',
          description: '本月${vault.name}超支¥${(-vault.available).toStringAsFixed(0)}',
          reward: 20,
          category: HabitCategory.spending,
          targetAmount: vault.allocatedAmount,
          currentProgress: vault.allocatedAmount - vault.spentAmount.abs(),
          isCompleted: _completedTasks['reduce_${vault.id}'] ?? false,
          relatedVaultId: vault.id,
        ));
      }

      // 即将用完的小金库 → 预算控制任务
      if (vault.usageRate > 0.8 && vault.usageRate < 1.0) {
        final daysRemaining = _getDaysRemainingInMonth();
        tasks.add(HabitTask(
          id: 'control_${vault.id}',
          title: '${vault.name}控制挑战',
          description: '剩余¥${vault.available.toStringAsFixed(0)}要撑$daysRemaining天',
          reward: 15,
          category: HabitCategory.budgeting,
          deadline: _getEndOfMonth(),
          isCompleted: _completedTasks['control_${vault.id}'] ?? false,
          relatedVaultId: vault.id,
        ));
      }

      // 健康的小金库 → 保持任务
      if (vault.status == VaultStatus.healthy && vault.usageRate < 0.5) {
        tasks.add(HabitTask(
          id: 'maintain_${vault.id}',
          title: '保持${vault.name}健康',
          description: '继续保持当前的消费节奏',
          reward: 10,
          category: HabitCategory.budgeting,
          isCompleted: _completedTasks['maintain_${vault.id}'] ?? false,
          relatedVaultId: vault.id,
        ));
      }
    }

    // 添加通用任务
    tasks.addAll(_generateGeneralTasks(vaults));

    return tasks;
  }

  /// 生成通用习惯任务
  List<HabitTask> _generateGeneralTasks(List<BudgetVault> vaults) {
    final tasks = <HabitTask>[];

    // 月度储蓄挑战
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings);
    if (savingsVaults.isNotEmpty) {
      final totalSavings = savingsVaults.fold(
        0.0,
        (sum, v) => sum + v.allocatedAmount,
      );
      final totalTarget = savingsVaults.fold(
        0.0,
        (sum, v) => sum + v.targetAmount,
      );

      tasks.add(HabitTask(
        id: 'monthly_savings',
        title: '月度储蓄目标',
        description: '本月已储蓄¥${totalSavings.toStringAsFixed(0)}',
        reward: 50,
        category: HabitCategory.savings,
        targetAmount: totalTarget,
        currentProgress: totalSavings,
        deadline: _getEndOfMonth(),
        isCompleted: _completedTasks['monthly_savings'] ?? false,
      ));
    }

    // 无超支挑战
    final overspentCount = vaults.where((v) => v.isOverSpent).length;
    if (overspentCount == 0) {
      tasks.add(HabitTask(
        id: 'no_overspent',
        title: '零超支挑战',
        description: '本月所有小金库都没有超支，太棒了！',
        reward: 30,
        category: HabitCategory.budgeting,
        isCompleted: true, // 已达成
      ));
    }

    // 预算执行挑战
    final healthyVaults = vaults.where((v) => v.status == VaultStatus.healthy);
    tasks.add(HabitTask(
      id: 'budget_execution',
      title: '预算执行挑战',
      description: '${healthyVaults.length}/${vaults.length}个小金库状态健康',
      reward: 25,
      category: HabitCategory.budgeting,
      targetAmount: vaults.length.toDouble(),
      currentProgress: healthyVaults.length.toDouble(),
      isCompleted: healthyVaults.length == vaults.length,
    ));

    return tasks;
  }

  /// 预算完成时发放奖励
  Future<HabitAchievement?> onBudgetAchieved(BudgetVault vault) async {
    HabitAchievement? achievement;

    if (vault.type == VaultType.savings && vault.progress >= 1.0) {
      // 储蓄目标达成
      final taskId = 'savings_${vault.id}';
      _completedTasks[taskId] = true;

      if (_habitService != null) {
        await _habitService.completeTask(taskId);
        await _habitService.awardPoints(50);
      }
      _totalPointsAwarded += 50;

      achievement = HabitAchievement(
        id: 'savings_achieved_${vault.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: '储蓄目标达成！',
        description: '${vault.name}已成功积累¥${vault.targetAmount.toStringAsFixed(0)}',
        points: 50,
        achievedAt: DateTime.now(),
        iconName: 'emoji_events',
      );
      _achievements.add(achievement);
    }

    return achievement;
  }

  /// 预算超支时的处理
  Future<HabitTask?> onBudgetOverspent(BudgetVault vault) async {
    if (vault.type == VaultType.flexible) {
      // 生成节约挑战
      return HabitTask(
        id: 'recovery_${vault.id}',
        title: '${vault.name}恢复挑战',
        description: '下月减少${vault.name}支出10%',
        reward: 25,
        category: HabitCategory.spending,
        relatedVaultId: vault.id,
      );
    }
    return null;
  }

  /// 每日签到奖励
  Future<int> dailyCheckIn() async {
    const dailyPoints = 5;

    if (_habitService != null) {
      await _habitService.awardPoints(dailyPoints);
    }
    _totalPointsAwarded += dailyPoints;

    return dailyPoints;
  }

  /// 检查并颁发成就
  Future<List<HabitAchievement>> checkAndAwardAchievements() async {
    final newAchievements = <HabitAchievement>[];
    final vaults = await _vaultRepo.getEnabled();

    // 首次储蓄成就
    final savingsVaults = vaults.where(
      (v) => v.type == VaultType.savings && v.allocatedAmount > 0,
    );
    if (savingsVaults.isNotEmpty &&
        !_hasAchievement('first_savings')) {
      final achievement = HabitAchievement(
        id: 'first_savings',
        title: '储蓄新手',
        description: '开始了第一笔储蓄',
        points: 20,
        achievedAt: DateTime.now(),
        iconName: 'star',
      );
      _achievements.add(achievement);
      newAchievements.add(achievement);
    }

    // 全预算健康成就
    final allHealthy = vaults.every(
      (v) => v.status == VaultStatus.healthy,
    );
    if (allHealthy &&
        vaults.isNotEmpty &&
        !_hasAchievement('all_healthy')) {
      final achievement = HabitAchievement(
        id: 'all_healthy',
        title: '预算大师',
        description: '所有小金库都保持健康状态',
        points: 100,
        achievedAt: DateTime.now(),
        iconName: 'workspace_premium',
      );
      _achievements.add(achievement);
      newAchievements.add(achievement);
    }

    // 高储蓄率成就
    final totalAllocated = vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final savingsAllocated = savingsVaults.fold(
      0.0,
      (sum, v) => sum + v.allocatedAmount,
    );
    if (totalAllocated > 0 &&
        savingsAllocated / totalAllocated > 0.3 &&
        !_hasAchievement('high_savings_rate')) {
      final achievement = HabitAchievement(
        id: 'high_savings_rate',
        title: '储蓄达人',
        description: '储蓄占比超过30%',
        points: 50,
        achievedAt: DateTime.now(),
        iconName: 'savings',
      );
      _achievements.add(achievement);
      newAchievements.add(achievement);
    }

    // 连续无超支成就
    final hasOverspent = vaults.any((v) => v.isOverSpent);
    if (!hasOverspent && !_hasAchievement('no_overspent_month')) {
      final achievement = HabitAchievement(
        id: 'no_overspent_month',
        title: '消费控制者',
        description: '本月没有任何小金库超支',
        points: 40,
        achievedAt: DateTime.now(),
        iconName: 'verified',
      );
      _achievements.add(achievement);
      newAchievements.add(achievement);
    }

    return newAchievements;
  }

  /// 获取习惯统计
  Future<BudgetHabitStats> getStats() async {
    final tasks = await generateBudgetTasks();
    final completedCount = tasks.where((t) => t.isCompleted).length;

    return BudgetHabitStats(
      totalTasks: tasks.length,
      completedTasks: completedCount,
      totalPointsEarned: _totalPointsAwarded,
      currentStreak: await _calculateCurrentStreak(),
      longestStreak: await _calculateLongestStreak(),
      recentAchievements: _achievements.reversed.take(5).toList(),
    );
  }

  /// 获取任务完成进度
  Future<Map<HabitCategory, double>> getProgressByCategory() async {
    final tasks = await generateBudgetTasks();
    final progress = <HabitCategory, double>{};

    for (final category in HabitCategory.values) {
      final categoryTasks = tasks.where((t) => t.category == category).toList();
      if (categoryTasks.isEmpty) {
        progress[category] = 1.0;
      } else {
        final completed = categoryTasks.where((t) => t.isCompleted).length;
        progress[category] = completed / categoryTasks.length;
      }
    }

    return progress;
  }

  /// 获取下一个里程碑
  Future<HabitMilestone?> getNextMilestone() async {
    final stats = await getStats();

    // 基于积分的里程碑
    final pointMilestones = [100, 500, 1000, 2500, 5000, 10000];
    for (final milestone in pointMilestones) {
      if (stats.totalPointsEarned < milestone) {
        return HabitMilestone(
          title: '$milestone积分达成',
          description: '再获得${milestone - stats.totalPointsEarned}积分',
          currentProgress: stats.totalPointsEarned.toDouble(),
          targetProgress: milestone.toDouble(),
          reward: milestone ~/ 10,
        );
      }
    }

    return null;
  }

  // ==================== 私有方法 ====================

  bool _hasAchievement(String id) {
    return _achievements.any((a) => a.id == id);
  }

  int _calculateSavingsReward(BudgetVault vault) {
    // 根据储蓄目标金额计算奖励
    if (vault.targetAmount >= 10000) return 50;
    if (vault.targetAmount >= 5000) return 35;
    if (vault.targetAmount >= 1000) return 25;
    return 15;
  }

  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return endOfMonth.day - now.day;
  }

  DateTime _getEndOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0);
  }

  Future<int> _calculateCurrentStreak() async {
    // 简化实现：返回模拟值
    // 实际实现需要追踪每日活跃记录
    return 7;
  }

  Future<int> _calculateLongestStreak() async {
    // 简化实现：返回模拟值
    return 14;
  }
}

/// 习惯里程碑
class HabitMilestone {
  final String title;
  final String description;
  final double currentProgress;
  final double targetProgress;
  final int reward;

  const HabitMilestone({
    required this.title,
    required this.description,
    required this.currentProgress,
    required this.targetProgress,
    required this.reward,
  });

  double get progressPercentage => currentProgress / targetProgress;
}
