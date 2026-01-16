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
/// 四层回声防护机制：
/// 1. 硬件级AEC（录音配置，在录音层面已处理）
/// 2. 文本相似度过滤
/// 3. 短句过滤
/// 4. 静默窗口
///
/// 使用场景：
/// 当TTS播放时，ASR可能会识别到扬声器播放的声音，
/// 导致误将TTS内容当作用户输入。回声过滤器用于识别
/// 并过滤这些回声。
class EchoFilter {
  final PipelineConfig _config;
  final SimilarityCalculator _similarity = SimilarityCalculator();

  /// 当前TTS文本
  String _currentTTSText = '';

  /// TTS是否正在播放
  bool _isTTSPlaying = false;

  /// TTS结束时间
  DateTime? _ttsEndTime;

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

  /// TTS是否正在播放
  bool get isTTSPlaying => _isTTSPlaying;

  /// 当前TTS文本
  String get currentTTSText => _currentTTSText;

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
    debugPrint('[EchoFilter] TTS停止，进入静默窗口');
  }

  /// 检查ASR结果是否为回声
  ///
  /// [asrText] ASR识别的文本
  /// [isPartial] 是否为中间结果（中间结果使用更宽松的阈值）
  ///
  /// 返回过滤结果
  EchoFilterResult check(String asrText, {bool isPartial = false}) {
    _totalChecks++;
    final cleanText = _cleanText(asrText);

    // 1. 短文本过滤
    if (cleanText.length < _config.echoMinTextLength) {
      _filteredCount++;
      debugPrint('[EchoFilter] 短文本过滤: "$asrText"');
      return EchoFilterResult.filtered;
    }

    // 如果TTS没有播放且不在静默窗口，直接通过
    if (!_isTTSPlaying && !isInSilenceWindow) {
      return EchoFilterResult.pass;
    }

    // 2. 静默窗口检查
    if (isInSilenceWindow && !_isTTSPlaying) {
      // 在静默窗口内，使用更严格的阈值
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      final strictThreshold = _config.echoSimilarityThreshold * 0.8;

      if (similarity > strictThreshold) {
        _filteredCount++;
        debugPrint('[EchoFilter] 静默窗口过滤: "$asrText" (相似度=$similarity)');
        return EchoFilterResult.filtered;
      }

      _suspiciousCount++;
      debugPrint('[EchoFilter] 静默窗口可疑: "$asrText" (相似度=$similarity)');
      return EchoFilterResult.suspicious;
    }

    // 3. 文本相似度过滤
    if (_isTTSPlaying && _currentTTSText.isNotEmpty) {
      final similarity = _similarity.calculate(cleanText, _cleanText(_currentTTSText));
      final threshold = isPartial
          ? _config.echoSimilarityThreshold * 1.2 // 中间结果更宽松
          : _config.echoSimilarityThreshold;

      if (similarity > threshold) {
        _filteredCount++;
        debugPrint('[EchoFilter] 相似度过滤: "$asrText" (相似度=$similarity)');
        return EchoFilterResult.filtered;
      }

      // 4. 前缀匹配检查（回声通常从TTS开头开始）
      if (_similarity.isPrefixMatch(cleanText, _cleanText(_currentTTSText))) {
        _filteredCount++;
        debugPrint('[EchoFilter] 前缀匹配过滤: "$asrText"');
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
    debugPrint('[EchoFilter] 重置');
  }

  /// 重置统计信息
  void resetStats() {
    _totalChecks = 0;
    _filteredCount = 0;
    _suspiciousCount = 0;
  }
}
