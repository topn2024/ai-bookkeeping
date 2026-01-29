/// Feature Flags
///
/// 功能开关配置，用于控制新旧实现之间的切换。
/// 支持渐进式迁移和 A/B 测试。
library;

import 'package:flutter/foundation.dart';

/// 功能开关配置
class FeatureFlags {
  /// 单例实例
  static final FeatureFlags _instance = FeatureFlags._();
  static FeatureFlags get instance => _instance;

  FeatureFlags._();

  // ==================== 架构重构相关 ====================

  /// 是否使用新的语音架构（Coordinator Pattern）
  ///
  /// 启用后将使用拆分后的协调器：
  /// - VoiceRecognitionCoordinator
  /// - IntentProcessingCoordinator
  /// - TransactionOperationCoordinator
  /// - NavigationCoordinator
  /// - ConversationCoordinator
  /// - FeedbackCoordinator
  bool _useNewVoiceArchitecture = false;

  /// 是否使用 Repository Pattern
  ///
  /// 启用后将使用新的 Repository 实现替代 DatabaseService
  bool _useRepositoryPattern = false;

  /// 是否使用新的 GlobalVoiceAssistantManager 架构
  bool _useNewAssistantManager = false;

  // ==================== Getters ====================

  bool get useNewVoiceArchitecture => _useNewVoiceArchitecture;
  bool get useRepositoryPattern => _useRepositoryPattern;
  bool get useNewAssistantManager => _useNewAssistantManager;

  // ==================== Setters ====================

  /// 启用新语音架构
  void enableNewVoiceArchitecture() {
    _useNewVoiceArchitecture = true;
    debugPrint('[FeatureFlags] 启用新语音架构');
  }

  /// 禁用新语音架构（回退到旧实现）
  void disableNewVoiceArchitecture() {
    _useNewVoiceArchitecture = false;
    debugPrint('[FeatureFlags] 禁用新语音架构');
  }

  /// 启用 Repository Pattern
  void enableRepositoryPattern() {
    _useRepositoryPattern = true;
    debugPrint('[FeatureFlags] 启用 Repository Pattern');
  }

  /// 禁用 Repository Pattern
  void disableRepositoryPattern() {
    _useRepositoryPattern = false;
    debugPrint('[FeatureFlags] 禁用 Repository Pattern');
  }

  /// 启用新 Assistant Manager 架构
  void enableNewAssistantManager() {
    _useNewAssistantManager = true;
    debugPrint('[FeatureFlags] 启用新 Assistant Manager 架构');
  }

  /// 禁用新 Assistant Manager 架构
  void disableNewAssistantManager() {
    _useNewAssistantManager = false;
    debugPrint('[FeatureFlags] 禁用新 Assistant Manager 架构');
  }

  // ==================== 批量操作 ====================

  /// 启用所有新架构特性
  void enableAllNewFeatures() {
    _useNewVoiceArchitecture = true;
    _useRepositoryPattern = true;
    _useNewAssistantManager = true;
    debugPrint('[FeatureFlags] 启用所有新架构特性');
  }

  /// 禁用所有新架构特性（完全回退）
  void disableAllNewFeatures() {
    _useNewVoiceArchitecture = false;
    _useRepositoryPattern = false;
    _useNewAssistantManager = false;
    debugPrint('[FeatureFlags] 禁用所有新架构特性');
  }

  /// 重置为默认值
  void reset() {
    _useNewVoiceArchitecture = false;
    _useRepositoryPattern = false;
    _useNewAssistantManager = false;
    debugPrint('[FeatureFlags] 重置为默认值');
  }

  // ==================== 调试 ====================

  /// 获取当前状态描述
  Map<String, bool> get currentState => {
        'useNewVoiceArchitecture': _useNewVoiceArchitecture,
        'useRepositoryPattern': _useRepositoryPattern,
        'useNewAssistantManager': _useNewAssistantManager,
      };

  @override
  String toString() {
    return 'FeatureFlags('
        'newVoiceArch: $_useNewVoiceArchitecture, '
        'repoPattern: $_useRepositoryPattern, '
        'newAssistant: $_useNewAssistantManager)';
  }
}

/// 便捷访问
FeatureFlags get featureFlags => FeatureFlags.instance;
