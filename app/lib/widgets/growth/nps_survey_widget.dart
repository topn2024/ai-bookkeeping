import 'package:flutter/material.dart';

/// NPS调查组件
///
/// 提供应用内NPS调查界面组件
///
/// 对应实施方案：用户增长体系 - NPS监测与口碑优化（第28章）

/// NPS 调查弹窗
class NPSSurveyDialog extends StatefulWidget {
  final void Function(int score, String? feedback) onSubmit;
  final VoidCallback? onDismiss;
  final String? customTitle;
  final String? customSubtitle;

  const NPSSurveyDialog({
    super.key,
    required this.onSubmit,
    this.onDismiss,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  State<NPSSurveyDialog> createState() => _NPSSurveyDialogState();
}

class _NPSSurveyDialogState extends State<NPSSurveyDialog> {
  int? _selectedScore;
  final _feedbackController = TextEditingController();
  bool _showFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 关闭按钮
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // 标题
            Text(
              widget.customTitle ?? '您愿意向朋友推荐这款应用吗？',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 副标题
            Text(
              widget.customSubtitle ?? '您的反馈对我们很重要',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 评分选择
            if (!_showFeedback) ...[
              _buildScoreSelector(),
              const SizedBox(height: 16),

              // 评分标签
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '完全不愿意',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Text(
                    '非常愿意',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedScore != null
                      ? () => setState(() => _showFeedback = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('下一步'),
                ),
              ),
            ],

            // 反馈输入
            if (_showFeedback) ...[
              _buildFeedbackInput(),
              const SizedBox(height: 16),

              // 提交按钮
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showFeedback = false),
                    child: const Text('返回'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSubmit(
                        _selectedScore!,
                        _feedbackController.text.isNotEmpty
                            ? _feedbackController.text
                            : null,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('提交'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(11, (index) {
        final isSelected = _selectedScore == index;
        final color = _getScoreColor(index);

        return GestureDetector(
          onTap: () => setState(() => _selectedScore = index),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 9) return Colors.green;
    if (score >= 7) return Colors.orange;
    return Colors.red;
  }

  Widget _buildFeedbackInput() {
    String hint;
    if (_selectedScore! >= 9) {
      hint = '太棒了！是什么让您如此喜爱这款应用？';
    } else if (_selectedScore! >= 7) {
      hint = '感谢您的反馈！有什么可以让我们做得更好的地方吗？';
    } else {
      hint = '很抱歉没有达到您的期望。请告诉我们哪些方面需要改进？';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedbackController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '请输入您的反馈（可选）',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

/// NPS 感谢弹窗
class NPSThankYouDialog extends StatelessWidget {
  final int score;
  final VoidCallback onClose;
  final VoidCallback? onShare;
  final VoidCallback? onReview;

  const NPSThankYouDialog({
    super.key,
    required this.score,
    required this.onClose,
    this.onShare,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isPromoter = score >= 9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isPromoter
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPromoter ? Icons.favorite : Icons.thumb_up,
                size: 40,
                color: isPromoter ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 20),

            // 感谢语
            Text(
              _getThankYouTitle(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              _getThankYouMessage(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 推荐者的额外操作
            if (isPromoter) ...[
              if (onReview != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onReview,
                    icon: const Icon(Icons.star),
                    label: const Text('去应用商店评价'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (onShare != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('分享给好友'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // 关闭按钮
            TextButton(
              onPressed: onClose,
              child: Text(isPromoter ? '稍后再说' : '关闭'),
            ),
          ],
        ),
      ),
    );
  }

  String _getThankYouTitle() {
    if (score >= 9) return '感谢您的认可！';
    if (score >= 7) return '感谢您的反馈！';
    return '感谢您的宝贵意见';
  }

  String _getThankYouMessage() {
    if (score >= 9) {
      return '您的支持是我们前进的动力，如果方便的话，请在应用商店给我们好评吧！';
    }
    if (score >= 7) {
      return '我们会根据您的建议不断改进，努力为您提供更好的体验。';
    }
    return '我们已收到您的反馈，会尽快改进相关问题。感谢您的耐心！';
  }
}

/// 分享卡片组件
class ShareCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? content;
  final String? backgroundImage;
  final Color? backgroundColor;
  final VoidCallback? onShare;

  const ShareCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.content,
    this.backgroundImage,
    this.backgroundColor,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 内容区域
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (content != null) ...[
                  const SizedBox(height: 16),
                  content!,
                ],
              ],
            ),
          ),

          // 底部品牌区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'AI智能记账',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onShare != null) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: onShare,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 账单摘要分享卡片
class BillSummaryShareCard extends StatelessWidget {
  final String period;
  final double totalIncome;
  final double totalExpense;
  final double netSaving;
  final VoidCallback? onShare;

  const BillSummaryShareCard({
    super.key,
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSaving,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCard(
      title: '$period账单',
      subtitle: '我的财务小结',
      onShare: onShare,
      content: Column(
        children: [
          _buildStatRow('收入', totalIncome, Colors.green),
          const SizedBox(height: 8),
          _buildStatRow('支出', totalExpense, Colors.red),
          const Divider(height: 24),
          _buildStatRow(
            netSaving >= 0 ? '净存款' : '超支',
            netSaving.abs(),
            netSaving >= 0 ? Colors.blue : Colors.orange,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color color,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            color: isHighlight ? Colors.black : Colors.grey[600],
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isHighlight ? 18 : 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 成就分享卡片
class AchievementShareCard extends StatelessWidget {
  final String achievementName;
  final String description;
  final String iconEmoji;
  final DateTime unlockedAt;
  final VoidCallback? onShare;

  const AchievementShareCard({
    super.key,
    required this.achievementName,
    required this.description,
    required this.iconEmoji,
    required this.unlockedAt,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCard(
      title: '获得成就',
      subtitle: _formatDate(unlockedAt),
      backgroundColor: Colors.amber[50],
      onShare: onShare,
      content: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                iconEmoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            achievementName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// 邀请卡片
class InviteCard extends StatelessWidget {
  final String inviteCode;
  final String inviterName;
  final String rewardDescription;
  final VoidCallback? onCopyCode;
  final VoidCallback? onShare;

  const InviteCard({
    super.key,
    required this.inviteCode,
    required this.inviterName,
    required this.rewardDescription,
    this.onCopyCode,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCard(
      title: '$inviterName 邀请你一起记账',
      subtitle: '使用邀请码注册，双方都有奖励',
      onShare: onShare,
      content: Column(
        children: [
          // 邀请码
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  inviteCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  onPressed: onCopyCode,
                  tooltip: '复制邀请码',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 奖励说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rewardDescription,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.green,
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
}

/// 显示 NPS 调查弹窗
Future<void> showNPSSurvey(
  BuildContext context, {
  required void Function(int score, String? feedback) onSubmit,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => NPSSurveyDialog(
      onSubmit: (score, feedback) {
        Navigator.of(context).pop();
        onSubmit(score, feedback);
      },
      onDismiss: () {
        Navigator.of(context).pop();
        onDismiss?.call();
      },
    ),
  );
}

/// 显示 NPS 感谢弹窗
Future<void> showNPSThankYou(
  BuildContext context, {
  required int score,
  VoidCallback? onShare,
  VoidCallback? onReview,
}) {
  return showDialog(
    context: context,
    builder: (context) => NPSThankYouDialog(
      score: score,
      onClose: () => Navigator.of(context).pop(),
      onShare: onShare != null
          ? () {
              Navigator.of(context).pop();
              onShare();
            }
          : null,
      onReview: onReview != null
          ? () {
              Navigator.of(context).pop();
              onReview();
            }
          : null,
    ),
  );
}
