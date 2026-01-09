import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 引导完成庆祝页
///
/// 对应原型设计 10.17 引导完成庆祝
/// 新用户完成引导后的庆祝页面
class OnboardingCompletePage extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback? onTryVoice;
  final VoidCallback? onSetBudget;
  final VoidCallback? onImportBills;

  const OnboardingCompletePage({
    super.key,
    required this.onGoHome,
    this.onTryVoice,
    this.onSetBudget,
    this.onImportBills,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.green[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 庆祝动画区
              _CelebrationHeader(),

              // 成就解锁
              _AchievementCard(),

              // 下一步建议
              _NextStepsSuggestion(
                onTryVoice: onTryVoice,
                onSetBudget: onSetBudget,
                onImportBills: onImportBills,
              ),

              // 进入首页按钮
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: onGoHome,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.onboardingCompleteGoHome,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.home, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 庆祝头部
class _CelebrationHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        children: [
          // 庆祝图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[400]!, Colors.green[700]!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.celebration,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 祝贺文字
          const Text(
            '太棒了！',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            '你已成功记下第一笔账\n理财之旅正式开始',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 成就解锁卡片
class _AchievementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[50]!, Colors.amber[100]!],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber[300]!),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.amber[400],
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '🏆',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成就解锁',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                  Text(
                    '初次记账 · 获得10经验值',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.star,
              color: Colors.amber[700],
            ),
          ],
        ),
      ),
    );
  }
}

/// 下一步建议
class _NextStepsSuggestion extends StatelessWidget {
  final VoidCallback? onTryVoice;
  final VoidCallback? onSetBudget;
  final VoidCallback? onImportBills;

  const _NextStepsSuggestion({
    this.onTryVoice,
    this.onSetBudget,
    this.onImportBills,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '接下来你可以...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _NextStepItem(
                  icon: Icons.mic,
                  iconColor: Colors.blue,
                  iconBackground: Colors.blue[50]!,
                  title: '试试语音记账',
                  subtitle: '说出消费，自动记录',
                  onTap: onTryVoice,
                ),
                Divider(height: 1, color: Colors.grey[200]),
                _NextStepItem(
                  icon: Icons.account_balance,
                  iconColor: Colors.orange,
                  iconBackground: Colors.orange[50]!,
                  title: '设置月度预算',
                  subtitle: '合理规划开支',
                  onTap: onSetBudget,
                ),
                Divider(height: 1, color: Colors.grey[200]),
                _NextStepItem(
                  icon: Icons.upload_file,
                  iconColor: Colors.green,
                  iconBackground: Colors.green[50]!,
                  title: '导入历史账单',
                  subtitle: '一键同步银行记录',
                  onTap: onImportBills,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _NextStepItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
