import 'package:flutter/material.dart';
import '../../models/help_content.dart';
import '../../theme/app_theme.dart';

/// 页面帮助详情组件
class PageHelpDetailWidget extends StatelessWidget {
  final HelpContent content;

  const PageHelpDetailWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能描述
            _buildSection(
              '功能描述',
              Icons.description,
              AppColors.primary,
              [
                Text(
                  content.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            // 使用场景
            if (content.useCases.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                '使用场景',
                Icons.lightbulb_outline,
                AppColors.income,
                content.useCases
                    .map((useCase) => _buildListItem(useCase))
                    .toList(),
              ),
            ],

            // 操作步骤
            if (content.steps.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                '操作步骤',
                Icons.format_list_numbered,
                AppColors.transfer,
                content.steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return _buildStepItem(index + 1, step);
                }).toList(),
              ),
            ],

            // 注意事项
            if (content.tips.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                '注意事项',
                Icons.info_outline,
                Colors.orange,
                content.tips.map((tip) => _buildTipItem(tip)).toList(),
              ),
            ],

            // 相关功能
            if (content.relatedPages.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                '相关功能',
                Icons.link,
                Colors.blue,
                content.relatedPages
                    .map((page) => _buildRelatedPageItem(page))
                    .toList(),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 15)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, HelpStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.transfer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.transfer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedPageItem(String pageId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // TODO: 导航到相关页面
        },
        child: Row(
          children: [
            const Icon(Icons.arrow_forward, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              pageId,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
