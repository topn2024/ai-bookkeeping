import 'package:flutter/foundation.dart';

import '../config/pipeline_config.dart';
import 'similarity_calculator.dart';

/// 回声过滤结果
enum EchoFilterResult {
  /// 通过过滤（不是回声）
  pass,

  /// 被过滤（是回声）
  filtered,

  /// 可疑（在静默窗口内，需要更严格判断）
  suspicious,
}

/// 回声过滤器
///
/// 简化版回声防护机制（参考chat-companion-app的简单直接模式）：
/// 1. 硬件级AEC（录音配置，在录音层面已处理）
/// 2. 文本相似度过滤（简单阈值判断）
/// 3. 短句过滤（最小长度检查）
///
/// 设计原则：
/// - 宁可漏过回声，不可误杀用户输入
/// - VAD检测到语音时，大幅放宽过滤条件
/// - 简单直接，减少复杂逻辑
class EchoFilter {
  final PipelineConfig _config;
  final SimilarityCalculator _similarity = SimilarityCalculator();

  /// 当前TTS文本
  String _currentTTSText = '';

  /// TTS是否正在播放
  bool _isTTSPlaying = false;

  /// TTS结束时间
  DateTime? _ttsEndTime;

  /// VAD是否检测到语音（用于动态阈值）
  bool _vadSpeechDetected = false;

  /// 上次过滤回声的时间
  DateTime? _lastEchoFilterTime;

  /// 统计信息
  int _totalChecks = 0;
  int _filteredCount = 0;
  int _suspiciousCount = 0;

  EchoFilter({PipelineConfig? config})
      : _config = config ?? PipelineConfig.defaultConfig;

  /// 是否在静默窗口内
  bool get isInSilenceWindow {
    if (_ttsEndTime == null) return false;
    final elapsed = DateTime.now().difference(_ttsEndTime!);
    return elapsed.inMilliseconds < _config.echoSilenceWindowMs;
  }

  /// 是否在回声过滤冷却期内
  bool get isInEchoFilterCooldown {
    if (_lastEchoFilterTime == null) return false;
    final elapsed = DateTime.now().difference(_lastEchoFilterTime!);
    return elapsed.inMilliseconds < _config.echoFilterCooldownMs;
  }

  /// TTS是否正在播放
  bool get isTTSPlaying => _isTTSPlaying;

  /// 当前TTS文本
  String get currentTTSText => _currentTTSText;

  /// VAD是否检测到语音
  bool get vadSpeechDetected => _vadSpeechDetected;

  /// 过滤统计
  Map<String, int> get stats => {
        'totalChecks': _totalChecks,
        'filteredCount': _filteredCount,
        'suspiciousCount': _suspiciousCount,
        'passCount': _totalChecks - _filteredCount - _suspiciousCount,
      };

  /// 过滤率
  double get filterRate =>
      _totalChecks > 0 ? _filteredCount / _totalChecks : 0.0;

  /// 更新VAD状态
  void updateVADState(bool isSpeechDetected) {
    _vadSpeechDetected = isSpeechDetected;
  }

  /// 通知TTS开始播放
  void onTTSStarted(String text) {
    _currentTTSText = text;
    _isTTSPlaying = true;
    _ttsEndTime = null;
    debugPrint('[EchoFilter] TTS开始: "${_truncate(text, 20)}"');
  }

  /// 通知TTS追加文本（用于流式TTS）
  void onTTSTextAppended(String text) {
    _currentTTSText += text;
  }

  /// 通知TTS停止播放
  void onTTSStopped() {
    _isTTSPlaying = false;
    _ttsEndTime = DateTime.now();
    debugPrint('[EchoFilter] TTS停止，进入静默窗口 (${_config.echoSilenceWindowMs}ms)');
  }

  /// 检查ASR结果是否为回声
  ///
  /// [asrText] ASR识别的文本
  /// [isPartial] 是否为中间结果
  ///
  /// 返回过滤结果
  ///
  /// 简化版逻辑（参考chat-companion-app）：
  /// - TTS没播放且不在静默窗口 → 直接通过
  /// - VAD检测到语音 → 大幅放宽，几乎不过滤
  /// - 只做简单的相似度检查
  EchoFilterResult check(String asrText, {bool isPartial = false}) {
    _totalChecks++;
    final cleanText = _cleanText(asrText);

    // 如果TTS没有播放且不在静默窗口，直接通过（最常见的情况）
    if (!_isTTSPlaying && !isInSilenceWindow) {
      return EchoFilterResult.pass;
    }

    // VAD检测到语音时，用户很可能在说话，大幅放宽过滤
    // 参考chat-companion-app: 只过滤非常短的文本
    if (_vadSpeechDetected) {
      // VAD检测到语音，只过滤1个字以下的噪音
      if (cleanText.length < 2) {
        _filteredCount++;
        debugPrint('[EchoFilter] VAD模式-极短文本过滤: "$asrText"');
        return EchoFilterResult.filtered;
      }
      // VAD模式下，几乎不做其他过滤，让用户输入通过
      debugPrint('[EchoFilter] VAD检测到语音，放行: "$asrText"');
      return EchoFilterResult.pass;
    }

    // 没有VAD的情况，做基本的短文本过滤
    if (cleanText.length < _config.echoMinTextLength) {
      _filteredCount++;
      _lastEchoFilterTime = DateTime.now();
      debugPrint('[EchoFilter] 短文本过滤: "$asrText" (len=${cleanText.length})');
      return EchoFilterResult.filtered;
    }

    // 简单的相似度检查（TTS正在播放或在静默窗口内）
    if (_currentTTSText.isNotEmpty) {
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      // 使用较高的阈值（0.7），宁可漏过回声也不误杀用户输入
      final threshold = 0.7;

      if (similarity > threshold) {
        _filteredCount++;
        _lastEchoFilterTime = DateTime.now();
        debugPrint('[EchoFilter] 相似度过滤: "$asrText" (sim=$similarity > $threshold)');
        return EchoFilterResult.filtered;
      }
    }

    return EchoFilterResult.pass;
  }

  /// 快速检查是否为回声（布尔返回值）
  bool isEcho(String asrText, {bool isPartial = false}) {
    return check(asrText, isPartial: isPartial) == EchoFilterResult.filtered;
  }

  /// 清理文本（移除标点和空白）
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp('[。，！？；、：""''（）【】《》,.!?;:\\s]'), '')
        .toLowerCase();
  }

  /// 截断文本用于日志
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// 重置过滤器状态
  void reset() {
    _currentTTSText = '';
    _isTTSPlaying = false;
    _ttsEndTime = null;
    _vadSpeechDetected = false;
    _lastEchoFilterTime = null;
    debugPrint('[EchoFilter] 重置');
  }

  /// 重置统计信息
  void resetStats() {
    _totalChecks = 0;
    _filteredCount = 0;
    _suspiciousCount = 0;
  }
}
