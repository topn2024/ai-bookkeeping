import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'money_age_page.dart';
import 'budget_center_page.dart';
import '../providers/budget_provider.dart';
import '../providers/budget_vault_provider.dart';
import '../providers/transaction_provider.dart';

/// 财务健康仪表盘页面
///
/// 对应原型设计 10.01 财务健康仪表盘
/// 展示用户的财务健康综合评分和5个维度分析
class FinancialHealthDashboardPage extends ConsumerWidget {
  const FinancialHealthDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取真实数据
    final moneyAge = ref.watch(moneyAgeProvider);
    final vaultState = ref.watch(budgetVaultProvider);
    final transactions = ref.watch(transactionProvider);

    // 计算钱龄得分 (0-20分)
    final moneyAgeScore = _calculateMoneyAgeScore(moneyAge);
    final moneyAgeStatus = _getMoneyAgeStatus(moneyAge);
    final moneyAgeColor = moneyAge >= 30 ? Colors.green : (moneyAge >= 15 ? Colors.orange : Colors.red);

    // 计算预算控制得分
    final budgetScore = _calculateBudgetScore(vaultState);
    final budgetStatus = _getBudgetStatus(vaultState);
    final budgetColor = budgetScore >= 15 ? Colors.green : (budgetScore >= 10 ? Colors.orange : Colors.red);

    // 计算应急金得分（暂时给固定分数，未来可以实现应急金功能）
    final emergencyScore = 12;
    final emergencyStatus = '建议建立应急金储备';
    final emergencyColor = Colors.orange;

    // 计算消费结构得分（暂时给固定分数）
    final structureScore = 15;
    final structureStatus = '消费结构合理';
    final structureColor = Colors.green;

    // 计算记账习惯得分
    final habitScore = _calculateHabitScore(transactions);
    final habitStatus = _getHabitStatus(transactions);
    final habitColor = habitScore >= 15 ? Colors.green : (habitScore >= 10 ? Colors.orange : Colors.red);

    // 计算总分
    final totalScore = moneyAgeScore + budgetScore + emergencyScore + structureScore + habitScore;
    final healthStatus = totalScore >= 80 ? '财务优秀' : (totalScore >= 60 ? '财务良好' : '需要改进');

    // 生成改进建议
    final suggestion = _generateSuggestion(moneyAgeScore, budgetScore, habitScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('财务健康'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 总分展示
          _HealthScoreCard(
            score: totalScore,
            status: healthStatus,
            change: 0,
          ),

          // 5维度得分
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              '健康维度分析',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 钱龄得分
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoneyAgePage()),
            ),
            child: _DimensionCard(
              icon: Icons.schedule,
              iconColor: AppTheme.primaryColor,
              iconBgColor: const Color(0xFFEBF3FF),
              title: '钱龄',
              score: moneyAgeScore,
              maxScore: 20,
              status: moneyAgeStatus,
              statusColor: moneyAgeColor,
            ),
          ),

          // 预算控制
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetCenterPage()),
            ),
            child: _DimensionCard(
              icon: Icons.account_balance_wallet,
              iconColor: const Color(0xFFFFB74D),
              iconBgColor: const Color(0xFFFFF3E0),
              title: '预算控制',
              score: budgetScore,
              maxScore: 20,
              status: budgetStatus,
              statusColor: budgetColor,
            ),
          ),

          // 应急金
          _DimensionCard(
            icon: Icons.shield,
            iconColor: const Color(0xFF66BB6A),
            iconBgColor: const Color(0xFFE8F5E9),
            title: '应急金',
            score: emergencyScore,
            maxScore: 20,
            status: emergencyStatus,
            statusColor: emergencyColor,
          ),

          // 消费结构
          _DimensionCard(
            icon: Icons.pie_chart,
            iconColor: const Color(0xFF7B1FA2),
            iconBgColor: const Color(0xFFF3E5F5),
            title: '消费结构',
            score: structureScore,
            maxScore: 20,
            status: structureStatus,
            statusColor: structureColor,
          ),

          // 记账习惯
          _DimensionCard(
            icon: Icons.local_fire_department,
            iconColor: const Color(0xFFEF5350),
            iconBgColor: const Color(0xFFFFEBEE),
            title: '记账习惯',
            score: habitScore,
            maxScore: 20,
            status: habitStatus,
            statusColor: habitColor,
          ),

          // 改进建议
          _ImprovementSuggestionCard(
            title: '本月改进重点',
            suggestion: suggestion,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 计算钱龄得分 (0-20分)
  int _calculateMoneyAgeScore(int moneyAge) {
    if (moneyAge >= 60) return 20;
    if (moneyAge >= 45) return 18;
    if (moneyAge >= 30) return 16;
    if (moneyAge >= 20) return 14;
    if (moneyAge >= 10) return 10;
    if (moneyAge >= 5) return 6;
    if (moneyAge < 0) return 0; // 负钱龄0分
    return 3;
  }

  String _getMoneyAgeStatus(int moneyAge) {
    if (moneyAge < 0) return '透支：已超支${-moneyAge}天';
    if (moneyAge >= 60) return '当前${moneyAge}天，优秀状态';
    if (moneyAge >= 30) return '当前${moneyAge}天，良好状态';
    if (moneyAge >= 15) return '当前${moneyAge}天，尚可状态';
    return '当前${moneyAge}天，需要改进';
  }

  // 计算预算控制得分
  int _calculateBudgetScore(BudgetVaultState vaultState) {
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();
    if (vaults.isEmpty) return 15; // 没有设置预算给默认分

    int overspentCount = 0;
    int almostEmptyCount = 0;

    for (final vault in vaults) {
      final remaining = vault.targetAmount - vault.allocatedAmount;
      final remainingPercent = vault.targetAmount > 0
          ? ((remaining / vault.targetAmount) * 100).round()
          : 100;

      if (remaining < 0) {
        overspentCount++;
      } else if (remainingPercent <= 20 && remainingPercent > 0) {
        almostEmptyCount++;
      }
    }

    // 根据问题数量扣分
    int score = 20;
    score -= overspentCount * 3; // 每个超支扣3分
    score -= almostEmptyCount * 1; // 每个即将用完扣1分
    return score.clamp(0, 20);
  }

  String _getBudgetStatus(BudgetVaultState vaultState) {
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();
    if (vaults.isEmpty) return '未设置预算';

    for (final vault in vaults) {
      final remaining = vault.targetAmount - vault.allocatedAmount;
      if (remaining < 0) {
        return '${vault.name}预算超支';
      }
    }

    for (final vault in vaults) {
      final remaining = vault.targetAmount - vault.allocatedAmount;
      final remainingPercent = vault.targetAmount > 0
          ? ((remaining / vault.targetAmount) * 100).round()
          : 100;
      if (remainingPercent <= 20 && remainingPercent > 0) {
        return '${vault.name}预算即将用完';
      }
    }

    return '预算执行良好';
  }

  // 计算记账习惯得分
  int _calculateHabitScore(List transactions) {
    if (transactions.isEmpty) return 0;

    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentTransactions = transactions.where((t) => t.date.isAfter(last30Days)).toList();

    // 按日期分组
    final dayGroups = <String, int>{};
    for (final t in recentTransactions) {
      final dateKey = '${t.date.year}-${t.date.month}-${t.date.day}';
      dayGroups[dateKey] = (dayGroups[dateKey] ?? 0) + 1;
    }

    final recordedDays = dayGroups.length;

    // 根据记账天数打分
    if (recordedDays >= 25) return 20;
    if (recordedDays >= 20) return 18;
    if (recordedDays >= 15) return 15;
    if (recordedDays >= 10) return 12;
    if (recordedDays >= 5) return 8;
    return 5;
  }

  String _getHabitStatus(List transactions) {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentTransactions = transactions.where((t) => t.date.isAfter(last30Days)).toList();

    final dayGroups = <String, int>{};
    for (final t in recentTransactions) {
      final dateKey = '${t.date.year}-${t.date.month}-${t.date.day}';
      dayGroups[dateKey] = (dayGroups[dateKey] ?? 0) + 1;
    }

    final recordedDays = dayGroups.length;
    return '近30天记账${recordedDays}天';
  }

  String _generateSuggestion(int moneyAgeScore, int budgetScore, int habitScore) {
    // 找出得分最低的维度给出建议
    final scores = {
      'moneyAge': moneyAgeScore,
      'budget': budgetScore,
      'habit': habitScore,
    };

    final lowestDimension = scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;

    switch (lowestDimension) {
      case 'moneyAge':
        return '钱龄是提升空间最大的维度，建议延迟非必要消费，让资金在账户中停留更长时间';
      case 'budget':
        return '预算控制是提升空间最大的维度，建议设置每周预算上限，及时调整超支分类';
      case 'habit':
        return '记账习惯是提升空间最大的维度，建议每天记录消费，养成良好的记账习惯';
      default:
        return '继续保持良好的财务习惯，您的财务状况正在稳步改善';
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('财务健康指数说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('财务健康指数由5个维度综合计算：'),
            SizedBox(height: 12),
            Text('• 钱龄：资金持有时间'),
            Text('• 预算控制：预算执行情况'),
            Text('• 应急金：紧急备用金储备'),
            Text('• 消费结构：必要vs非必要支出'),
            Text('• 记账习惯：记账频率和完整度'),
            SizedBox(height: 12),
            Text('每个维度满分20分，总分100分。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 健康分数卡片
class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String status;
  final int change;

  const _HealthScoreCard({
    required this.score,
    required this.status,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (score >= 80) {
      bgColor = Colors.green;
    } else if (score >= 60) {
      bgColor = Colors.orange;
    } else {
      bgColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '财务健康指数',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                change >= 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '较上月 ${change >= 0 ? '+' : ''}$change分',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 维度得分卡片
class _DimensionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final int score;
  final int maxScore;
  final String status;
  final Color statusColor;

  const _DimensionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = score / maxScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '$score/$maxScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                color: statusColor == Colors.green
                    ? Colors.grey[600]
                    : statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 改进建议卡片
class _ImprovementSuggestionCard extends StatelessWidget {
  final String title;
  final String suggestion;

  const _ImprovementSuggestionCard({
    required this.title,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
