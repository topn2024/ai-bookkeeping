import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/antigravity_shadows.dart';

/// NPS调查页面
/// 原型设计 14.01：NPS调查
/// - 0-10分评分界面
/// - 评分原因收集
/// - 感谢反馈页面
class NpsSurveyPage extends ConsumerStatefulWidget {
  const NpsSurveyPage({super.key});

  @override
  ConsumerState<NpsSurveyPage> createState() => _NpsSurveyPageState();
}

class _NpsSurveyPageState extends ConsumerState<NpsSurveyPage> {
  int? _selectedScore;
  final _feedbackController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_submitted) {
      return _buildThankYouPage(context, theme);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestion(context, theme),
                    const SizedBox(height: 24),
                    _buildScoreSelector(context, theme),
                    const SizedBox(height: 32),
                    if (_selectedScore != null) ...[
                      _buildFeedbackSection(context, theme),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            if (_selectedScore != null) _buildSubmitButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.close, color: theme.colorScheme.onSurface),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '您有多大可能向朋友推荐我们的应用？',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '您的反馈对我们非常重要',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSelector(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        // 分数说明
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '完全不可能',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '非常可能',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 分数选择器
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(11, (index) {
            final isSelected = _selectedScore == index;
            final color = _getScoreColor(index);

            return GestureDetector(
              onTap: () => setState(() => _selectedScore = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 36 : 28,
                height: isSelected ? 36 : 28,
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(isSelected ? 10 : 8),
                  boxShadow: isSelected ? AntigravityShadows.l2 : AntigravityShadows.l2Zero,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: isSelected ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // 选中分数说明
        if (_selectedScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getScoreColor(_selectedScore!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getScoreLabel(_selectedScore!),
              style: TextStyle(
                color: _getScoreColor(_selectedScore!),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedbackSection(BuildContext context, ThemeData theme) {
    final isPromoter = _selectedScore != null && _selectedScore! >= 9;
    final isDetractor = _selectedScore != null && _selectedScore! <= 6;

    String hintText;
    if (isPromoter) {
      hintText = '太棒了！请告诉我们您最喜欢的功能...';
    } else if (isDetractor) {
      hintText = '很抱歉让您失望了，请告诉我们如何改进...';
    } else {
      hintText = '请告诉我们如何能做得更好...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPromoter ? '您最喜欢什么？' : '我们可以如何改进？',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedbackController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        // 快捷标签
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getQuickTags(isPromoter, isDetractor).map((tag) {
            return GestureDetector(
              onTap: () {
                final currentText = _feedbackController.text;
                _feedbackController.text = currentText.isEmpty
                    ? tag
                    : '$currentText、$tag';
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<String> _getQuickTags(bool isPromoter, bool isDetractor) {
    if (isPromoter) {
      return ['智能识别准确', '界面美观', '记账方便', '统计清晰', '钱龄功能'];
    } else if (isDetractor) {
      return ['识别不准', '功能复杂', '同步问题', '速度慢', '缺少功能'];
    }
    return ['还需改进', '基本满意', '可以更好', '缺少功能'];
  }

  Widget _buildSubmitButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: AntigravityShadows.l3,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _submitted = true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('提交反馈'),
          ),
        ),
      ),
    );
  }

  Widget _buildThankYouPage(BuildContext context, ThemeData theme) {
    final isPromoter = _selectedScore != null && _selectedScore! >= 9;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    size: 40,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '感谢您的反馈！',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isPromoter
                      ? '很高兴您喜欢我们的应用！您的支持是我们前进的动力。'
                      : '我们会认真考虑您的建议，努力做得更好！',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (isPromoter)
                  OutlinedButton.icon(
                    onPressed: () {
                      // 跳转到分享页面
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('分享给朋友'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回应用'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score <= 6) return AppColors.expense;
    if (score <= 8) return AppColors.warning;
    return AppColors.income;
  }

  String _getScoreLabel(int score) {
    if (score <= 6) return '批评者';
    if (score <= 8) return '被动者';
    return '推荐者';
  }
}
