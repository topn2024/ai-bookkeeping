import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personalization settings service (第22章个性化与社交设计)
class PersonalizationSettingsService {
  static const String _keyThemeColor = 'personalization_theme_color';
  static const String _keyHomeCards = 'personalization_home_cards';
  static const String _keyQuickActions = 'personalization_quick_actions';
  static const String _keyPinnedCategories = 'personalization_pinned_categories';
  static const String _keyHiddenCategories = 'personalization_hidden_categories';
  static const String _keyLayoutDensity = 'personalization_layout_density';

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ===== Theme Color Customization =====

  /// Get current theme color (6 presets + custom)
  Future<ThemeColorSetting> getThemeColor() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyThemeColor);
    if (json == null) {
      return ThemeColorSetting.defaultBlue();
    }
    return ThemeColorSetting.fromJson(jsonDecode(json));
  }

  /// Set theme color
  Future<void> setThemeColor(ThemeColorSetting setting) async {
    await _ensureInitialized();
    await _prefs?.setString(_keyThemeColor, jsonEncode(setting.toJson()));
  }

  /// Preset theme colors
  static List<ThemeColorSetting> get presetColors => [
        ThemeColorSetting(
          id: 'blue',
          name: '默认蓝',
          color: const Color(0xFF2196F3),
          isPreset: true,
        ),
        ThemeColorSetting(
          id: 'green',
          name: '清新绿',
          color: const Color(0xFF4CAF50),
          isPreset: true,
        ),
        ThemeColorSetting(
          id: 'purple',
          name: '优雅紫',
          color: const Color(0xFF9C27B0),
          isPreset: true,
        ),
        ThemeColorSetting(
          id: 'orange',
          name: '活力橙',
          color: const Color(0xFFFF9800),
          isPreset: true,
        ),
        ThemeColorSetting(
          id: 'red',
          name: '热情红',
          color: const Color(0xFFF44336),
          isPreset: true,
        ),
        ThemeColorSetting(
          id: 'teal',
          name: '沉稳青',
          color: const Color(0xFF009688),
          isPreset: true,
        ),
      ];

  // ===== Home Cards Customization =====

  /// Get home card settings
  Future<HomeCardSettings> getHomeCardSettings() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyHomeCards);
    if (json == null) {
      return HomeCardSettings.defaultSettings();
    }
    return HomeCardSettings.fromJson(jsonDecode(json));
  }

  /// Set home card settings
  Future<void> setHomeCardSettings(HomeCardSettings settings) async {
    await _ensureInitialized();
    await _prefs?.setString(_keyHomeCards, jsonEncode(settings.toJson()));
  }

  // ===== Quick Actions Customization =====

  /// Get quick actions
  Future<List<QuickAction>> getQuickActions() async {
    await _ensureInitialized();
    final json = _prefs?.getString(_keyQuickActions);
    if (json == null) {
      return QuickAction.defaultActions();
    }
    final list = jsonDecode(json) as List;
    return list.map((e) => QuickAction.fromJson(e)).toList();
  }

  /// Set quick actions
  Future<void> setQuickActions(List<QuickAction> actions) async {
    await _ensureInitialized();
    await _prefs?.setString(
      _keyQuickActions,
      jsonEncode(actions.map((e) => e.toJson()).toList()),
    );
  }

  // ===== Category Customization =====

  /// Get pinned categories
  Future<List<String>> getPinnedCategories() async {
    await _ensureInitialized();
    return _prefs?.getStringList(_keyPinnedCategories) ?? [];
  }

  /// Set pinned categories
  Future<void> setPinnedCategories(List<String> categories) async {
    await _ensureInitialized();
    await _prefs?.setStringList(_keyPinnedCategories, categories);
  }

  /// Get hidden categories
  Future<List<String>> getHiddenCategories() async {
    await _ensureInitialized();
    return _prefs?.getStringList(_keyHiddenCategories) ?? [];
  }

  /// Set hidden categories
  Future<void> setHiddenCategories(List<String> categories) async {
    await _ensureInitialized();
    await _prefs?.setStringList(_keyHiddenCategories, categories);
  }

  /// Pin a category
  Future<void> pinCategory(String categoryId) async {
    final pinned = await getPinnedCategories();
    if (!pinned.contains(categoryId)) {
      pinned.insert(0, categoryId);
      await setPinnedCategories(pinned);
    }
  }

  /// Unpin a category
  Future<void> unpinCategory(String categoryId) async {
    final pinned = await getPinnedCategories();
    pinned.remove(categoryId);
    await setPinnedCategories(pinned);
  }

  /// Hide a category
  Future<void> hideCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    if (!hidden.contains(categoryId)) {
      hidden.add(categoryId);
      await setHiddenCategories(hidden);
    }
  }

  /// Show a hidden category
  Future<void> showCategory(String categoryId) async {
    final hidden = await getHiddenCategories();
    hidden.remove(categoryId);
    await setHiddenCategories(hidden);
  }

  // ===== Layout Density =====

  /// Get layout density
  Future<LayoutDensity> getLayoutDensity() async {
    await _ensureInitialized();
    final value = _prefs?.getString(_keyLayoutDensity);
    return LayoutDensity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayoutDensity.standard,
    );
  }

  /// Set layout density
  Future<void> setLayoutDensity(LayoutDensity density) async {
    await _ensureInitialized();
    await _prefs?.setString(_keyLayoutDensity, density.name);
  }

  /// Ensure SharedPreferences is initialized
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  /// Reset all personalization settings
  Future<void> resetAll() async {
    await _ensureInitialized();
    await _prefs?.remove(_keyThemeColor);
    await _prefs?.remove(_keyHomeCards);
    await _prefs?.remove(_keyQuickActions);
    await _prefs?.remove(_keyPinnedCategories);
    await _prefs?.remove(_keyHiddenCategories);
    await _prefs?.remove(_keyLayoutDensity);
  }
}

/// Theme color setting
class ThemeColorSetting {
  final String id;
  final String name;
  final Color color;
  final bool isPreset;

  ThemeColorSetting({
    required this.id,
    required this.name,
    required this.color,
    this.isPreset = false,
  });

  factory ThemeColorSetting.defaultBlue() => ThemeColorSetting(
        id: 'blue',
        name: '默认蓝',
        color: const Color(0xFF2196F3),
        isPreset: true,
      );

  factory ThemeColorSetting.custom(Color color) => ThemeColorSetting(
        id: 'custom',
        name: '自定义',
        color: color,
        isPreset: false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'isPreset': isPreset,
      };

  factory ThemeColorSetting.fromJson(Map<String, dynamic> json) =>
      ThemeColorSetting(
        id: json['id'] as String,
        name: json['name'] as String,
        color: Color(json['color'] as int),
        isPreset: json['isPreset'] as bool? ?? false,
      );
}

/// Home card settings
class HomeCardSettings {
  final List<HomeCardConfig> cards;

  HomeCardSettings({required this.cards});

  factory HomeCardSettings.defaultSettings() => HomeCardSettings(
        cards: [
          HomeCardConfig(id: 'balance', name: '账户余额', visible: true, order: 0),
          HomeCardConfig(id: 'money_age', name: '钱龄概览', visible: true, order: 1),
          HomeCardConfig(id: 'budget', name: '预算进度', visible: true, order: 2),
          HomeCardConfig(id: 'recent', name: '最近交易', visible: true, order: 3),
          HomeCardConfig(id: 'insights', name: '智能洞察', visible: true, order: 4),
          HomeCardConfig(id: 'habits', name: '习惯打卡', visible: true, order: 5),
        ],
      );

  Map<String, dynamic> toJson() => {
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory HomeCardSettings.fromJson(Map<String, dynamic> json) =>
      HomeCardSettings(
        cards: (json['cards'] as List)
            .map((e) => HomeCardConfig.fromJson(e))
            .toList(),
      );

  /// Reorder cards
  HomeCardSettings reorder(int oldIndex, int newIndex) {
    final newCards = List<HomeCardConfig>.from(cards);
    final item = newCards.removeAt(oldIndex);
    newCards.insert(newIndex, item);

    // Update order values
    for (int i = 0; i < newCards.length; i++) {
      newCards[i] = newCards[i].copyWith(order: i);
    }

    return HomeCardSettings(cards: newCards);
  }

  /// Toggle card visibility
  HomeCardSettings toggleVisibility(String cardId) {
    return HomeCardSettings(
      cards: cards.map((c) {
        if (c.id == cardId) {
          return c.copyWith(visible: !c.visible);
        }
        return c;
      }).toList(),
    );
  }
}

/// Home card configuration
class HomeCardConfig {
  final String id;
  final String name;
  final bool visible;
  final int order;

  HomeCardConfig({
    required this.id,
    required this.name,
    required this.visible,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'order': order,
      };

  factory HomeCardConfig.fromJson(Map<String, dynamic> json) => HomeCardConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        visible: json['visible'] as bool,
        order: json['order'] as int,
      );

  HomeCardConfig copyWith({
    String? id,
    String? name,
    bool? visible,
    int? order,
  }) =>
      HomeCardConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        visible: visible ?? this.visible,
        order: order ?? this.order,
      );
}

/// Quick action for home screen
class QuickAction {
  final String id;
  final String name;
  final String icon;
  final bool enabled;

  QuickAction({
    required this.id,
    required this.name,
    required this.icon,
    this.enabled = true,
  });

  static List<QuickAction> defaultActions() => [
        QuickAction(id: 'voice', name: '语音记账', icon: 'mic'),
        QuickAction(id: 'camera', name: '拍照记账', icon: 'camera_alt'),
        QuickAction(id: 'manual', name: '手动记账', icon: 'edit'),
        QuickAction(id: 'template', name: '模板记账', icon: 'bookmark'),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'enabled': enabled,
      };

  factory QuickAction.fromJson(Map<String, dynamic> json) => QuickAction(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// Layout density options
enum LayoutDensity {
  compact,
  standard,
  comfortable,
}

extension LayoutDensityExtension on LayoutDensity {
  String get displayName {
    switch (this) {
      case LayoutDensity.compact:
        return '紧凑';
      case LayoutDensity.standard:
        return '标准';
      case LayoutDensity.comfortable:
        return '宽松';
    }
  }

  double get cardPadding {
    switch (this) {
      case LayoutDensity.compact:
        return 8.0;
      case LayoutDensity.standard:
        return 16.0;
      case LayoutDensity.comfortable:
        return 24.0;
    }
  }

  double get listItemHeight {
    switch (this) {
      case LayoutDensity.compact:
        return 48.0;
      case LayoutDensity.standard:
        return 64.0;
      case LayoutDensity.comfortable:
        return 80.0;
    }
  }
}
