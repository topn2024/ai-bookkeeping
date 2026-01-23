import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'import_main_page.dart';

/// 账单导出教程页面
/// 原型设计 5.17：账单导出教程
/// - 平台选择标签（微信/支付宝/银行）
/// - 分步骤教程
/// - 完成后跳转导入
class BillExportTutorialPage extends ConsumerStatefulWidget {
  final String? initialPlatform;

  const BillExportTutorialPage({
    super.key,
    this.initialPlatform,
  });

  @override
  ConsumerState<BillExportTutorialPage> createState() =>
      _BillExportTutorialPageState();
}

class _BillExportTutorialPageState extends ConsumerState<BillExportTutorialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<PlatformTutorial> _tutorials = [
    PlatformTutorial(
      platform: 'wechat',
      name: '微信',
      color: const Color(0xFF07C160),
      icon: Icons.chat,
      steps: [
        TutorialStep(
          title: '打开微信，点击「我」',
          description: '进入微信主界面后，点击底部导航栏的「我」',
        ),
        TutorialStep(
          title: '进入「服务」→「钱包」',
          description: '在个人页面中找到服务入口',
        ),
        TutorialStep(
          title: '点击「账单」→ 右上角「···」',
          description: '打开账单页面后，点击右上角更多按钮',
        ),
        TutorialStep(
          title: '选择「账单下载」并设置时间',
          description: '建议选择「用于个人对账」格式，包含完整交易信息',
          isHighlight: true,
        ),
        TutorialStep(
          title: '账单会发送到绑定邮箱',
          description: '下载邮件中的CSV附件，然后在本APP中导入即可',
          isComplete: true,
        ),
      ],
    ),
    PlatformTutorial(
      platform: 'alipay',
      name: '支付宝',
      color: const Color(0xFF1677FF),
      icon: Icons.account_balance_wallet,
      steps: [
        TutorialStep(
          title: '打开支付宝，点击「我的」',
          description: '进入支付宝主界面后，点击底部的「我的」',
        ),
        TutorialStep(
          title: '点击「账单」',
          description: '在我的页面中找到账单入口',
        ),
        TutorialStep(
          title: '点击右上角「···」→「开具交易流水证明」',
          description: '或者选择「下载账单」功能',
        ),
        TutorialStep(
          title: '选择时间范围和用途',
          description: '选择「用于个人对账」，支持最长12个月',
          isHighlight: true,
        ),
        TutorialStep(
          title: '账单会发送到绑定邮箱',
          description: '下载邮件中的CSV附件，然后在本APP中导入即可',
          isComplete: true,
        ),
      ],
    ),
    PlatformTutorial(
      platform: 'bank',
      name: '银行',
      color: const Color(0xFFE53935),
      icon: Icons.account_balance,
      steps: [
        TutorialStep(
          title: '登录网上银行或手机银行',
          description: '使用银行官方APP或网站',
        ),
        TutorialStep(
          title: '进入「账户查询」或「交易明细」',
          description: '不同银行入口位置可能不同',
        ),
        TutorialStep(
          title: '选择「导出」或「下载」功能',
          description: '设置需要导出的时间范围',
        ),
        TutorialStep(
          title: '选择导出格式',
          description: '推荐选择 CSV 或 Excel 格式，兼容性最好',
          isHighlight: true,
        ),
        TutorialStep(
          title: '下载文件到手机',
          description: '将导出的文件保存到手机，然后在本APP中导入',
          isComplete: true,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialPlatform != null) {
      initialIndex = _tutorials.indexWhere((t) => t.platform == widget.initialPlatform);
      if (initialIndex < 0) initialIndex = 0;
    }
    _tabController = TabController(
      length: _tutorials.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出账单教程'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: _tutorials.map((tutorial) {
                return Tab(text: tutorial.name);
              }).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tutorials.map((tutorial) {
                return _buildTutorialContent(theme, tutorial);
              }).toList(),
            ),
          ),
          _buildBottomButton(context, theme),
        ],
      ),
    );
  }

  /// 教程内容
  Widget _buildTutorialContent(ThemeData theme, PlatformTutorial tutorial) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 平台标题
        Row(
          children: [
            Icon(tutorial.icon, color: tutorial.color, size: 18),
            const SizedBox(width: 8),
            Text(
              '${tutorial.name}账单导出步骤',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tutorial.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 步骤列表
        ...tutorial.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return _buildStepItem(theme, tutorial, index + 1, step);
        }),
      ],
    );
  }

  Widget _buildStepItem(
    ThemeData theme,
    PlatformTutorial tutorial,
    int number,
    TutorialStep step,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤编号或完成图标
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: step.isComplete
                  ? AppColors.success
                  : tutorial.color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: step.isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // 步骤内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: step.isHighlight
                        ? theme.colorScheme.surfaceContainerHighest
                        : (step.isComplete
                            ? const Color(0xFFE8F5E9)
                            : theme.colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: step.isComplete
                          ? const Color(0xFF2E7D32)
                          : theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部按钮
  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _goToImport(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '已完成，去导入账单',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  void _goToImport(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ImportMainPage()),
    );
  }
}

/// 平台教程数据
class PlatformTutorial {
  final String platform;
  final String name;
  final Color color;
  final IconData icon;
  final List<TutorialStep> steps;

  PlatformTutorial({
    required this.platform,
    required this.name,
    required this.color,
    required this.icon,
    required this.steps,
  });
}

/// 教程步骤
class TutorialStep {
  final String title;
  final String description;
  final bool isHighlight;
  final bool isComplete;

  TutorialStep({
    required this.title,
    required this.description,
    this.isHighlight = false,
    this.isComplete = false,
  });
}
