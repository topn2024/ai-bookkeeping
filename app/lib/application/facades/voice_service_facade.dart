/// Voice Service Facade
///
/// 统一的语音服务入口，根据 Feature Flag 路由到新旧实现。
/// 使用 Facade 模式封装实现细节，对外提供稳定的 API。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/feature_flags.dart';
import '../../services/voice_service_coordinator.dart' as legacy;
import '../coordinators/voice_service_orchestrator.dart' as modern;

/// 语音服务 Facade
///
/// 统一入口，根据 Feature Flag 决定使用新旧实现：
/// - 新实现：VoiceServiceOrchestrator（协调器模式）
/// - 旧实现：VoiceServiceCoordinator（原始实现）
class VoiceServiceFacade extends ChangeNotifier {
  /// 新实现（协调器模式）
  final modern.VoiceServiceOrchestrator? _modernImpl;

  /// 旧实现（原始）
  final legacy.VoiceServiceCoordinator? _legacyImpl;

  /// Feature Flags
  final FeatureFlags _featureFlags;

  VoiceServiceFacade({
    modern.VoiceServiceOrchestrator? modernImpl,
    legacy.VoiceServiceCoordinator? legacyImpl,
    FeatureFlags? featureFlags,
  })  : _modernImpl = modernImpl,
        _legacyImpl = legacyImpl,
        _featureFlags = featureFlags ?? FeatureFlags.instance {
    // 监听实现的变化
    _modernImpl?.addListener(_onImplChanged);
    _legacyImpl?.addListener(_onImplChanged);
  }

  /// 是否使用新实现
  bool get _useModern => _featureFlags.useNewVoiceArchitecture && _modernImpl != null;

  /// 当前会话状态
  VoiceSessionState get sessionState {
    if (_useModern) {
      return _mapModernState(_modernImpl!.sessionState);
    } else if (_legacyImpl != null) {
      return _mapLegacyState(_legacyImpl!.sessionState);
    }
    return VoiceSessionState.idle;
  }

  /// 是否有活跃会话
  bool get hasActiveSession {
    if (_useModern) {
      return _modernImpl!.hasActiveSession;
    } else if (_legacyImpl != null) {
      return _legacyImpl!.hasActiveSession;
    }
    return false;
  }

  // ==================== 核心方法 ====================

  /// 处理语音命令
  Future<VoiceSessionResult> processVoiceCommand(String voiceInput) async {
    debugPrint('[VoiceServiceFacade] 处理语音命令，使用${_useModern ? "新" : "旧"}实现');

    if (_useModern) {
      final result = await _modernImpl!.processVoiceCommand(voiceInput);
      return _mapModernResult(result);
    } else if (_legacyImpl != null) {
      final result = await _legacyImpl!.processVoiceCommand(voiceInput);
      return _mapLegacyResult(result);
    }

    return VoiceSessionResult.error('语音服务未初始化');
  }

  /// 处理音频流
  Stream<VoiceSessionResult> processAudioStream(Stream<Uint8List> audioStream) {
    debugPrint('[VoiceServiceFacade] 处理音频流，使用${_useModern ? "新" : "旧"}实现');

    if (_useModern) {
      return _modernImpl!.processAudioStream(audioStream).map(_mapModernResult);
    } else if (_legacyImpl != null) {
      return _legacyImpl!.processAudioStream(audioStream).map(_mapLegacyResult);
    }

    return Stream.value(VoiceSessionResult.error('语音服务未初始化'));
  }

  /// 启动语音会话
  Future<VoiceSessionResult> startVoiceSession() async {
    debugPrint('[VoiceServiceFacade] 启动语音会话，使用${_useModern ? "新" : "旧"}实现');

    if (_useModern) {
      final result = await _modernImpl!.startVoiceSession();
      return _mapModernResult(result);
    } else if (_legacyImpl != null) {
      final result = await _legacyImpl!.startVoiceSession();
      return _mapLegacyResult(result);
    }

    return VoiceSessionResult.error('语音服务未初始化');
  }

  /// 结束语音会话
  Future<void> endVoiceSession() async {
    debugPrint('[VoiceServiceFacade] 结束语音会话');

    if (_useModern) {
      await _modernImpl!.endVoiceSession();
    } else if (_legacyImpl != null) {
      await _legacyImpl!.endVoiceSession();
    }
  }

  // ==================== 切换实现 ====================

  /// 切换到新实现
  void switchToModernImpl() {
    if (_modernImpl == null) {
      debugPrint('[VoiceServiceFacade] 新实现未初始化，无法切换');
      return;
    }
    _featureFlags.enableNewVoiceArchitecture();
    notifyListeners();
  }

  /// 切换到旧实现
  void switchToLegacyImpl() {
    _featureFlags.disableNewVoiceArchitecture();
    notifyListeners();
  }

  /// 当前使用的实现名称
  String get currentImplementation => _useModern ? 'modern' : 'legacy';

  // ==================== 映射方法 ====================

  /// 映射新实现的状态
  VoiceSessionState _mapModernState(modern.VoiceSessionState state) {
    switch (state) {
      case modern.VoiceSessionState.idle:
        return VoiceSessionState.idle;
      case modern.VoiceSessionState.listening:
        return VoiceSessionState.listening;
      case modern.VoiceSessionState.processing:
        return VoiceSessionState.processing;
      case modern.VoiceSessionState.waitingForConfirmation:
        return VoiceSessionState.waitingForConfirmation;
      case modern.VoiceSessionState.waitingForClarification:
        return VoiceSessionState.waitingForClarification;
      case modern.VoiceSessionState.waitingForMultiIntentConfirmation:
        return VoiceSessionState.waitingForMultiIntentConfirmation;
      case modern.VoiceSessionState.waitingForAmountSupplement:
        return VoiceSessionState.waitingForAmountSupplement;
      case modern.VoiceSessionState.automationRunning:
        return VoiceSessionState.automationRunning;
      case modern.VoiceSessionState.error:
        return VoiceSessionState.error;
      case modern.VoiceSessionState.recovering:
        return VoiceSessionState.recovering;
    }
  }

  /// 映射旧实现的状态
  VoiceSessionState _mapLegacyState(legacy.VoiceSessionState state) {
    switch (state) {
      case legacy.VoiceSessionState.idle:
        return VoiceSessionState.idle;
      case legacy.VoiceSessionState.listening:
        return VoiceSessionState.listening;
      case legacy.VoiceSessionState.processing:
        return VoiceSessionState.processing;
      case legacy.VoiceSessionState.waitingForConfirmation:
        return VoiceSessionState.waitingForConfirmation;
      case legacy.VoiceSessionState.waitingForClarification:
        return VoiceSessionState.waitingForClarification;
      case legacy.VoiceSessionState.waitingForMultiIntentConfirmation:
        return VoiceSessionState.waitingForMultiIntentConfirmation;
      case legacy.VoiceSessionState.waitingForAmountSupplement:
        return VoiceSessionState.waitingForAmountSupplement;
      case legacy.VoiceSessionState.automationRunning:
        return VoiceSessionState.automationRunning;
      case legacy.VoiceSessionState.error:
        return VoiceSessionState.error;
      case legacy.VoiceSessionState.recovering:
        return VoiceSessionState.recovering;
    }
  }

  /// 映射新实现的结果
  VoiceSessionResult _mapModernResult(modern.VoiceSessionResult result) {
    return VoiceSessionResult(
      status: _mapModernStatus(result.status),
      message: result.message,
      errorMessage: result.errorMessage,
      data: result.data,
    );
  }

  /// 映射旧实现的结果
  VoiceSessionResult _mapLegacyResult(legacy.VoiceSessionResult result) {
    return VoiceSessionResult(
      status: _mapLegacyStatus(result.status),
      message: result.message,
      errorMessage: result.errorMessage,
      data: result.data,
    );
  }

  /// 映射新实现的状态类型
  VoiceSessionStatus _mapModernStatus(modern.VoiceSessionStatus status) {
    switch (status) {
      case modern.VoiceSessionStatus.success:
        return VoiceSessionStatus.success;
      case modern.VoiceSessionStatus.error:
        return VoiceSessionStatus.error;
      case modern.VoiceSessionStatus.partial:
        return VoiceSessionStatus.partial;
      case modern.VoiceSessionStatus.waitingForConfirmation:
        return VoiceSessionStatus.waitingForConfirmation;
      case modern.VoiceSessionStatus.waitingForClarification:
        return VoiceSessionStatus.waitingForClarification;
    }
  }

  /// 映射旧实现的状态类型
  VoiceSessionStatus _mapLegacyStatus(legacy.VoiceSessionStatus status) {
    switch (status) {
      case legacy.VoiceSessionStatus.success:
        return VoiceSessionStatus.success;
      case legacy.VoiceSessionStatus.error:
        return VoiceSessionStatus.error;
      case legacy.VoiceSessionStatus.partial:
        return VoiceSessionStatus.partial;
      case legacy.VoiceSessionStatus.waitingForConfirmation:
        return VoiceSessionStatus.waitingForConfirmation;
      case legacy.VoiceSessionStatus.waitingForClarification:
        return VoiceSessionStatus.waitingForClarification;
    }
  }

  void _onImplChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _modernImpl?.removeListener(_onImplChanged);
    _legacyImpl?.removeListener(_onImplChanged);
    super.dispose();
  }
}

// ==================== Facade 统一类型 ====================

/// 语音会话状态（Facade 层）
enum VoiceSessionState {
  idle,
  listening,
  processing,
  waitingForConfirmation,
  waitingForClarification,
  waitingForMultiIntentConfirmation,
  waitingForAmountSupplement,
  automationRunning,
  error,
  recovering,
}

/// 语音会话状态类型（Facade 层）
enum VoiceSessionStatus {
  success,
  error,
  partial,
  waitingForConfirmation,
  waitingForClarification,
}

/// 语音会话结果（Facade 层）
class VoiceSessionResult {
  final VoiceSessionStatus status;
  final String? message;
  final String? errorMessage;
  final dynamic data;

  const VoiceSessionResult({
    required this.status,
    this.message,
    this.errorMessage,
    this.data,
  });

  factory VoiceSessionResult.success(String message, [dynamic data]) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.success,
      message: message,
      data: data,
    );
  }

  factory VoiceSessionResult.error(String errorMessage) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.error,
      errorMessage: errorMessage,
    );
  }

  factory VoiceSessionResult.partial(String message) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.partial,
      message: message,
    );
  }

  bool get isSuccess => status == VoiceSessionStatus.success;
  bool get isError => status == VoiceSessionStatus.error;
}
