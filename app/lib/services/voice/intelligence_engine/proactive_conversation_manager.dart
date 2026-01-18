import 'dart:async';
import 'package:flutter/foundation.dart';

/// 主动对话管理器
///
/// 职责：
/// - 30秒无输入计时器
/// - 最多3次主动发起限制
/// - LLM生成话题（基于用户画像）
/// - 用户拒绝检测和退出机制
class ProactiveConversationManager {
  final ProactiveTopicGenerator topicGenerator;
  final ProactiveMessageCallback onProactiveMessage;

  // 计时器
  Timer? _silenceTimer;

  // 状态
  ProactiveState _state = ProactiveState.idle;

  // 计数器
  int _proactiveCount = 0;

  // 配置
  static const int _silenceTimeoutMs = 30000; // 30秒
  static const int _maxProactiveCount = 3;

  // 是否已禁用
  bool _proactiveDisabled = false;

  ProactiveConversationManager({
    required this.topicGenerator,
    required this.onProactiveMessage,
  });

  /// 启动静默监听
  void startSilenceMonitoring() {
    if (_proactiveDisabled) {
      debugPrint('[ProactiveConversationManager] 主动对话已禁用');
      return;
    }

    if (_proactiveCount >= _maxProactiveCount) {
      debugPrint('[ProactiveConversationManager] 已达到最大主动次数限制');
      return;
    }

    debugPrint('[ProactiveConversationManager] 启动静默监听: ${_silenceTimeoutMs}ms');
    _state = ProactiveState.waiting;

    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(milliseconds: _silenceTimeoutMs),
      () async {
        debugPrint('[ProactiveConversationManager] 静默超时，触发主动对话');
        await _triggerProactiveMessage();
      },
    );
  }

  /// 重置计时器（用户有输入时调用）
  void resetTimer() {
    debugPrint('[ProactiveConversationManager] 重置计时器');
    _silenceTimer?.cancel();
    _state = ProactiveState.idle;

    // 用户响应后重置计数器
    if (_proactiveCount > 0) {
      debugPrint('[ProactiveConversationManager] 用户响应，重置计数器');
      _proactiveCount = 0;
    }

    // 重新启动监听
    startSilenceMonitoring();
  }

  /// 停止监听
  void stopMonitoring() {
    debugPrint('[ProactiveConversationManager] 停止监听');
    _silenceTimer?.cancel();
    _state = ProactiveState.idle;
  }

  /// 触发主动对话
  Future<void> _triggerProactiveMessage() async {
    if (_proactiveCount >= _maxProactiveCount) {
      debugPrint('[ProactiveConversationManager] 已达到最大主动次数');
      return;
    }

    _state = ProactiveState.generating;
    _proactiveCount++;

    debugPrint('[ProactiveConversationManager] 生成主动话题 ($proactiveCount/$_maxProactiveCount)');

    try {
      // 生成话题
      final topic = await topicGenerator.generateTopic();

      if (topic != null) {
        _state = ProactiveState.speaking;
        debugPrint('[ProactiveConversationManager] 主动话题: $topic');

        // 回调通知
        onProactiveMessage(topic);
      }
    } catch (e) {
      debugPrint('[ProactiveConversationManager] 生成话题失败: $e');
    }

    _state = ProactiveState.idle;

    // 继续监听（如果未达到限制）
    if (_proactiveCount < _maxProactiveCount) {
      startSilenceMonitoring();
    }
  }

  /// 检测用户拒绝
  bool detectRejection(String input) {
    const rejectionKeywords = [
      '不用了', '别说了', '安静', '闭嘴', '不要',
      '停止', '别烦我', '不需要',
    ];

    final hasRejection = rejectionKeywords.any((keyword) => input.contains(keyword));

    if (hasRejection) {
      debugPrint('[ProactiveConversationManager] 检测到用户拒绝');
      _proactiveDisabled = true;
      stopMonitoring();
    }

    return hasRejection;
  }

  /// 重新启用主动对话
  void enable() {
    debugPrint('[ProactiveConversationManager] 重新启用主动对话');
    _proactiveDisabled = false;
    _proactiveCount = 0;
    startSilenceMonitoring();
  }

  /// 禁用主动对话
  void disable() {
    debugPrint('[ProactiveConversationManager] 禁用主动对话');
    _proactiveDisabled = true;
    stopMonitoring();
  }

  /// 获取当前状态
  ProactiveState get state => _state;

  /// 获取主动次数
  int get proactiveCount => _proactiveCount;

  /// 是否已禁用
  bool get isDisabled => _proactiveDisabled;

  /// 清理资源
  void dispose() {
    _silenceTimer?.cancel();
  }
}

/// 主动对话状态
enum ProactiveState {
  idle,       // 空闲
  waiting,    // 等待中
  generating, // 生成话题中
  speaking,   // 播放中
  stopped,    // 已停止
}

/// 主动话题生成器接口
abstract class ProactiveTopicGenerator {
  /// 生成话题
  Future<String?> generateTopic();
}

/// 主动消息回调
typedef ProactiveMessageCallback = void Function(String message);
