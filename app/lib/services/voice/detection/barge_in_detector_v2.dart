import 'package:flutter/foundation.dart';

import '../config/pipeline_config.dart';

/// 打断检测层级
///
/// 简化版：仅使用 VAD 进行打断检测
/// 回声消除由硬件级 AEC 在音频层处理，不再在文本层做相似度过滤
enum BargeInLayer {
  /// VAD 检测到语音（主要依据）
  vadBased,

  /// 完整句子确认
  finalResult,
}

/// 打断检测结果
class BargeInResult {
  /// 是否触发打断
  final bool triggered;

  /// 触发的层级
  final BargeInLayer? layer;

  /// 触发文本
  final String? text;

  /// 原因描述
  final String? reason;

  const BargeInResult({
    required this.triggered,
    this.layer,
    this.text,
    this.reason,
  });

  static const notTriggered = BargeInResult(triggered: false);

  @override
  String toString() {
    if (!triggered) return 'BargeInResult(not triggered)';
    return 'BargeInResult(triggered, layer=$layer, text="$text", reason=$reason)';
  }
}

/// 简化版打断检测器
///
/// 设计原则：
/// - 回声消除由硬件级 AEC 在音频层处理
/// - 打断检测仅基于 VAD 语音活动检测
/// - 简单直接，减少复杂条件判断
///
/// 检测逻辑：
/// - VAD 检测到语音 + 持续一定时间 → 触发打断
/// - 有 ASR 文本内容作为辅助确认
class BargeInDetectorV2 {
  final PipelineConfig _config;

  /// TTS状态
  bool _isTTSPlaying = false;
  String _currentTTSText = '';

  /// VAD状态
  bool _vadSpeechDetected = false;
  DateTime? _vadSpeechStartTime;

  /// 最小语音持续时间（毫秒），防止噪音误触发
  static const int _minSpeechDurationMs = 200;

  /// 冷却控制
  DateTime? _lastBargeInTime;

  /// 统计信息
  int _vadTriggers = 0;
  int _finalTriggers = 0;
  int _totalChecks = 0;

  /// 回调
  void Function(BargeInResult result)? onBargeIn;

  BargeInDetectorV2({
    PipelineConfig? config,
  }) : _config = config ?? PipelineConfig.defaultConfig;

  /// 是否启用（TTS正在播放）
  bool get isEnabled => _isTTSPlaying;

  /// VAD是否检测到语音
  bool get vadSpeechDetected => _vadSpeechDetected;

  /// 当前TTS文本
  String get currentTTSText => _currentTTSText;

  /// 统计信息
  Map<String, int> get stats => {
        'totalChecks': _totalChecks,
        'vadTriggers': _vadTriggers,
        'finalTriggers': _finalTriggers,
      };

  /// 更新TTS状态
  void updateTTSState({
    required bool isPlaying,
    required String currentText,
  }) {
    _isTTSPlaying = isPlaying;
    _currentTTSText = currentText;
    debugPrint('[BargeInDetectorV2] TTS状态更新: isPlaying=$isPlaying');
  }

  /// 追加TTS文本（流式TTS场景）
  void appendTTSText(String text) {
    _currentTTSText += text;
  }

  /// 更新VAD状态
  void updateVADState(bool isSpeechDetected) {
    final wasDetected = _vadSpeechDetected;
    _vadSpeechDetected = isSpeechDetected;

    // 记录语音开始时间（用于计算持续时间）
    if (isSpeechDetected && !wasDetected) {
      _vadSpeechStartTime = DateTime.now();
      debugPrint('[BargeInDetectorV2] VAD语音开始');
    } else if (!isSpeechDetected && wasDetected) {
      _vadSpeechStartTime = null;
      debugPrint('[BargeInDetectorV2] VAD语音结束');
    }
  }

  /// 处理ASR中间结果
  ///
  /// 简化版检测逻辑：
  /// - 硬件 AEC 已经在音频层消除回声
  /// - VAD 检测到语音 + 持续足够时间 → 触发打断
  /// - ASR 有内容作为辅助确认
  BargeInResult handlePartialResult(String text) {
    if (!_isTTSPlaying) return BargeInResult.notTriggered;
    if (!_canBargeIn()) return BargeInResult.notTriggered;

    _totalChecks++;
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return BargeInResult.notTriggered;

    // 检查 VAD 是否检测到语音且持续足够时间
    if (_vadSpeechDetected && _vadSpeechStartTime != null) {
      final speechDuration = DateTime.now().difference(_vadSpeechStartTime!);
      if (speechDuration.inMilliseconds >= _minSpeechDurationMs) {
        // VAD 检测到持续语音，且有 ASR 文本内容，触发打断
        if (cleanText.length >= 2) {  // 至少有2个字符
          _vadTriggers++;
          final result = BargeInResult(
            triggered: true,
            layer: BargeInLayer.vadBased,
            text: text,
            reason: 'VAD语音持续${speechDuration.inMilliseconds}ms',
          );
          _triggerBargeIn(result);
          return result;
        }
      }
    }

    return BargeInResult.notTriggered;
  }

  /// 处理ASR最终结果
  ///
  /// 最终结果确认打断
  BargeInResult handleFinalResult(String text) {
    if (!_isTTSPlaying) return BargeInResult.notTriggered;
    if (!_canBargeIn()) return BargeInResult.notTriggered;

    _totalChecks++;
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return BargeInResult.notTriggered;

    // 有最终ASR结果，且有实际内容，触发打断
    if (cleanText.length >= 2) {
      _finalTriggers++;
      final result = BargeInResult(
        triggered: true,
        layer: BargeInLayer.finalResult,
        text: text,
        reason: 'ASR最终结果确认',
      );
      _triggerBargeIn(result);
      return result;
    }

    return BargeInResult.notTriggered;
  }

  /// 是否可以触发打断（冷却时间检查）
  bool _canBargeIn() {
    if (_lastBargeInTime == null) return true;
    final elapsed = DateTime.now().difference(_lastBargeInTime!);
    return elapsed.inMilliseconds > _config.bargeInCooldownMs;
  }

  /// 触发打断
  void _triggerBargeIn(BargeInResult result) {
    _lastBargeInTime = DateTime.now();
    debugPrint('[BargeInDetectorV2] 触发打断: $result');
    onBargeIn?.call(result);
  }

  /// 清理文本
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp('[。，！？；、：""''（）【】《》,.!?;:\\s]'), '')
        .toLowerCase();
  }

  /// 重置检测器
  void reset() {
    _isTTSPlaying = false;
    _currentTTSText = '';
    _vadSpeechDetected = false;
    _vadSpeechStartTime = null;
    _lastBargeInTime = null;
    debugPrint('[BargeInDetectorV2] 重置');
  }

  /// 重置统计信息
  void resetStats() {
    _vadTriggers = 0;
    _finalTriggers = 0;
    _totalChecks = 0;
  }
}
