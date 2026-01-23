import 'package:flutter/material.dart';

/// 跨设备布局预览页面
/// 原型设计 11.10：跨设备布局预览
/// - 设备适配说明卡片
/// - 布局模式预览（手机竖屏、平板竖屏、折叠屏展开）
/// - 布局示意图
class ResponsiveLayoutPreviewPage extends StatelessWidget {
  const ResponsiveLayoutPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBreakpoint = _getCurrentBreakpoint(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('显示设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdaptiveCard(theme),
            const SizedBox(height: 16),
            _buildLayoutModes(theme, currentBreakpoint),
          ],
        ),
      ),
    );
  }

  /// 智能布局适配卡片
  Widget _buildAdaptiveCard(ThemeData theme) {
    return Container(
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
              Icon(
                Icons.devices,
                color: const Color(0xFF1565C0),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '智能布局适配',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '应用会自动适配您的设备屏幕，在手机、平板、折叠屏上都能获得最佳体验',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1976D2),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 布局模式列表
  Widget _buildLayoutModes(ThemeData theme, LayoutBreakpoint currentBreakpoint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '布局模式预览',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildLayoutCard(
          theme,
          icon: Icons.smartphone,
          title: '手机竖屏',
          subtitle: '< 600dp · 单栏布局',
          iconBgColor: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF4CAF50),
          isCurrent: currentBreakpoint == LayoutBreakpoint.phone,
          layoutBuilder: _buildPhoneLayout,
        ),
        const SizedBox(height: 8),
        _buildLayoutCard(
          theme,
          icon: Icons.tablet,
          title: '平板竖屏',
          subtitle: '600-840dp · 主详分栏',
          iconBgColor: const Color(0xFFFFF3E0),
          iconColor: const Color(0xFFFF9800),
          isCurrent: currentBreakpoint == LayoutBreakpoint.tablet,
          layoutBuilder: _buildTabletLayout,
        ),
        const SizedBox(height: 8),
        _buildLayoutCard(
          theme,
          icon: Icons.unfold_more,
          title: '折叠屏展开',
          subtitle: '> 840dp · 导航+主内容',
          iconBgColor: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF9C27B0),
          isCurrent: currentBreakpoint == LayoutBreakpoint.foldable,
          layoutBuilder: _buildFoldableLayout,
        ),
      ],
    );
  }

  Widget _buildLayoutCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required bool isCurrent,
    required Widget Function(ThemeData) layoutBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor),
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: layoutBuilder(theme),
          ),
        ],
      ),
    );
  }

  /// 手机布局示意
  Widget _buildPhoneLayout(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 平板布局示意
  Widget _buildTabletLayout(ThemeData theme) {
    return Center(
      child: Container(
        width: 70,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            // 左侧列表
            Container(
              width: 28,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            // 右侧详情
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 折叠屏布局示意
  Widget _buildFoldableLayout(ThemeData theme) {
    return Center(
      child: Container(
        width: 90,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            // 左侧导航
            Container(
              width: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                children: List.generate(3, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            // 中间列表
            Container(
              width: 30,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            // 右侧详情
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LayoutBreakpoint _getCurrentBreakpoint(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return LayoutBreakpoint.phone;
    } else if (width < 840) {
      return LayoutBreakpoint.tablet;
    } else {
      return LayoutBreakpoint.foldable;
    }
  }
}

/// 布局断点
enum LayoutBreakpoint {
  phone,    // < 600dp
  tablet,   // 600-840dp
  foldable, // > 840dp
}

/// 响应式布局工具
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? foldable;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.foldable,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 840 && foldable != null) {
      return foldable!;
    } else if (width >= 600 && tablet != null) {
      return tablet!;
    }
    return phone;
  }
}
