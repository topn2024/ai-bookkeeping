import 'package:flutter/foundation.dart';

/// 响应ID追踪器
///
/// 用于防止竞态条件（参考chat-companion-app优化）：
/// - 用户打断后，旧响应的TTS不应继续播放
/// - 新响应开始后，旧响应的完成事件不应影响状态
/// - 等待客户端确认播放完成才结束is_speaking状态
///
/// 使用场景：
/// 1. 用户说"今天花了多少"，系统开始响应（ID=1）
/// 2. 用户打断说"不对，是昨天"，系统开始新响应（ID=2）
/// 3. ID=1的TTS任务检查发现ID已过期，停止执行
/// 4. ID=1的playback_complete事件被忽略（因为ID不匹配）
class ResponseTracker {
  int _currentId = 0;
  DateTime? _lastResponseTime;

  /// 当前响应是否正在播放
  bool _isPlaying = false;

  /// 当前响应是否被打断
  bool _wasInterrupted = false;

  /// 当前响应ID
  int get currentId => _currentId;

  /// 最后响应时间
  DateTime? get lastResponseTime => _lastResponseTime;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 是否被打断
  bool get wasInterrupted => _wasInterrupted;

  /// 是否有活跃响应
  bool get hasActiveResponse => _currentId > 0;

  /// 开始新响应
  ///
  /// 返回新的响应ID，同时使所有旧响应ID失效
  int startNewResponse() {
    _currentId++;
    _lastResponseTime = DateTime.now();
    _isPlaying = false;
    _wasInterrupted = false;
    debugPrint('[ResponseTracker] 新响应开始: ID=$_currentId');
    return _currentId;
  }

  /// 标记开始播放
  void markPlaybackStarted(int id) {
    if (id == _currentId) {
      _isPlaying = true;
      debugPrint('[ResponseTracker] 开始播放: ID=$id');
    } else {
      debugPrint('[ResponseTracker] 忽略过期的播放开始: ID=$id (当前=$_currentId)');
    }
  }

  /// 确认播放完成（参考chat-companion-app的playback_complete机制）
  ///
  /// 返回是否接受此完成事件（ID匹配且未被打断）
  bool confirmPlaybackComplete(int id) {
    // 检查响应ID是否匹配当前响应
    if (id != _currentId) {
      debugPrint('[ResponseTracker] 忽略过期的播放完成: ID=$id (当前=$_currentId)');
      return false;
    }

    // 如果已经被打断（is_playing=false），忽略这个消息
    if (!_isPlaying) {
      debugPrint('[ResponseTracker] 忽略打断后的播放完成: ID=$id');
      return false;
    }

    _isPlaying = false;
    debugPrint('[ResponseTracker] 确认播放完成: ID=$id');
    return true;
  }

  /// 标记被打断
  void markInterrupted(int id) {
    if (id == _currentId) {
      _wasInterrupted = true;
      _isPlaying = false;
      debugPrint('[ResponseTracker] 标记打断: ID=$id');
    }
  }

  /// 检查是否为当前响应
  ///
  /// 用于TTS队列等组件检查任务是否应该继续执行
  bool isCurrentResponse(int id) {
    return id == _currentId;
  }

  /// 检查响应ID是否有效（未过期）
  ///
  /// 与isCurrentResponse相同，但语义更清晰
  bool isValidResponse(int id) {
    return id == _currentId;
  }

  /// 取消当前响应
  ///
  /// 使当前ID失效，但不分配新ID
  /// 用于用户主动取消或系统错误时
  void cancelCurrentResponse() {
    if (_currentId > 0) {
      debugPrint('[ResponseTracker] 取消响应: ID=$_currentId');
      _currentId++; // 递增使当前ID失效
    }
  }

  /// 完成当前响应
  ///
  /// 标记响应完成，记录完成时间
  void completeCurrentResponse(int id) {
    if (id == _currentId) {
      debugPrint('[ResponseTracker] 响应完成: ID=$id');
    } else {
      debugPrint('[ResponseTracker] 忽略过期响应完成事件: ID=$id (当前=$_currentId)');
    }
  }

  /// 重置追踪器
  ///
  /// 用于会话结束时清理状态
  void reset() {
    _currentId = 0;
    _lastResponseTime = null;
    debugPrint('[ResponseTracker] 重置');
  }

  /// 获取响应存活时间
  ///
  /// 返回当前响应从开始到现在的时间
  Duration? getResponseDuration() {
    if (_lastResponseTime == null) return null;
    return DateTime.now().difference(_lastResponseTime!);
  }
}
