import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/color_picker.dart';

/// 自定义主题管理页面
class CustomThemePage extends ConsumerWidget {
  const CustomThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isMember = themeState.isMember;
    final customThemes = themeState.customThemes;
    final activeTheme = themeState.activeCustomTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义主题'),
        actions: [
          // 开发者模式：切换会员状态
          IconButton(
            icon: Icon(isMember ? Icons.star : Icons.star_border),
            tooltip: isMember ? '会员已激活' : '非会员',
            onPressed: () {
              // 开发测试用：切换会员状态
              ref.read(themeProvider.notifier).setMemberStatus(!isMember);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isMember ? '已切换为非会员' : '已切换为会员'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: isMember
          ? _buildMemberContent(context, ref, customThemes, activeTheme)
          : _buildNonMemberContent(context, ref),
      floatingActionButton: isMember
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateThemeDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新建主题'),
            )
          : null,
    );
  }

  Widget _buildNonMemberContent(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.palette,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '自定义主题',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '自定义主题功能',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '当前版本免费开放所有功能！\n\n'
              '您可以：\n'
              '- 完全自定义应用配色\n'
              '- 创建多个个性化主题\n'
              '- 自定义收入/支出/转账颜色\n'
              '- 调整卡片圆角等样式\n'
              '- 使用精美预设主题模板',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // 自动激活所有功能（当前版本免费）
                ref.read(themeProvider.notifier).setMemberStatus(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已激活！现在可以使用自定义主题了'),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('激活自定义主题'),
            ),
            const SizedBox(height: 16),
            // 预览预设主题
            TextButton(
              onPressed: () => _showPresetThemesPreview(context),
              child: const Text('预览预设主题'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberContent(
    BuildContext context,
    WidgetRef ref,
    List<CustomTheme> customThemes,
    CustomTheme? activeTheme,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前主题状态
        _buildCurrentThemeCard(context, ref, activeTheme),
        const SizedBox(height: 24),
        // 预设主题
        _buildSectionTitle(context, '预设主题模板'),
        const SizedBox(height: 8),
        _buildPresetThemes(context, ref),
        const SizedBox(height: 24),
        // 我的主题
        _buildSectionTitle(context, '我的自定义主题'),
        const SizedBox(height: 8),
        if (customThemes.isEmpty)
          _buildEmptyCustomThemes(context)
        else
          _buildCustomThemesList(context, ref, customThemes, activeTheme),
      ],
    );
  }

  Widget _buildCurrentThemeCard(
    BuildContext context,
    WidgetRef ref,
    CustomTheme? activeTheme,
  ) {
    final themeState = ref.watch(themeProvider);
    final isUsingCustom = themeState.isUsingCustomTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '当前主题',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isUsingCustom && activeTheme != null) ...[
              Text(
                activeTheme.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildColorPreviewRow(context, activeTheme),
            ] else ...[
              Text(
                '使用预设主题',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppColorThemes.getTheme(themeState.colorTheme).name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (isUsingCustom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(themeProvider.notifier).setColorTheme(AppColorTheme.blue);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('恢复默认'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openThemeEditor(context, ref, activeTheme!),
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorPreviewRow(BuildContext context, CustomTheme theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildColorChip('主色', theme.primaryColor),
        _buildColorChip('收入', theme.incomeColor),
        _buildColorChip('支出', theme.expenseColor),
        _buildColorChip('转账', theme.transferColor),
        _buildColorChip('背景', theme.backgroundColor),
      ],
    );
  }

  Widget _buildColorChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildPresetThemes(BuildContext context, WidgetRef ref) {
    final presets = CustomTheme.getPresetThemes();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = presets[index];
          return _buildPresetThemeCard(context, ref, preset);
        },
      ),
    );
  }

  Widget _buildPresetThemeCard(
    BuildContext context,
    WidgetRef ref,
    CustomTheme preset,
  ) {
    return GestureDetector(
      onTap: () => _showPresetActionSheet(context, ref, preset),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: preset.primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMiniColorDot(preset.incomeColor),
                          const SizedBox(width: 4),
                          _buildMiniColorDot(preset.expenseColor),
                          const SizedBox(width: 4),
                          _buildMiniColorDot(preset.transferColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: preset.cardColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Text(
                preset.name,
                style: TextStyle(
                  fontSize: 12,
                  color: preset.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniColorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  Widget _buildEmptyCustomThemes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.palette_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有自定义主题',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建您的第一个主题',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomThemesList(
    BuildContext context,
    WidgetRef ref,
    List<CustomTheme> themes,
    CustomTheme? activeTheme,
  ) {
    return Column(
      children: themes.map((theme) {
        final isActive = activeTheme?.id == theme.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isActive
                  ? Icon(
                      Icons.check,
                      color: theme.primaryColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
            title: Text(theme.name),
            subtitle: Text(
              '创建于 ${_formatDate(theme.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isActive)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: '应用此主题',
                    onPressed: () {
                      ref.read(themeProvider.notifier).applyCustomTheme(theme);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑',
                  onPressed: () => _openThemeEditor(context, ref, theme),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(context, ref, theme),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showCreateThemeDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '主题名称',
                hintText: '输入主题名称',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              final theme = await ref.read(themeProvider.notifier).createCustomTheme(
                name: nameController.text.trim(),
              );
              if (context.mounted) {
                _openThemeEditor(context, ref, theme);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showPresetActionSheet(
    BuildContext context,
    WidgetRef ref,
    CustomTheme preset,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: preset.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Text(preset.name),
              subtitle: const Text('预设主题'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('直接应用'),
              subtitle: const Text('立即使用此主题'),
              onTap: () {
                Navigator.pop(context);
                ref.read(themeProvider.notifier).applyCustomTheme(preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制并编辑'),
              subtitle: const Text('基于此主题创建新主题'),
              onTap: () async {
                Navigator.pop(context);
                final nameController = TextEditingController(
                  text: '${preset.name} - 副本',
                );
                if (!context.mounted) return;

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('复制主题'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '新主题名称',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('创建'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  final newTheme = await ref.read(themeProvider.notifier).createFromPreset(
                    preset,
                    nameController.text.trim(),
                  );
                  if (context.mounted) {
                    _openThemeEditor(context, ref, newTheme);
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openThemeEditor(BuildContext context, WidgetRef ref, CustomTheme theme) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemeEditorPage(theme: theme),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除主题'),
        content: Text('确定要删除主题"${theme.name}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(themeProvider.notifier).deleteCustomTheme(theme.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showPresetThemesPreview(BuildContext context) {
    final presets = CustomTheme.getPresetThemes();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '预设主题预览',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: preset.backgroundColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: preset.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                preset.name,
                                style: TextStyle(
                                  color: preset.primaryColor.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPreviewColorItem('主色', preset.primaryColor),
                              _buildPreviewColorItem('收入', preset.incomeColor),
                              _buildPreviewColorItem('支出', preset.expenseColor),
                              _buildPreviewColorItem('转账', preset.transferColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewColorItem(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// 主题编辑器页面
class ThemeEditorPage extends ConsumerStatefulWidget {
  final CustomTheme theme;

  const ThemeEditorPage({super.key, required this.theme});

  @override
  ConsumerState<ThemeEditorPage> createState() => _ThemeEditorPageState();
}

class _ThemeEditorPageState extends ConsumerState<ThemeEditorPage> {
  late CustomTheme _theme;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
  }

  void _updateTheme(CustomTheme Function(CustomTheme) updater) {
    setState(() {
      _theme = updater(_theme);
      _hasChanges = true;
    });
  }

  Future<void> _saveTheme() async {
    await ref.read(themeProvider.notifier).updateCustomTheme(_theme);
    ref.read(themeProvider.notifier).applyCustomTheme(_theme);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题已保存并应用')),
      );
      Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃更改？'),
        content: const Text('您有未保存的更改，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('编辑 ${_theme.name}'),
          actions: [
            TextButton.icon(
              onPressed: _hasChanges ? _saveTheme : null,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 预览卡片
            _buildPreviewCard(),
            const SizedBox(height: 24),
            // 基本信息
            _buildSectionTitle('基本信息'),
            _buildNameField(),
            const SizedBox(height: 24),
            // 主要颜色
            _buildSectionTitle('主要颜色'),
            _buildColorSection([
              ThemeColorType.primary,
              ThemeColorType.secondary,
            ]),
            const SizedBox(height: 24),
            // 交易颜色
            _buildSectionTitle('交易颜色'),
            _buildColorSection([
              ThemeColorType.income,
              ThemeColorType.expense,
              ThemeColorType.transfer,
            ]),
            const SizedBox(height: 24),
            // 界面颜色
            _buildSectionTitle('界面颜色'),
            _buildColorSection([
              ThemeColorType.background,
              ThemeColorType.surface,
              ThemeColorType.card,
              ThemeColorType.divider,
            ]),
            const SizedBox(height: 24),
            // 文字颜色
            _buildSectionTitle('文字颜色'),
            _buildColorSection([
              ThemeColorType.textPrimary,
              ThemeColorType.textSecondary,
            ]),
            const SizedBox(height: 24),
            // 样式设置
            _buildSectionTitle('样式设置'),
            _buildStyleSettings(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      color: _theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主题预览',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _theme.backgroundColor,
                borderRadius: BorderRadius.circular(_theme.cardBorderRadius),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _theme.primaryColor,
                          borderRadius: BorderRadius.circular(_theme.buttonBorderRadius),
                        ),
                        child: const Text(
                          '主按钮',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _theme.secondaryColor,
                          borderRadius: BorderRadius.circular(_theme.buttonBorderRadius),
                        ),
                        child: const Text(
                          '次按钮',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPreviewAmount('+¥1,234', _theme.incomeColor),
                      _buildPreviewAmount('-¥567', _theme.expenseColor),
                      _buildPreviewAmount('¥890', _theme.transferColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这是主要文字样式',
              style: TextStyle(color: _theme.textPrimaryColor),
            ),
            Text(
              '这是次要文字样式',
              style: TextStyle(color: _theme.textSecondaryColor),
            ),
            Divider(color: _theme.dividerColor),
            Text(
              '分隔线预览',
              style: TextStyle(
                color: _theme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewAmount(String amount, Color color) {
    return Text(
      amount,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      decoration: const InputDecoration(
        labelText: '主题名称',
        border: OutlineInputBorder(),
      ),
      controller: TextEditingController(text: _theme.name),
      onChanged: (value) {
        _updateTheme((t) => t.copyWith(name: value));
      },
    );
  }

  Widget _buildColorSection(List<ThemeColorType> types) {
    return Card(
      child: Column(
        children: types.map((type) {
          return ColorPickerRow(
            label: type.displayName,
            description: type.description,
            color: type.getColor(_theme),
            onColorChanged: (color) {
              _updateTheme((t) {
                switch (type) {
                  case ThemeColorType.primary:
                    return t.copyWith(primaryColor: color);
                  case ThemeColorType.secondary:
                    return t.copyWith(secondaryColor: color);
                  case ThemeColorType.background:
                    return t.copyWith(backgroundColor: color);
                  case ThemeColorType.surface:
                    return t.copyWith(surfaceColor: color);
                  case ThemeColorType.income:
                    return t.copyWith(incomeColor: color);
                  case ThemeColorType.expense:
                    return t.copyWith(expenseColor: color);
                  case ThemeColorType.transfer:
                    return t.copyWith(transferColor: color);
                  case ThemeColorType.textPrimary:
                    return t.copyWith(textPrimaryColor: color);
                  case ThemeColorType.textSecondary:
                    return t.copyWith(textSecondaryColor: color);
                  case ThemeColorType.card:
                    return t.copyWith(cardColor: color);
                  case ThemeColorType.divider:
                    return t.copyWith(dividerColor: color);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStyleSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('卡片圆角'),
            subtitle: Text('${_theme.cardBorderRadius.round()}px'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _theme.cardBorderRadius,
                min: 0,
                max: 24,
                divisions: 24,
                onChanged: (value) {
                  _updateTheme((t) => t.copyWith(cardBorderRadius: value));
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('按钮圆角'),
            subtitle: Text('${_theme.buttonBorderRadius.round()}px'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _theme.buttonBorderRadius,
                min: 0,
                max: 24,
                divisions: 24,
                onChanged: (value) {
                  _updateTheme((t) => t.copyWith(buttonBorderRadius: value));
                },
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Material 3'),
            subtitle: const Text('使用 Material Design 3 样式'),
            value: _theme.useMaterial3,
            onChanged: (value) {
              _updateTheme((t) => t.copyWith(useMaterial3: value));
            },
          ),
        ],
      ),
    );
  }
}
