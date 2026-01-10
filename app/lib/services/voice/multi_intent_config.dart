import 'package:shared_preferences/shared_preferences.dart';

/// 多意图处理配置服务
///
/// 管理语音多意图处理的配置选项，包括：
/// - 多意图处理开关
/// - AI辅助开关
/// - 追问模式配置
class MultiIntentConfig {
  static const String _keyMultiIntentEnabled = 'multi_intent_enabled';
  static const String _keyAiAssistEnabled = 'multi_intent_ai_assist_enabled';
  static const String _keyFollowUpMode = 'multi_intent_follow_up_mode';
  static const String _keyAutoConfirmSingleIntent = 'multi_intent_auto_confirm_single';
  static const String _keyShowFilteredNoise = 'multi_intent_show_filtered_noise';
  static const String _keyMinConfidenceThreshold = 'multi_intent_min_confidence';

  SharedPreferences? _prefs;

  /// 单例实例
  static final MultiIntentConfig _instance = MultiIntentConfig._internal();

  factory MultiIntentConfig() => _instance;

  MultiIntentConfig._internal();

  /// 初始化配置服务
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 确保已初始化
  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // ==================== 多意图处理开关 ====================

  /// 是否启用多意图处理
  ///
  /// 启用后，语音助手会自动识别并处理包含多个意图的复杂语句
  /// 默认：启用
  Future<bool> get multiIntentEnabled async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_keyMultiIntentEnabled) ?? true;
  }

  /// 设置是否启用多意图处理
  Future<void> setMultiIntentEnabled(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyMultiIntentEnabled, enabled);
  }

  // ==================== AI辅助开关 ====================

  /// 是否启用AI辅助分解
  ///
  /// 启用后，对于复杂语句会使用AI（Qwen）进行意图分解
  /// 关闭后，仅使用规则分句器
  /// 默认：启用
  Future<bool> get aiAssistEnabled async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_keyAiAssistEnabled) ?? true;
  }

  /// 设置是否启用AI辅助分解
  Future<void> setAiAssistEnabled(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAiAssistEnabled, enabled);
  }

  // ==================== 追问模式配置 ====================

  /// 获取追问模式
  ///
  /// - batch: 批量模式，一次性显示所有需要补充的意图
  /// - sequential: 逐个模式，一个一个询问
  /// 默认：批量模式
  Future<FollowUpMode> get followUpMode async {
    final prefs = await _ensurePrefs();
    final modeStr = prefs.getString(_keyFollowUpMode);
    return FollowUpMode.fromString(modeStr);
  }

  /// 设置追问模式
  Future<void> setFollowUpMode(FollowUpMode mode) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_keyFollowUpMode, mode.value);
  }

  // ==================== 其他配置 ====================

  /// 单个完整意图是否自动确认
  ///
  /// 启用后，如果只识别到一个完整意图，会自动执行而不需要确认
  /// 默认：启用
  Future<bool> get autoConfirmSingleIntent async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_keyAutoConfirmSingleIntent) ?? true;
  }

  /// 设置单个完整意图是否自动确认
  Future<void> setAutoConfirmSingleIntent(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAutoConfirmSingleIntent, enabled);
  }

  /// 是否显示过滤的噪音内容
  ///
  /// 启用后，在确认界面会显示被过滤的无关内容（可折叠）
  /// 默认：关闭
  Future<bool> get showFilteredNoise async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_keyShowFilteredNoise) ?? false;
  }

  /// 设置是否显示过滤的噪音内容
  Future<void> setShowFilteredNoise(bool show) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyShowFilteredNoise, show);
  }

  /// 最小置信度阈值
  ///
  /// 低于此阈值的意图会被过滤掉
  /// 范围：0.0 - 1.0
  /// 默认：0.3
  Future<double> get minConfidenceThreshold async {
    final prefs = await _ensurePrefs();
    return prefs.getDouble(_keyMinConfidenceThreshold) ?? 0.3;
  }

  /// 设置最小置信度阈值
  Future<void> setMinConfidenceThreshold(double threshold) async {
    final prefs = await _ensurePrefs();
    await prefs.setDouble(_keyMinConfidenceThreshold, threshold.clamp(0.0, 1.0));
  }

  // ==================== 批量操作 ====================

  /// 获取所有配置
  Future<MultiIntentConfigData> getAll() async {
    return MultiIntentConfigData(
      multiIntentEnabled: await multiIntentEnabled,
      aiAssistEnabled: await aiAssistEnabled,
      followUpMode: await followUpMode,
      autoConfirmSingleIntent: await autoConfirmSingleIntent,
      showFilteredNoise: await showFilteredNoise,
      minConfidenceThreshold: await minConfidenceThreshold,
    );
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_keyMultiIntentEnabled);
    await prefs.remove(_keyAiAssistEnabled);
    await prefs.remove(_keyFollowUpMode);
    await prefs.remove(_keyAutoConfirmSingleIntent);
    await prefs.remove(_keyShowFilteredNoise);
    await prefs.remove(_keyMinConfidenceThreshold);
  }
}

/// 追问模式枚举
enum FollowUpMode {
  /// 批量模式 - 一次性显示所有需要补充的意图
  batch('batch', '批量模式'),

  /// 逐个模式 - 一个一个询问
  sequential('sequential', '逐个模式');

  final String value;
  final String displayName;

  const FollowUpMode(this.value, this.displayName);

  /// 从字符串解析
  static FollowUpMode fromString(String? value) {
    switch (value) {
      case 'sequential':
        return FollowUpMode.sequential;
      case 'batch':
      default:
        return FollowUpMode.batch;
    }
  }
}

/// 多意图配置数据类
class MultiIntentConfigData {
  /// 是否启用多意图处理
  final bool multiIntentEnabled;

  /// 是否启用AI辅助分解
  final bool aiAssistEnabled;

  /// 追问模式
  final FollowUpMode followUpMode;

  /// 单个完整意图是否自动确认
  final bool autoConfirmSingleIntent;

  /// 是否显示过滤的噪音内容
  final bool showFilteredNoise;

  /// 最小置信度阈值
  final double minConfidenceThreshold;

  const MultiIntentConfigData({
    required this.multiIntentEnabled,
    required this.aiAssistEnabled,
    required this.followUpMode,
    required this.autoConfirmSingleIntent,
    required this.showFilteredNoise,
    required this.minConfidenceThreshold,
  });

  /// 默认配置
  static const defaultConfig = MultiIntentConfigData(
    multiIntentEnabled: true,
    aiAssistEnabled: true,
    followUpMode: FollowUpMode.batch,
    autoConfirmSingleIntent: true,
    showFilteredNoise: false,
    minConfidenceThreshold: 0.3,
  );

  /// 复制并修改
  MultiIntentConfigData copyWith({
    bool? multiIntentEnabled,
    bool? aiAssistEnabled,
    FollowUpMode? followUpMode,
    bool? autoConfirmSingleIntent,
    bool? showFilteredNoise,
    double? minConfidenceThreshold,
  }) {
    return MultiIntentConfigData(
      multiIntentEnabled: multiIntentEnabled ?? this.multiIntentEnabled,
      aiAssistEnabled: aiAssistEnabled ?? this.aiAssistEnabled,
      followUpMode: followUpMode ?? this.followUpMode,
      autoConfirmSingleIntent: autoConfirmSingleIntent ?? this.autoConfirmSingleIntent,
      showFilteredNoise: showFilteredNoise ?? this.showFilteredNoise,
      minConfidenceThreshold: minConfidenceThreshold ?? this.minConfidenceThreshold,
    );
  }

  @override
  String toString() {
    return 'MultiIntentConfigData('
        'multiIntentEnabled: $multiIntentEnabled, '
        'aiAssistEnabled: $aiAssistEnabled, '
        'followUpMode: ${followUpMode.value}, '
        'autoConfirmSingleIntent: $autoConfirmSingleIntent, '
        'showFilteredNoise: $showFilteredNoise, '
        'minConfidenceThreshold: $minConfidenceThreshold)';
  }
}
