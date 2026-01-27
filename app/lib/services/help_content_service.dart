import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/help_content.dart';

/// 帮助内容服务
/// 负责加载、缓存和管理帮助内容
class HelpContentService {
  // 单例模式
  static final HelpContentService _instance = HelpContentService._internal();
  factory HelpContentService() => _instance;
  HelpContentService._internal();

  /// 帮助内容缓存 (pageId -> HelpContent)
  final Map<String, HelpContent> _cache = {};

  /// 模块内容缓存 (module -> List<HelpContent>)
  final Map<String, List<HelpContent>> _moduleCache = {};

  /// 搜索历史记录
  final List<String> _searchHistory = [];

  /// 是否已加载
  bool _isLoaded = false;

  /// 搜索历史记录的最大数量
  static const int _maxSearchHistory = 10;

  /// SharedPreferences key
  static const String _searchHistoryKey = 'help_search_history';
  static const String _viewStatsKey = 'help_view_stats';

  /// 帮助内容查看统计 (pageId -> 查看次数)
  final Map<String, int> _viewStats = {};

  /// 模块文件映射
  static const Map<String, String> _moduleFiles = {
    'home': 'home.json',
    'money_age': 'money_age.json',
    'budget': 'budget.json',
    'accounts': 'accounts.json',
    'categories': 'categories.json',
    'statistics': 'statistics.json',
    'settings': 'settings.json',
    'voice': 'voice.json',
    'ai': 'ai.json',
    'import_export': 'import_export.json',
    'help_feedback': 'help_feedback.json',
    'security': 'security.json',
    'habits': 'habits.json',
    'impulse_control': 'impulse_control.json',
    'family': 'family.json',
    'growth': 'growth.json',
    'data_sync': 'data_sync.json',
    'errors': 'errors.json',
    'monitoring': 'monitoring.json',
    'bill_reminders': 'bill_reminders.json',
  };

  /// 预加载所有帮助内容
  Future<void> preload() async {
    if (_isLoaded) return;

    try {
      for (final entry in _moduleFiles.entries) {
        final module = entry.key;
        final fileName = entry.value;
        await _loadModule(module, fileName);
      }
      _isLoaded = true;
    } catch (e) {
      print('加载帮助内容失败: $e');
      rethrow;
    }
  }

  /// 加载单个模块的帮助内容
  Future<void> _loadModule(String module, String fileName) async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/help/$fileName');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final contentList = jsonData['contents'] as List<dynamic>;

      final moduleContents = <HelpContent>[];
      for (final item in contentList) {
        final content = HelpContent.fromJson(item as Map<String, dynamic>);
        _cache[content.pageId] = content;
        moduleContents.add(content);
      }

      _moduleCache[module] = moduleContents;
    } catch (e) {
      print('加载模块 $module 失败: $e');
      // 继续加载其他模块，不中断整个加载过程
    }
  }

  /// 根据页面ID获取帮助内容
  HelpContent? getContentByPageId(String pageId) {
    return _cache[pageId];
  }

  /// 根据模块获取帮助内容列表
  List<HelpContent> getContentsByModule(String module) {
    return _moduleCache[module] ?? [];
  }

  /// 获取所有帮助内容
  List<HelpContent> getAllContents() {
    return _cache.values.toList();
  }

  /// 获取所有模块名称
  List<String> getAllModules() {
    return _moduleCache.keys.toList();
  }

  /// 搜索帮助内容
  /// 支持按标题、描述、关键词搜索
  List<HelpContent> search(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final results = <HelpContent>[];

    for (final content in _cache.values) {
      // 计算相关度分数
      double score = 0.0;

      // 标题完全匹配：+10分
      if (content.title.toLowerCase() == lowerQuery) {
        score += 10.0;
      }
      // 标题包含：+5分
      else if (content.title.toLowerCase().contains(lowerQuery)) {
        score += 5.0;
      }

      // 描述包含：+3分
      if (content.description.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }

      // 关键词匹配：+2分
      if (content.keywords
          .any((k) => k.toLowerCase().contains(lowerQuery))) {
        score += 2.0;
      }

      // 使用场景包含：+1分
      if (content.useCases
          .any((u) => u.toLowerCase().contains(lowerQuery))) {
        score += 1.0;
      }

      // 步骤包含：+1分
      if (content.steps.any((s) =>
          s.title.toLowerCase().contains(lowerQuery) ||
          s.description.toLowerCase().contains(lowerQuery))) {
        score += 1.0;
      }

      if (score > 0) {
        results.add(content);
      }
    }

    // 按相关度排序（这里简化处理，实际应该按score排序）
    return results;
  }

  /// 加载搜索历史
  Future<void> loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];
      _searchHistory.clear();
      _searchHistory.addAll(history);
    } catch (e) {
      print('加载搜索历史失败: $e');
    }
  }

  /// 添加搜索历史
  Future<void> addSearchHistory(String query) async {
    if (query.isEmpty) return;

    try {
      // 移除重复项
      _searchHistory.remove(query);
      // 添加到开头
      _searchHistory.insert(0, query);
      // 限制数量
      if (_searchHistory.length > _maxSearchHistory) {
        _searchHistory.removeRange(_maxSearchHistory, _searchHistory.length);
      }

      // 保存到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchHistoryKey, _searchHistory);
    } catch (e) {
      print('保存搜索历史失败: $e');
    }
  }

  /// 清除搜索历史
  Future<void> clearSearchHistory() async {
    try {
      _searchHistory.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      print('清除搜索历史失败: $e');
    }
  }

  /// 获取搜索历史
  List<String> getSearchHistory() {
    return List.from(_searchHistory);
  }

  /// 加载查看统计
  Future<void> loadViewStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_viewStatsKey);
      if (statsJson != null) {
        final stats = json.decode(statsJson) as Map<String, dynamic>;
        _viewStats.clear();
        stats.forEach((key, value) {
          _viewStats[key] = value as int;
        });
      }
    } catch (e) {
      print('加载查看统计失败: $e');
    }
  }

  /// 记录帮助内容查看
  Future<void> recordView(String pageId) async {
    try {
      _viewStats[pageId] = (_viewStats[pageId] ?? 0) + 1;

      // 保存到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewStatsKey, json.encode(_viewStats));
    } catch (e) {
      print('保存查看统计失败: $e');
    }
  }

  /// 获取查看次数
  int getViewCount(String pageId) {
    return _viewStats[pageId] ?? 0;
  }

  /// 获取热门帮助内容（按查看次数排序）
  List<HelpContent> getPopularContents({int limit = 10}) {
    final sortedEntries = _viewStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final popularContents = <HelpContent>[];
    for (final entry in sortedEntries.take(limit)) {
      final content = _cache[entry.key];
      if (content != null) {
        popularContents.add(content);
      }
    }

    return popularContents;
  }

  /// 清除查看统计
  Future<void> clearViewStats() async {
    try {
      _viewStats.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewStatsKey);
    } catch (e) {
      print('清除查看统计失败: $e');
    }
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _moduleCache.clear();
    _isLoaded = false;
  }

  /// 是否已加载
  bool get isLoaded => _isLoaded;
}
