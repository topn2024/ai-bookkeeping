import 'package:flutter/foundation.dart';

import '../core/asr_config.dart';
import '../core/asr_models.dart';
import '../core/asr_plugin_interface.dart';

/// ASR插件注册中心
///
/// 管理所有已注册的ASR插件
class ASRPluginRegistry {
  static final ASRPluginRegistry _instance = ASRPluginRegistry._internal();
  factory ASRPluginRegistry() => _instance;
  ASRPluginRegistry._internal();

  /// 已注册的插件（按优先级排序）
  final Map<String, ASRPluginInterface> _plugins = {};

  /// 插件优先级缓存
  final List<ASRPluginInterface> _sortedPlugins = [];

  /// 是否已排序
  bool _needsSort = true;

  /// 获取所有已注册插件
  List<ASRPluginInterface> get plugins {
    if (_needsSort) {
      _sortPlugins();
    }
    return List.unmodifiable(_sortedPlugins);
  }

  /// 获取已注册插件数量
  int get pluginCount => _plugins.length;

  /// 注册插件
  void register(ASRPluginInterface plugin) {
    if (_plugins.containsKey(plugin.pluginId)) {
      debugPrint('[ASRPluginRegistry] 插件 ${plugin.pluginId} 已存在，将被替换');
      _plugins[plugin.pluginId]?.dispose();
    }

    _plugins[plugin.pluginId] = plugin;
    _needsSort = true;
    debugPrint(
        '[ASRPluginRegistry] 注册插件: ${plugin.pluginId} (优先级: ${plugin.priority})');
  }

  /// 批量注册插件
  void registerAll(List<ASRPluginInterface> plugins) {
    for (final plugin in plugins) {
      register(plugin);
    }
  }

  /// 注销插件
  void unregister(String pluginId) {
    final plugin = _plugins.remove(pluginId);
    if (plugin != null) {
      _needsSort = true;
      debugPrint('[ASRPluginRegistry] 注销插件: $pluginId');
      plugin.dispose();
    }
  }

  /// 获取指定插件
  ASRPluginInterface? getPlugin(String pluginId) {
    return _plugins[pluginId];
  }

  /// 检查插件是否已注册
  bool hasPlugin(String pluginId) {
    return _plugins.containsKey(pluginId);
  }

  /// 获取指定类型的插件
  T? getPluginOfType<T extends ASRPluginInterface>() {
    for (final plugin in _plugins.values) {
      if (plugin is T) return plugin;
    }
    return null;
  }

  /// 获取所有在线插件（按优先级排序）
  List<ASRPluginInterface> get onlinePlugins {
    return plugins.where((p) => p.capabilities.requiresNetwork).toList();
  }

  /// 获取所有离线插件（按优先级排序）
  List<ASRPluginInterface> get offlinePlugins {
    return plugins.where((p) => !p.capabilities.requiresNetwork).toList();
  }

  /// 获取支持流式识别的插件（按优先级排序）
  List<ASRPluginInterface> get streamingPlugins {
    return plugins.where((p) => p.capabilities.supportsStreaming).toList();
  }

  /// 获取支持批量识别的插件（按优先级排序）
  List<ASRPluginInterface> get batchPlugins {
    return plugins.where((p) => p.capabilities.supportsBatch).toList();
  }

  /// 初始化所有插件
  Future<void> initializeAll({ASRPluginConfig? config}) async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.initialize(config: config);
        debugPrint('[ASRPluginRegistry] 初始化插件成功: ${plugin.pluginId}');
      } catch (e) {
        debugPrint('[ASRPluginRegistry] 初始化插件失败: ${plugin.pluginId}, 错误: $e');
      }
    }
  }

  /// 检查所有插件可用性
  Future<Map<String, ASRAvailability>> checkAllAvailability() async {
    final results = <String, ASRAvailability>{};

    for (final plugin in _plugins.values) {
      try {
        results[plugin.pluginId] = await plugin.checkAvailability();
      } catch (e) {
        results[plugin.pluginId] = ASRAvailability.unavailable('检查失败: $e');
      }
    }

    return results;
  }

  /// 按优先级排序插件
  void _sortPlugins() {
    _sortedPlugins.clear();
    _sortedPlugins.addAll(_plugins.values);
    _sortedPlugins.sort((a, b) => a.priority.compareTo(b.priority));
    _needsSort = false;
  }

  /// 释放所有插件
  Future<void> disposeAll() async {
    for (final plugin in _plugins.values) {
      try {
        await plugin.dispose();
      } catch (e) {
        debugPrint('[ASRPluginRegistry] 释放插件失败: ${plugin.pluginId}, 错误: $e');
      }
    }
    _plugins.clear();
    _sortedPlugins.clear();
  }

  /// 重置注册中心（用于测试）
  @visibleForTesting
  void reset() {
    _plugins.clear();
    _sortedPlugins.clear();
    _needsSort = true;
  }
}
