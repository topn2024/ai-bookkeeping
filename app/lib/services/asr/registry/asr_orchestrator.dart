import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/asr_config.dart';
import '../core/asr_exception.dart';
import '../core/asr_models.dart';
import '../core/asr_plugin_interface.dart';
import '../postprocess/asr_postprocessor.dart';
import '../utils/network_checker.dart';
import '../utils/session_manager.dart';
import 'asr_plugin_registry.dart';

/// ASR调度器
///
/// 负责选择合适的ASR插件、处理降级和重试逻辑
class ASROrchestrator {
  final ASRPluginRegistry _registry;
  final NetworkChecker _networkChecker;
  final SessionManager _sessionManager;
  final ASRPostprocessor? _postprocessor;

  /// 是否正在识别
  bool _isRecognizing = false;

  /// 禁用的插件列表（临时禁用，如余额不足）
  final Set<String> _disabledPlugins = {};

  /// 插件禁用恢复时间
  final Map<String, DateTime> _disabledUntil = {};

  ASROrchestrator({
    ASRPluginRegistry? registry,
    NetworkChecker? networkChecker,
    SessionManager? sessionManager,
    ASRPostprocessor? postprocessor,
  })  : _registry = registry ?? ASRPluginRegistry(),
        _networkChecker = networkChecker ?? NetworkChecker(),
        _sessionManager = sessionManager ?? SessionManager(),
        _postprocessor = postprocessor;

  /// 是否正在识别
  bool get isRecognizing => _isRecognizing;

  /// 是否已取消
  bool get isCancelled => _sessionManager.isCancelled;

  /// 获取可用插件列表（按优先级排序）
  Future<List<ASRPluginInterface>> getAvailablePlugins({
    bool requiresNetwork = false,
    bool streaming = false,
  }) async {
    final hasNetwork = await _networkChecker.isOnline();
    final now = DateTime.now();

    // 清理已过期的禁用状态
    _disabledUntil.removeWhere((_, until) => now.isAfter(until));
    _disabledPlugins.removeWhere((id) => !_disabledUntil.containsKey(id));

    return _registry.plugins.where((plugin) {
      // 检查是否被临时禁用
      if (_disabledPlugins.contains(plugin.pluginId)) {
        return false;
      }

      // 检查网络要求
      if (plugin.capabilities.requiresNetwork && !hasNetwork) {
        return false;
      }

      // 检查是否只要离线插件
      if (requiresNetwork && !plugin.capabilities.requiresNetwork) {
        return false;
      }

      // 检查流式支持
      if (streaming && !plugin.capabilities.supportsStreaming) {
        return false;
      }

      // 检查插件状态
      if (plugin.state == ASRPluginState.disposed ||
          plugin.state == ASRPluginState.error) {
        return false;
      }

      return true;
    }).toList();
  }

  /// 选择最佳插件
  Future<ASRPluginInterface?> selectBestPlugin({
    bool streaming = false,
  }) async {
    final plugins = await getAvailablePlugins(streaming: streaming);
    return plugins.isNotEmpty ? plugins.first : null;
  }

  /// 批量识别
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint(
        '[ASROrchestrator] transcribe开始，音频大小: ${audio.data.length} bytes');

    _isRecognizing = true;
    final sessionId = _sessionManager.startSession();

    try {
      final plugins = await getAvailablePlugins();
      if (plugins.isEmpty) {
        throw ASRException(
          '没有可用的ASR插件',
          errorCode: ASRErrorCode.noAvailablePlugin,
        );
      }

      Object? lastError;

      // 按优先级尝试各个插件
      for (final plugin in plugins) {
        if (!_sessionManager.isSessionValid(sessionId)) {
          debugPrint('[ASROrchestrator] 会话已失效，停止尝试');
          break;
        }

        debugPrint('[ASROrchestrator] 尝试插件: ${plugin.pluginId}');

        try {
          final result = await plugin.transcribe(audio);
          debugPrint(
              '[ASROrchestrator] ${plugin.pluginId} 成功: ${result.text}');

          return _postProcess(
              result.copyWith(pluginId: plugin.pluginId));
        } catch (e) {
          lastError = e;
          debugPrint('[ASROrchestrator] ${plugin.pluginId} 失败: $e');

          // 检查是否应该降级
          if (e is ASRException && !e.shouldFallback) {
            rethrow;
          }

          // 检查是否需要临时禁用插件
          _handlePluginError(plugin, e);
        }
      }

      // 所有插件都失败
      if (lastError != null) {
        throw lastError;
      }

      throw ASRException(
        '所有ASR插件都失败了',
        errorCode: ASRErrorCode.serverError,
      );
    } finally {
      _isRecognizing = false;
      _sessionManager.endSession(sessionId);
    }
  }

  /// 流式识别
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[ASROrchestrator] transcribeStream 开始');

    // 防止并发
    if (_isRecognizing) {
      debugPrint('[ASROrchestrator] 取消之前的识别');
      await cancelTranscription();
    }

    _isRecognizing = true;
    final sessionId = _sessionManager.startSession();

    try {
      final plugins = await getAvailablePlugins(streaming: true);
      if (plugins.isEmpty) {
        throw ASRException(
          '没有可用的流式ASR插件',
          errorCode: ASRErrorCode.noAvailablePlugin,
        );
      }

      bool success = false;
      Object? lastError;

      // 按优先级尝试各个插件
      for (final plugin in plugins) {
        if (!_sessionManager.isSessionValid(sessionId)) {
          debugPrint('[ASROrchestrator] 会话已失效，停止尝试');
          break;
        }

        if (success) break;

        debugPrint('[ASROrchestrator] 尝试流式插件: ${plugin.pluginId}');

        try {
          // 注意：audioStream 是单订阅流，只能被一个插件消费
          // 如果当前插件失败，后续插件无法重新读取已消费的数据
          // 因此流式识别不支持跨插件降级，失败后直接退出循环
          await for (final partial in plugin.transcribeStream(audioStream)) {
            if (!_sessionManager.isSessionValid(sessionId)) {
              // 已取消，但仍然处理最终结果
              if (partial.isFinal && partial.text.isNotEmpty) {
                debugPrint(
                    '[ASROrchestrator] 已取消，但收到最终结果，仍然yield: "${partial.text}"');
                yield _postProcessPartial(
                    ASRPartialResult(
                      text: partial.text,
                      isFinal: partial.isFinal,
                      index: partial.index,
                      confidence: partial.confidence,
                      pluginId: plugin.pluginId,
                    ));
              }
              debugPrint('[ASROrchestrator] 已取消，停止yield');
              break;
            }

            success = true;
            yield _postProcessPartial(
                ASRPartialResult(
                  text: partial.text,
                  isFinal: partial.isFinal,
                  index: partial.index,
                  confidence: partial.confidence,
                  pluginId: plugin.pluginId,
                ));
          }

          if (success) {
            debugPrint('[ASROrchestrator] ${plugin.pluginId} 流式识别成功');
            break;
          }
        } catch (e) {
          lastError = e;
          debugPrint('[ASROrchestrator] ${plugin.pluginId} 流式识别失败: $e');

          // 检查是否需要临时禁用插件
          _handlePluginError(plugin, e);

          // 非降级错误直接抛出
          if (e is ASRException && !e.shouldFallback) {
            rethrow;
          }

          // 流式识别不支持跨插件降级：audioStream 是单订阅流，
          // 已被当前插件消费的数据无法重放给下一个插件。
          // 直接退出循环，抛出错误。
          debugPrint('[ASROrchestrator] 流式识别不支持降级（单订阅流已消费），停止尝试');
          break;
        }
      }

      // 如果没有成功且有错误，抛出最后一个错误
      if (!success && lastError != null) {
        throw lastError;
      }
    } catch (e) {
      debugPrint('[ASROrchestrator] 流式识别错误: $e');
      rethrow;
    } finally {
      _isRecognizing = false;
      _sessionManager.endSession(sessionId);
      debugPrint('[ASROrchestrator] transcribeStream 结束');
    }
  }

  /// 取消当前识别
  Future<void> cancelTranscription() async {
    debugPrint('[ASROrchestrator] cancelTranscription');

    _sessionManager.cancelSession();

    // 取消所有插件的识别
    final futures = <Future>[];
    for (final plugin in _registry.plugins) {
      futures.add(plugin.cancelTranscription().catchError((_) {}));
    }

    await Future.wait(futures);
    _isRecognizing = false;
  }

  /// 预热连接
  Future<void> warmupConnection() async {
    debugPrint('[ASROrchestrator] 预热ASR连接...');

    final plugins = await getAvailablePlugins(streaming: true);
    for (final plugin in plugins) {
      try {
        await plugin.warmupConnection();
        if (plugin.hasValidWarmup) {
          debugPrint('[ASROrchestrator] ${plugin.pluginId} 预热成功');
          break; // 只预热第一个可用的
        }
      } catch (e) {
        debugPrint('[ASROrchestrator] ${plugin.pluginId} 预热失败: $e');
      }
    }
  }

  /// 是否有预热的连接
  bool get hasWarmupConnection {
    for (final plugin in _registry.plugins) {
      if (plugin.hasValidWarmup) return true;
    }
    return false;
  }

  /// 设置热词
  void setHotWords(List<HotWord> hotWords) {
    for (final plugin in _registry.plugins) {
      plugin.setHotWords(hotWords);
    }
  }

  /// 添加热词
  void addHotWords(List<HotWord> hotWords) {
    for (final plugin in _registry.plugins) {
      plugin.addHotWords(hotWords);
    }
  }

  /// 临时禁用插件
  void disablePlugin(String pluginId, {Duration? duration}) {
    _disabledPlugins.add(pluginId);
    if (duration != null) {
      _disabledUntil[pluginId] = DateTime.now().add(duration);
    } else {
      // 默认禁用60秒
      _disabledUntil[pluginId] = DateTime.now().add(const Duration(seconds: 60));
    }
    debugPrint('[ASROrchestrator] 禁用插件: $pluginId');
  }

  /// 启用插件
  void enablePlugin(String pluginId) {
    _disabledPlugins.remove(pluginId);
    _disabledUntil.remove(pluginId);
    debugPrint('[ASROrchestrator] 启用插件: $pluginId');
  }

  /// 处理插件错误
  void _handlePluginError(ASRPluginInterface plugin, Object error) {
    if (error is ASRException) {
      switch (error.errorCode) {
        case ASRErrorCode.rateLimited:
          // 限流时临时禁用
          disablePlugin(plugin.pluginId, duration: const Duration(minutes: 1));
          break;
        case ASRErrorCode.unauthorized:
        case ASRErrorCode.tokenFailed:
          // 认证失败时临时禁用
          disablePlugin(plugin.pluginId, duration: const Duration(minutes: 5));
          break;
        default:
          break;
      }
    }
  }

  /// 后处理结果
  ASRResult _postProcess(ASRResult result) {
    if (_postprocessor == null) return result;
    return _postprocessor.process(result);
  }

  /// 后处理部分结果
  ASRPartialResult _postProcessPartial(ASRPartialResult result) {
    if (_postprocessor == null) return result;
    return _postprocessor.processPartial(result);
  }

  /// 初始化所有插件
  Future<void> initialize({ASRPluginConfig? config}) async {
    await _registry.initializeAll(config: config);
  }

  /// 释放资源
  Future<void> dispose() async {
    await cancelTranscription();
    _sessionManager.dispose();
    _disabledPlugins.clear();
    _disabledUntil.clear();
  }
}
