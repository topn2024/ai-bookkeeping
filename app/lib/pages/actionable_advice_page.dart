import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'budget_center_page.dart';
import 'budget_management_page.dart';
import 'money_age_page.dart';

/// 建议类型枚举
enum AdviceType {
  budgetWarning,
  overspending,
  moneyAge,
  achievement,
}

/// 可行建议数据
class ActionableAdvice {
  final String id;
  final AdviceType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? primaryAction;
  final String? secondaryAction;
  final Map<String, dynamic>? metadata;

  ActionableAdvice({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.primaryAction,
    this.secondaryAction,
    this.metadata,
  });
}

/// 10.20 可行建议展示页面
/// 展示智能分析后的可执行建议
class ActionableAdvicePage extends ConsumerStatefulWidget {
  const ActionableAdvicePage({super.key});

  @override
  ConsumerState<ActionableAdvicePage> createState() =>
      _ActionableAdvicePageState();
}

class _ActionableAdvicePageState extends ConsumerState<ActionableAdvicePage> {
  late List<ActionableAdvice> _adviceList;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    _adviceList = [
      ActionableAdvice(
        id: '1',
        type: AdviceType.budgetWarning,
        title: '餐饮预算预警',
        description: '餐饮还剩 ¥80/5天，平均每天16元。这周少点2次外卖，改成自带午餐怎么样？',
        icon: Icons.restaurant,
        color: const Color(0xFFF57C00),
        bgColor: const Color(0xFFFFF3E0),
        primaryAction: '设置提醒',
        secondaryAction: '忽略',
        metadata: {
          'remaining': 80,
          'days': 5,
          'daily_average': 16,
        },
      ),
      ActionableAdvice(
        id: '2',
        type: AdviceType.overspending,
        title: '超支处理方案',
        description: '购物超支 ¥200，主要是双11购物。可以从娱乐预算（还剩¥300）调拨，要帮你设置吗？',
        icon: Icons.trending_up,
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        primaryAction: '立即调拨',
        secondaryAction: '下月补上',
        metadata: {
          'overspent': 200,
          'source': '双11购物',
          'available_from': '娱乐预算',
          'available_amount': 300,
        },
      ),
      ActionableAdvice(
        id: '3',
        type: AdviceType.moneyAge,
        title: '钱龄提升机会',
        description: '钱龄目前 12天，离目标差3天。把周末的¥299购物推迟到下周发工资后，钱龄可达 16天',
        icon: Icons.schedule,
        color: const Color(0xFF43A047),
        bgColor: const Color(0xFFE8F5E9),
        primaryAction: '添加到待办',
        secondaryAction: '已知晓',
        metadata: {
          'current_age': 12,
          'target_age': 15,
          'potential_age': 16,
          'postpone_amount': 299,
        },
      ),
      ActionableAdvice(
        id: '4',
        type: AdviceType.achievement,
        title: '连续记账7天！',
        description: '本月预算执行率85%，月底就能看到完整的消费报告。继续保持这个好习惯！',
        icon: Icons.emoji_events,
        color: const Color(0xFF8E24AA),
        bgColor: const Color(0xFFF3E5F5),
        metadata: {
          'streak_days': 7,
          'budget_execution': 85,
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.smartAdvice,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 今日建议摘要
                  _buildTodaySummary(l10n),
                  // 建议列表
                  ...List.generate(_adviceList.length, (index) {
                    return _buildAdviceCard(_adviceList[index], l10n);
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // 底部设置入口
          _buildSettingsEntry(l10n),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(AppLocalizations l10n) {
    final actionableCount = _adviceList
        .where((a) => a.primaryAction != null)
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                l10n.todayAdvice,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '基于你的消费习惯，这里有$actionableCount条可执行的建议帮助你更好地管理财务',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1565C0),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(ActionableAdvice advice, AppLocalizations l10n) {
    final isAchievement = advice.type == AdviceType.achievement;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isAchievement
            ? LinearGradient(
                colors: [
                  advice.bgColor,
                  const Color(0xFFE1BEE7),
                ],
              ).colors.first
            : Colors.white,
        gradient: isAchievement
            ? LinearGradient(
                colors: [advice.bgColor, const Color(0xFFE1BEE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: advice.color,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAchievement ? Colors.white : advice.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    advice.icon,
                    color: advice.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advice.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isAchievement
                              ? const Color(0xFF6A1B9A)
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildHighlightedDescription(advice),
                    ],
                  ),
                ),
              ],
            ),
            // 操作按钮
            if (advice.primaryAction != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildActionButton(
                    advice.primaryAction!,
                    advice.color,
                    advice.bgColor,
                    isPrimary: true,
                    onPressed: () => _handlePrimaryAction(advice),
                  ),
                  if (advice.secondaryAction != null) ...[
                    const SizedBox(width: 10),
                    _buildActionButton(
                      advice.secondaryAction!,
                      AppTheme.textSecondaryColor,
                      Colors.transparent,
                      isPrimary: false,
                      onPressed: () => _handleSecondaryAction(advice),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedDescription(ActionableAdvice advice) {
    final description = advice.description;
    final color = advice.type == AdviceType.achievement
        ? const Color(0xFF7B1FA2)
        : AppTheme.textSecondaryColor;

    // 简单处理：高亮显示数字和关键词
    return Text(
      description,
      style: TextStyle(
        fontSize: 13,
        color: color,
        height: 1.5,
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    Color textColor,
    Color bgColor, {
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary ? bgColor : Colors.transparent,
            border: isPrimary
                ? null
                : Border.all(color: AppTheme.dividerColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.w500 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsEntry(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: InkWell(
          onTap: () => _openAdviceSettings(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.settings,
                size: 18,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.manageAdvicePreference,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePrimaryAction(ActionableAdvice advice) {
    switch (advice.type) {
      case AdviceType.budgetWarning:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetCenterPage()),
        );
        break;
      case AdviceType.overspending:
        _showReallocationDialog(advice);
        break;
      case AdviceType.moneyAge:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MoneyAgePage()),
        );
        break;
      default:
        break;
    }
  }

  void _handleSecondaryAction(ActionableAdvice advice) {
    setState(() {
      _adviceList.remove(advice);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('建议已忽略'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            setState(() {
              _adviceList.insert(0, advice);
            });
          },
        ),
      ),
    );
  }

  void _showReallocationDialog(ActionableAdvice advice) {
    final metadata = advice.metadata ?? {};
    final overspent = metadata['overspent'] ?? 0;
    final availableFrom = metadata['available_from'] ?? '其他预算';
    final availableAmount = metadata['available_amount'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('确认调拨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('从$availableFrom调拨 ¥$overspent 到购物预算？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$availableFrom余额', style: TextStyle(fontSize: 13)),
                      Text('¥$availableAmount → ¥${availableAmount - overspent}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('购物预算状态', style: TextStyle(fontSize: 13)),
                      Text('超支¥$overspent → 持平',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('预算调拨成功'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
              setState(() {
                _adviceList.remove(advice);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('确认调拨'),
          ),
        ],
      ),
    );
  }

  void _openAdviceSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '建议偏好设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingSwitch('预算提醒', true),
            _buildSettingSwitch('超支建议', true),
            _buildSettingSwitch('钱龄优化', true),
            _buildSettingSwitch('成就提示', true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('保存设置'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Switch(
            value: value,
            onChanged: (v) {},
            activeTrackColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
