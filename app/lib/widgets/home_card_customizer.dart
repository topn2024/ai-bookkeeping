import 'package:flutter/material.dart';
import '../services/personalization_settings_service.dart';

/// Home card customization widget (第22章首页卡片自定义布局)
class HomeCardCustomizer extends StatefulWidget {
  final HomeCardSettings settings;
  final ValueChanged<HomeCardSettings> onSettingsChanged;

  const HomeCardCustomizer({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<HomeCardCustomizer> createState() => _HomeCardCustomizerState();
}

class _HomeCardCustomizerState extends State<HomeCardCustomizer> {
  late HomeCardSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort cards by order
    final sortedCards = List<HomeCardConfig>.from(_settings.cards)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '首页卡片布局',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '长按拖动调整顺序，点击开关控制显示',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedCards.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              _settings = _settings.reorder(oldIndex, newIndex);
            });
            widget.onSettingsChanged(_settings);
          },
          itemBuilder: (context, index) {
            final card = sortedCards[index];
            return _buildCardItem(card, index);
          },
        ),
      ],
    );
  }

  Widget _buildCardItem(HomeCardConfig card, int index) {
    final theme = Theme.of(context);

    return Container(
      key: ValueKey(card.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: card.visible
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCardIcon(card.id),
                color: card.visible
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          title: Text(
            card.name,
            style: TextStyle(
              color: card.visible
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            card.visible ? '显示中' : '已隐藏',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: card.visible,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.toggleVisibility(card.id);
                  });
                  widget.onSettingsChanged(_settings);
                },
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCardIcon(String cardId) {
    switch (cardId) {
      case 'balance':
        return Icons.account_balance_wallet;
      case 'money_age':
        return Icons.hourglass_empty;
      case 'budget':
        return Icons.savings;
      case 'recent':
        return Icons.receipt_long;
      case 'insights':
        return Icons.lightbulb;
      case 'habits':
        return Icons.emoji_events;
      default:
        return Icons.widgets;
    }
  }
}

/// Quick action customizer widget
class QuickActionCustomizer extends StatefulWidget {
  final List<QuickAction> actions;
  final ValueChanged<List<QuickAction>> onActionsChanged;

  const QuickActionCustomizer({
    super.key,
    required this.actions,
    required this.onActionsChanged,
  });

  @override
  State<QuickActionCustomizer> createState() => _QuickActionCustomizerState();
}

class _QuickActionCustomizerState extends State<QuickActionCustomizer> {
  late List<QuickAction> _actions;

  @override
  void initState() {
    super.initState();
    _actions = List.from(widget.actions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷操作',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '选择首页显示的快捷记账入口',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _actions.map((action) => _buildActionChip(action)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionChip(QuickAction action) {
    final theme = Theme.of(context);

    return FilterChip(
      selected: action.enabled,
      onSelected: (selected) {
        setState(() {
          final index = _actions.indexWhere((a) => a.id == action.id);
          if (index >= 0) {
            _actions[index] = QuickAction(
              id: action.id,
              name: action.name,
              icon: action.icon,
              enabled: selected,
            );
          }
        });
        widget.onActionsChanged(_actions);
      },
      avatar: Icon(
        _getActionIcon(action.icon),
        size: 18,
        color: action.enabled
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(action.name),
    );
  }

  IconData _getActionIcon(String iconName) {
    switch (iconName) {
      case 'mic':
        return Icons.mic;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'edit':
        return Icons.edit;
      case 'bookmark':
        return Icons.bookmark;
      default:
        return Icons.widgets;
    }
  }
}

/// Category pin/hide manager widget
class CategoryPinManager extends StatelessWidget {
  final List<String> allCategories;
  final List<String> pinnedCategories;
  final List<String> hiddenCategories;
  final Map<String, String> categoryNames;
  final Map<String, IconData> categoryIcons;
  final Function(String) onPin;
  final Function(String) onUnpin;
  final Function(String) onHide;
  final Function(String) onShow;

  const CategoryPinManager({
    super.key,
    required this.allCategories,
    required this.pinnedCategories,
    required this.hiddenCategories,
    required this.categoryNames,
    required this.categoryIcons,
    required this.onPin,
    required this.onUnpin,
    required this.onHide,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类管理',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        // Pinned categories
        if (pinnedCategories.isNotEmpty) ...[
          Text(
            '置顶分类',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pinnedCategories.map((id) {
              return _buildCategoryChip(
                context,
                id,
                isPinned: true,
                isHidden: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Normal categories
        Text(
          '常用分类',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allCategories
              .where((id) =>
                  !pinnedCategories.contains(id) && !hiddenCategories.contains(id))
              .map((id) {
            return _buildCategoryChip(
              context,
              id,
              isPinned: false,
              isHidden: false,
            );
          }).toList(),
        ),

        // Hidden categories
        if (hiddenCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '已隐藏',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hiddenCategories.map((id) {
              return _buildCategoryChip(
                context,
                id,
                isPinned: false,
                isHidden: true,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String categoryId, {
    required bool isPinned,
    required bool isHidden,
  }) {
    final theme = Theme.of(context);
    final name = categoryNames[categoryId] ?? categoryId;
    final icon = categoryIcons[categoryId] ?? Icons.category;

    return GestureDetector(
      onLongPress: () {
        _showCategoryOptions(context, categoryId, isPinned, isHidden);
      },
      child: Chip(
        avatar: Icon(
          icon,
          size: 18,
          color: isHidden
              ? theme.colorScheme.onSurfaceVariant
              : isPinned
                  ? theme.colorScheme.primary
                  : null,
        ),
        label: Text(
          name,
          style: TextStyle(
            color: isHidden ? theme.colorScheme.onSurfaceVariant : null,
            decoration: isHidden ? TextDecoration.lineThrough : null,
          ),
        ),
        deleteIcon: isPinned
            ? const Icon(Icons.push_pin, size: 16)
            : isHidden
                ? const Icon(Icons.visibility_off, size: 16)
                : null,
        onDeleted: isPinned || isHidden
            ? () {
                if (isPinned) onUnpin(categoryId);
                if (isHidden) onShow(categoryId);
              }
            : null,
      ),
    );
  }

  void _showCategoryOptions(
    BuildContext context,
    String categoryId,
    bool isPinned,
    bool isHidden,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isPinned && !isHidden)
                ListTile(
                  leading: const Icon(Icons.push_pin),
                  title: const Text('置顶'),
                  onTap: () {
                    onPin(categoryId);
                    Navigator.pop(context);
                  },
                ),
              if (isPinned)
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('取消置顶'),
                  onTap: () {
                    onUnpin(categoryId);
                    Navigator.pop(context);
                  },
                ),
              if (!isHidden)
                ListTile(
                  leading: const Icon(Icons.visibility_off),
                  title: const Text('隐藏'),
                  onTap: () {
                    onHide(categoryId);
                    Navigator.pop(context);
                  },
                ),
              if (isHidden)
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('显示'),
                  onTap: () {
                    onShow(categoryId);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
