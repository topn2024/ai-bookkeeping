import 'package:flutter/foundation.dart';

import '../config/pipeline_config.dart';
import 'echo_filter.dart';
import 'similarity_calculator.dart';

/// 打断检测层级
enum BargeInLayer {
  /// 第1层：VAD + ASR联合检测（最快，~200ms）
  layer1VadAsr,

  /// 第2层：纯ASR中间结果检测（~500ms）
  layer2Asr,

  /// 第3层：完整句子 + 回声过滤（~1000ms）
  layer3Final,
}

/// 打断检测结果
class BargeInResult {
  /// 是否触发打断
  final bool triggered;

  /// 触发的层级
  final BargeInLayer? layer;

  /// 触发文本
  final String? text;

  /// 与TTS文本的相似度
  final double? similarity;

  const BargeInResult({
    required this.triggered,
    this.layer,
    this.text,
    this.similarity,
  });

  static const notTriggered = BargeInResult(triggered: false);

  @override
  String toString() {
    if (!triggered) return 'BargeInResult(not triggered)';
    return 'BargeInResult(triggered, layer=$layer, text="$text", similarity=$similarity)';
  }
}

/// 三层打断检测器
///
/// 层级设计：
/// - 第1层：VAD + ASR中间结果（最快，~200ms）
///   - 条件：VAD检测到语音 + ASR中间结果≥4字 + 相似度<0.4
/// - 第2层：纯ASR中间结果（~500ms）
///   - 条件：ASR中间结果≥8字 + 相似度<0.3
/// - 第3层：完整句子 + 四层回声过滤（~1000ms）
///   - 条件：ASR最终结果 + 通过回声过滤
///
/// 使用场景：
/// 当用户在TTS播放期间说话，需要快速判断是否是有效打断
/// 而不是回声或噪音。
class BargeInDetectorV2 {
  final PipelineConfig _config;
  final SimilarityCalculator _similarity = SimilarityCalculator();
  final EchoFilter _echoFilter;

  /// TTS状态
  bool _isTTSPlaying = false;
  String _currentTTSText = '';

  /// VAD状态
  bool _vadSpeechDetected = false;

  /// 冷却控制
  DateTime? _lastBargeInTime;

  /// 节流控制
  DateTime? _lastCheckTime;

  /// 统计信息
  int _layer1Triggers = 0;
  int _layer2Triggers = 0;
  int _layer3Triggers = 0;
  int _totalChecks = 0;

  /// 回调
  void Function(BargeInResult result)? onBargeIn;

  BargeInDetectorV2({
    PipelineConfig? config,
    EchoFilter? echoFilter,
  })  : _config = config ?? PipelineConfig.defaultConfig,
        _echoFilter = echoFilter ?? EchoFilter(config: config);

  /// 是否启用（TTS正在播放）
  bool get isEnabled => _isTTSPlaying;

  /// VAD是否检测到语音
  bool get vadSpeechDetected => _vadSpeechDetected;

  /// 当前TTS文本
  String get currentTTSText => _currentTTSText;

  /// 统计信息
  Map<String, int> get stats => {
        'totalChecks': _totalChecks,
        'layer1Triggers': _layer1Triggers,
        'layer2Triggers': _layer2Triggers,
        'layer3Triggers': _layer3Triggers,
      };

  /// 更新TTS状态
  void updateTTSState({
    required bool isPlaying,
    required String currentText,
  }) {
    _isTTSPlaying = isPlaying;
    _currentTTSText = currentText;

    // 同步更新回声过滤器
    if (isPlaying) {
      _echoFilter.onTTSStarted(currentText);
    } else {
      _echoFilter.onTTSStopped();
    }
  }

  /// 追加TTS文本（流式TTS场景）
  void appendTTSText(String text) {
    _currentTTSText += text;
    _echoFilter.onTTSTextAppended(text);
  }

  /// 更新VAD状态
  void updateVADState(bool isSpeechDetected) {
    _vadSpeechDetected = isSpeechDetected;
  }

  /// 处理ASR中间结果
  ///
  /// 检查第1层和第2层打断条件
  BargeInResult handlePartialResult(String text) {
    if (!_isTTSPlaying) return BargeInResult.notTriggered;
    if (!_canCheck()) return BargeInResult.notTriggered;
    if (!_canBargeIn()) return BargeInResult.notTriggered;

    _totalChecks++;
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return BargeInResult.notTriggered;

    // 第1层：VAD + ASR联合检测（最快）
    if (_vadSpeechDetected && cleanText.length >= _config.bargeInLayer1MinChars) {
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      if (similarity < _config.bargeInLayer1Threshold) {
        _layer1Triggers++;
        final result = BargeInResult(
          triggered: true,
          layer: BargeInLayer.layer1VadAsr,
          text: text,
          similarity: similarity,
        );
        _triggerBargeIn(result);
        return result;
      }
    }

    // 第2层：纯ASR中间结果检测
    if (cleanText.length >= _config.bargeInLayer2MinChars) {
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      if (similarity < _config.bargeInLayer2Threshold) {
        _layer2Triggers++;
        final result = BargeInResult(
          triggered: true,
          layer: BargeInLayer.layer2Asr,
          text: text,
          similarity: similarity,
        );
        _triggerBargeIn(result);
        return result;
      }
    }

    return BargeInResult.notTriggered;
  }

  /// 处理ASR最终结果
  ///
  /// 检查第3层打断条件（完整句子 + 回声过滤）
  BargeInResult handleFinalResult(String text) {
    if (!_isTTSPlaying) return BargeInResult.notTriggered;
    if (!_canBargeIn()) return BargeInResult.notTriggered;

    _totalChecks++;
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return BargeInResult.notTriggered;

    // 使用回声过滤器检查
    if (_echoFilter.isEcho(text, isPartial: false)) {
      debugPrint('[BargeInDetectorV2] 第3层: 回声过滤，忽略');
      return BargeInResult.notTriggered;
    }

    // 通过回声过滤，触发打断
    _layer3Triggers++;
    final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
    final result = BargeInResult(
      triggered: true,
      layer: BargeInLayer.layer3Final,
      text: text,
      similarity: similarity,
    );
    _triggerBargeIn(result);
    return result;
  }

  /// 是否可以触发打断（冷却时间检查）
  bool _canBargeIn() {
    if (_lastBargeInTime == null) return true;
    final elapsed = DateTime.now().difference(_lastBargeInTime!);
    return elapsed.inMilliseconds > _config.bargeInCooldownMs;
  }

  /// 节流检查
  bool _canCheck() {
    final now = DateTime.now();
    if (_lastCheckTime == null) {
      _lastCheckTime = now;
      return true;
    }

    final elapsed = now.difference(_lastCheckTime!);
    if (elapsed.inMilliseconds < _config.similarityThrottleMs) {
      return false;
    }

    _lastCheckTime = now;
    return true;
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
    _lastBargeInTime = null;
    _lastCheckTime = null;
    _echoFilter.reset();
    debugPrint('[BargeInDetectorV2] 重置');
  }

  /// 重置统计信息
  void resetStats() {
    _layer1Triggers = 0;
    _layer2Triggers = 0;
    _layer3Triggers = 0;
    _totalChecks = 0;
    _echoFilter.resetStats();
  }
}
