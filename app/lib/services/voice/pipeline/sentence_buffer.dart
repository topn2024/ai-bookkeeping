import '../config/pipeline_config.dart';

/// 句子缓冲区
///
/// 从LLM流式输出中检测完整句子，用于TTS分句合成。
///
/// 工作原理：
/// 1. 接收LLM流式输出的文本块
/// 2. 检测句子分隔符（。！？；\n）
/// 3. 当检测到完整句子且长度满足要求时输出
/// 4. 支持强制刷新剩余内容
class SentenceBuffer {
  final PipelineConfig _config;
  final StringBuffer _buffer = StringBuffer();

  /// 已输出的句子数量
  int _sentenceCount = 0;

  /// 创建句子缓冲区
  SentenceBuffer({PipelineConfig? config})
      : _config = config ?? PipelineConfig.defaultConfig;

  /// 当前缓冲区内容
  String get currentBuffer => _buffer.toString();

  /// 缓冲区长度
  int get length => _buffer.length;

  /// 已输出的句子数量
  int get sentenceCount => _sentenceCount;

  /// 缓冲区是否为空
  bool get isEmpty => _buffer.isEmpty;

  /// 添加文本块
  ///
  /// 返回检测到的完整句子列表（可能为空或包含多个句子）
  ///
  /// 示例：
  /// ```dart
  /// final buffer = SentenceBuffer();
  /// buffer.addChunk("今天花了"); // 返回 []
  /// buffer.addChunk("100元。明天"); // 返回 ["今天花了100元。"]
  /// buffer.addChunk("要省点。"); // 返回 ["明天要省点。"]
  /// ```
  List<String> addChunk(String chunk) {
    if (chunk.isEmpty) return [];

    _buffer.write(chunk);
    final sentences = <String>[];

    // 持续检测句子，直到没有更多完整句子
    while (true) {
      final sentence = _extractSentence();
      if (sentence == null) break;
      sentences.add(sentence);
      _sentenceCount++;
    }

    // 检查是否超过最大缓冲长度，强制输出
    if (_buffer.length > _config.maxBufferLength) {
      final forced = _forceExtract();
      if (forced != null && forced.isNotEmpty) {
        sentences.add(forced);
        _sentenceCount++;
      }
    }

    return sentences;
  }

  /// 从缓冲区提取一个完整句子
  ///
  /// 返回null表示没有完整句子
  String? _extractSentence() {
    final text = _buffer.toString();
    if (text.isEmpty) return null;

    // 查找最近的句子分隔符
    int earliestIndex = -1;
    for (final delimiter in _config.sentenceDelimiters) {
      final index = text.indexOf(delimiter);
      if (index >= 0 && (earliestIndex < 0 || index < earliestIndex)) {
        earliestIndex = index;
      }
    }

    if (earliestIndex < 0) return null;

    // 提取句子（包含分隔符）
    final sentence = text.substring(0, earliestIndex + 1).trim();
    final remaining = text.substring(earliestIndex + 1);

    // 检查最小长度
    if (sentence.length < _config.minSentenceLength) {
      // 句子太短，保留在缓冲区继续累积
      return null;
    }

    // 更新缓冲区
    _buffer.clear();
    _buffer.write(remaining);

    return sentence;
  }

  /// 强制提取缓冲区内容
  ///
  /// 当缓冲区超长时使用，在合适位置截断
  String? _forceExtract() {
    final text = _buffer.toString();
    if (text.isEmpty) return null;

    // 尝试在逗号处截断
    final commaDelimiters = ['，', ',', '、'];
    for (final delimiter in commaDelimiters) {
      final index = text.lastIndexOf(delimiter);
      if (index > _config.minSentenceLength) {
        final sentence = text.substring(0, index + 1).trim();
        final remaining = text.substring(index + 1);
        _buffer.clear();
        _buffer.write(remaining);
        return sentence;
      }
    }

    // 没有找到合适位置，直接截取
    final cutLength = _config.maxBufferLength ~/ 2;
    if (text.length > cutLength) {
      final sentence = text.substring(0, cutLength).trim();
      final remaining = text.substring(cutLength);
      _buffer.clear();
      _buffer.write(remaining);
      return sentence;
    }

    return null;
  }

  /// 刷新缓冲区，获取剩余内容
  ///
  /// 用于LLM生成完成后获取最后一部分内容
  String flush() {
    final remaining = _buffer.toString().trim();
    _buffer.clear();
    if (remaining.isNotEmpty) {
      _sentenceCount++;
    }
    return remaining;
  }

  /// 清空缓冲区
  void clear() {
    _buffer.clear();
    _sentenceCount = 0;
  }

  /// 重置缓冲区（保留统计）
  void reset() {
    _buffer.clear();
  }
}
