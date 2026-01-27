import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/help_content.dart';
import '../../services/help_content_service.dart';
import '../../theme/app_theme.dart';

/// 页面帮助详情组件
class PageHelpDetailWidget extends StatefulWidget {
  final HelpContent content;

  const PageHelpDetailWidget({
    super.key,
    required this.content,
  });

  @override
  State<PageHelpDetailWidget> createState() => _PageHelpDetailWidgetState();
}

class _PageHelpDetailWidgetState extends State<PageHelpDetailWidget> {
  final HelpContentService _helpService = HelpContentService();
  bool? _isHelpful;

  @override
  void initState() {
    super.initState();
    // 记录查看
    _helpService.recordView(widget.content.pageId);
    // 加载反馈状态
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedback = prefs.getBool('help_feedback_${widget.content.pageId}');
      if (mounted) {
        setState(() {
          _isHelpful = feedback;
        });
      }
    } catch (e) {
      print('加载反馈失败: $e');
    }
  }

  Future<void> _saveFeedback(bool isHelpful) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('help_feedback_${widget.content.pageId}', isHelpful);
      if (mounted) {
        setState(() {
          _isHelpful = isHelpful;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('感谢您的反馈'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('保存反馈失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.content.title),
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
            if (widget.content.relatedPages.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                '相关功能',
                Icons.link,
                Colors.blue,
                widget.content.relatedPages
                    .map((page) => _buildRelatedPageItem(page))
                    .toList(),
              ),
            ],

            // 反馈按钮
            const SizedBox(height: 32),
            _buildFeedbackSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '这个帮助内容对您有用吗？',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isHelpful == true ? null : () => _saveFeedback(true),
                  icon: Icon(
                    _isHelpful == true ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 20,
                  ),
                  label: const Text('有帮助'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isHelpful == true ? Colors.green : Colors.grey.shade700,
                    side: BorderSide(
                      color: _isHelpful == true ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isHelpful == false ? null : () => _saveFeedback(false),
                  icon: Icon(
                    _isHelpful == false ? Icons.thumb_down : Icons.thumb_down_outlined,
                    size: 20,
                  ),
                  label: const Text('无帮助'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isHelpful == false ? Colors.red : Colors.grey.shade700,
                    side: BorderSide(
                      color: _isHelpful == false ? Colors.red : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
