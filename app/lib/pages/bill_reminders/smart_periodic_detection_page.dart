import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 智能识别周期性收支页面
/// 原型设计 13.09：智能识别周期性收支
/// - AI发现提示卡片
/// - 发现的周期性收入列表
/// - 发现的周期性支出列表
/// - 设为周期性收入/账单 按钮
class SmartPeriodicDetectionPage extends ConsumerStatefulWidget {
  const SmartPeriodicDetectionPage({super.key});

  @override
  ConsumerState<SmartPeriodicDetectionPage> createState() => _SmartPeriodicDetectionPageState();
}

class _SmartPeriodicDetectionPageState extends ConsumerState<SmartPeriodicDetectionPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDiscoveryCard(theme),
                    const SizedBox(height: 20),
                    _buildPeriodicIncomeSection(theme),
                    const SizedBox(height: 20),
                    _buildPeriodicExpenseSection(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '发现周期性收支',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// AI发现提示卡片
  Widget _buildDiscoveryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 28,
              color: Color(0xFF6495ED),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI发现规律',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '根据您最近3个月的记录，发现了2个潜在的周期性收支',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1565C0),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 发现的周期性收入
  Widget _buildPeriodicIncomeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up,
              size: 18,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(width: 6),
            Text(
              '发现的周期性收入',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildIncomeDiscoveryCard(theme),
      ],
    );
  }

  Widget _buildIncomeDiscoveryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('💰', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '疑似每月工资',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        children: const [
                          TextSpan(text: '发现您每月5号都有一笔约 '),
                          TextSpan(
                            text: '¥15,000',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          TextSpan(text: ' 的收入'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已连续出现 3 个月',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setAsPeriodicIncome(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('设为周期性收入', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _ignoreIncome(),
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  '忽略',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 发现的周期性支出
  Widget _buildPeriodicExpenseSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_down,
              size: 18,
              color: Color(0xFFFF9800),
            ),
            const SizedBox(width: 6),
            Text(
              '发现的周期性支出',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildExpenseDiscoveryCard(theme),
      ],
    );
  }

  Widget _buildExpenseDiscoveryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('🏠', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '疑似每月房租',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        children: const [
                          TextSpan(text: '发现您每月1号都有一笔约 '),
                          TextSpan(
                            text: '¥3,500',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                          TextSpan(text: ' 的支出'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已连续出现 3 个月',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setAsPeriodicBill(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('设为定期账单', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _ignoreExpense(),
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  '忽略',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setAsPeriodicIncome() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已设置为周期性收入')),
    );
  }

  void _ignoreIncome() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已忽略此收入规律')),
    );
  }

  void _setAsPeriodicBill() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已设置为定期账单')),
    );
  }

  void _ignoreExpense() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已忽略此支出规律')),
    );
  }
}
