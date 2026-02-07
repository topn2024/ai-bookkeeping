import 'dart:async';

import 'package:flutter/foundation.dart';

/// 会话管理器
///
/// 管理ASR识别会话，防止并发冲突
class SessionManager {
  /// 当前会话ID
  int _currentSessionId = 0;

  /// 当前是否有活动会话
  bool _hasActiveSession = false;

  /// 会话取消标志
  bool _isCancelled = false;

  /// 会话超时定时器
  Timer? _timeoutTimer;

  /// 会话启动时间
  DateTime? _sessionStartTime;

  /// 当前会话ID
  int get currentSessionId => _currentSessionId;

  /// 是否有活动会话
  bool get hasActiveSession => _hasActiveSession;

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 会话已运行时间
  Duration? get sessionDuration {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// 开始新会话
  ///
  /// 如果有旧会话会自动取消
  /// 返回新会话ID
  int startSession({Duration? timeout}) {
    // 取消旧会话
    if (_hasActiveSession) {
      debugPrint('[SessionManager] 取消旧会话 #$_currentSessionId');
      _cancelCurrentSession();
    }

    // 创建新会话
    _currentSessionId++;
    _hasActiveSession = true;
    _isCancelled = false;
    _sessionStartTime = DateTime.now();

    debugPrint('[SessionManager] 启动新会话 #$_currentSessionId');

    // 设置超时
    if (timeout != null) {
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(timeout, () {
        debugPrint('[SessionManager] 会话 #$_currentSessionId 超时');
        _cancelCurrentSession();
      });
    }

    return _currentSessionId;
  }

  /// 结束当前会话
  void endSession(int sessionId) {
    if (sessionId != _currentSessionId) {
      debugPrint('[SessionManager] 忽略过期会话 #$sessionId 的结束请求');
      return;
    }

    debugPrint('[SessionManager] 结束会话 #$sessionId');
    _cleanup();
  }

  /// 取消当前会话
  void cancelSession() {
    if (!_hasActiveSession) return;

    debugPrint('[SessionManager] 取消会话 #$_currentSessionId');
    _cancelCurrentSession();
  }

  /// 检查会话是否仍然有效
  bool isSessionValid(int sessionId) {
    return sessionId == _currentSessionId && _hasActiveSession && !_isCancelled;
  }

  /// 检查会话是否过期
  bool isSessionExpired(int sessionId) {
    return sessionId != _currentSessionId;
  }

  void _cancelCurrentSession() {
    _isCancelled = true;
    _cleanup();
  }

  void _cleanup() {
    _hasActiveSession = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _sessionStartTime = null;
  }

  /// 释放资源
  void dispose() {
    _cleanup();
  }
}

/// 带锁的会话管理器
///
/// 提供互斥访问保证
class LockingSessionManager extends SessionManager {
  Completer<void>? _lockCompleter;

  /// 获取会话锁
  ///
  /// 如果已有会话在运行，等待其完成
  Future<int> acquireSession({
    Duration? timeout,
    Duration? waitTimeout,
  }) async {
    // 等待旧会话完成
    if (_lockCompleter != null && !_lockCompleter!.isCompleted) {
      debugPrint('[LockingSessionManager] 等待旧会话完成...');
      try {
        if (waitTimeout != null) {
          await _lockCompleter!.future.timeout(waitTimeout);
        } else {
          await _lockCompleter!.future;
        }
      } on TimeoutException {
        debugPrint('[LockingSessionManager] 等待超时，强制获取锁');
      }
    }

    _lockCompleter = Completer<void>();
    return startSession(timeout: timeout);
  }

  /// 释放会话锁
  void releaseSession(int sessionId) {
    endSession(sessionId);
    _lockCompleter?.complete();
    _lockCompleter = null;
  }

  @override
  void cancelSession() {
    super.cancelSession();
    _lockCompleter?.complete();
    _lockCompleter = null;
  }

  @override
  void dispose() {
    _lockCompleter?.complete();
    _lockCompleter = null;
    super.dispose();
  }
}
