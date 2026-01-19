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

/// 简化版打断检测器
///
/// 设计原则（参考chat-companion-app）：
/// - 宁可多响应打断，不可漏掉用户真正的打断意图
/// - VAD检测到语音 + 有内容 → 快速触发打断
/// - 简单直接，减少复杂条件判断
///
/// 层级设计：
/// - 第1层：VAD + ASR（最快）
/// - 第2层：纯ASR（较长文本）
/// - 第3层：完整句子
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
    // 同步VAD状态到回声过滤器（用于动态阈值）
    _echoFilter.updateVADState(isSpeechDetected);
  }

  /// 处理ASR中间结果
  ///
  /// 简化版检测逻辑（参考chat-companion-app）：
  /// - VAD检测到语音 + 有足够内容 → 快速触发
  /// - 宁可多触发，不可漏掉用户打断
  /// - 但需要防止TTS回声被误识别后触发误打断
  BargeInResult handlePartialResult(String text) {
    if (!_isTTSPlaying) return BargeInResult.notTriggered;
    if (!_canBargeIn()) return BargeInResult.notTriggered;

    _totalChecks++;
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) return BargeInResult.notTriggered;

    // 新增：如果在TTS播放的早期阶段（前1秒），不允许打断
    // 这个阶段回声误识别最严重，即使文本完全不匹配也可能是回声
    if (_echoFilter.isInTTSEarlyPhase) {
      debugPrint('[BargeInDetectorV2] 在TTS早期阶段，跳过打断检测: "$text"');
      return BargeInResult.notTriggered;
    }

    // 新增：如果在静默窗口内且VAD没有检测到语音，跳过
    // 静默窗口内的ASR结果很可能是残留的TTS回声
    if (_echoFilter.isInSilenceWindow && !_vadSpeechDetected) {
      debugPrint('[BargeInDetectorV2] 在静默窗口内且无VAD，跳过打断检测: "$text"');
      return BargeInResult.notTriggered;
    }

    // 注意：不在这里使用回声过滤器拦截
    // 因为当用户在TTS播放时说话，ASR会捕获混合内容
    // 我们依赖VAD+ASR内容长度来判断，而不是文本相似度

    // 第1层：VAD + ASR联合检测（最快，最重要）
    // 如果VAD检测到语音且有一定内容，直接触发打断
    if (_vadSpeechDetected && cleanText.length >= _config.bargeInLayer1MinChars) {
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      // 使用较高的阈值（更容易通过），宁可多触发
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

    // 第2层：纯ASR中间结果检测（较长文本）
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
