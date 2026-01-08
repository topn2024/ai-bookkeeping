import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.27 首页布局定制页面
/// 自定义首页显示的卡片和模块
class HomeLayoutPage extends ConsumerStatefulWidget {
  const HomeLayoutPage({super.key});

  @override
  ConsumerState<HomeLayoutPage> createState() => _HomeLayoutPageState();
}

class _HomeLayoutPageState extends ConsumerState<HomeLayoutPage> {
  final List<_LayoutModule> _modules = [
    _LayoutModule(id: 'balance', name: '本月结余', icon: Icons.account_balance_wallet, enabled: true),
    _LayoutModule(id: 'money_age', name: '钱龄卡片', icon: Icons.access_time, enabled: true),
    _LayoutModule(id: 'budget', name: '预算概览', icon: Icons.pie_chart, enabled: true),
    _LayoutModule(id: 'achievement', name: '成就卡片', icon: Icons.emoji_events, enabled: true),
    _LayoutModule(id: 'quick_stats', name: '快速统计', icon: Icons.bar_chart, enabled: true),
    _LayoutModule(id: 'recent', name: '最近记录', icon: Icons.history, enabled: true),
    _LayoutModule(id: 'advice', name: '智能建议', icon: Icons.tips_and_updates, enabled: false),
    _LayoutModule(id: 'savings', name: '储蓄目标', icon: Icons.savings, enabled: false),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.homeLayout,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: Text(
              l10n.reset,
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _modules.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                return _buildModuleItem(_modules[index], index);
              },
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '拖动调整顺序，开关控制显示',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleItem(_LayoutModule module, int index) {
    return Container(
      key: ValueKey(module.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: module.enabled
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.surfaceVariantColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            module.icon,
            color: module.enabled
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            size: 20,
          ),
        ),
        title: Text(
          module.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: module.enabled ? Colors.black87 : AppTheme.textSecondaryColor,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: module.enabled,
              onChanged: (v) => setState(() => module.enabled = v),
              activeTrackColor: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _saveLayout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '保存��局',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _modules.removeAt(oldIndex);
      _modules.insert(newIndex, item);
    });
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置布局'),
        content: const Text('确定要恢复默认布局吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                for (var module in _modules) {
                  module.enabled = ['balance', 'money_age', 'budget', 'achievement', 'quick_stats', 'recent'].contains(module.id);
                }
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _saveLayout() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('布局已保存'),
        backgroundColor: AppTheme.successColor,
      ),
    );
    Navigator.pop(context);
  }
}

class _LayoutModule {
  final String id;
  final String name;
  final IconData icon;
  bool enabled;

  _LayoutModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.enabled,
  });
}
