import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 图表分享页面
/// 原型设计 7.10：图表分享
/// - 预览图片
/// - 分享到（微信、朋友圈、复制链接、保存图片）
/// - 隐私设置（隐藏具体金额）
/// - 立即分享按钮
class ChartSharePage extends ConsumerStatefulWidget {
  final String title;
  final double totalAmount;
  final Map<String, double>? categoryBreakdown;

  const ChartSharePage({
    super.key,
    required this.title,
    required this.totalAmount,
    this.categoryBreakdown,
  });

  @override
  ConsumerState<ChartSharePage> createState() => _ChartSharePageState();
}

class _ChartSharePageState extends ConsumerState<ChartSharePage> {
  bool _hideAmount = true;

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
                child: Column(
                  children: [
                    _buildPreviewCard(theme),
                    _buildShareOptions(theme),
                    _buildPrivacySettings(theme),
                  ],
                ),
              ),
            ),
            _buildShareButton(context, theme),
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
              child: const Icon(Icons.close),
            ),
          ),
          const Expanded(
            child: Text(
              '分享图表',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 预览卡片
  Widget _buildPreviewCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6495ED), Color(0xFF9370DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hideAmount ? '¥****' : '¥${widget.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // 迷你饼图占位
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 16,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 分类占比
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCategoryPercent('餐饮', '27%'),
              _buildCategoryPercent('交通', '18%'),
              _buildCategoryPercent('购物', '15%'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '来自 智能记账App',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPercent(String name, String percent) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        Text(
          percent,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 分享选项
  Widget _buildShareOptions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分享到',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildShareOption(
                theme,
                icon: Icons.chat,
                label: '微信',
                color: const Color(0xFF1AAD19),
                onTap: () => _shareToWechat(context),
              ),
              _buildShareOption(
                theme,
                icon: Icons.qr_code,
                label: '朋友圈',
                color: const Color(0xFF1296DB),
                onTap: () => _shareToMoments(context),
              ),
              _buildShareOption(
                theme,
                icon: Icons.content_copy,
                label: '复制链接',
                color: theme.colorScheme.surfaceContainerHighest,
                iconColor: theme.colorScheme.onSurface,
                onTap: () => _copyLink(context),
              ),
              _buildShareOption(
                theme,
                icon: Icons.download,
                label: '保存图片',
                color: theme.colorScheme.surfaceContainerHighest,
                iconColor: theme.colorScheme.onSurface,
                onTap: () => _saveImage(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 隐私设置
  Widget _buildPrivacySettings(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '隐藏具体金额',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '分享时显示百分比而非金额',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _hideAmount,
            onChanged: (v) => setState(() => _hideAmount = v),
            activeTrackColor: const Color(0xFF6495ED),
          ),
        ],
      ),
    );
  }

  /// 分享按钮
  Widget _buildShareButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share),
          label: const Text('立即分享', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _shareToWechat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享到微信...')),
    );
  }

  void _shareToMoments(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享到朋友圈...')),
    );
  }

  void _copyLink(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制')),
    );
  }

  void _saveImage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片已保存到相册')),
    );
  }

  void _share(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成分享图片...')),
    );
    Navigator.pop(context);
  }
}
