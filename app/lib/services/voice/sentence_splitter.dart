/// 语音输入分句器
///
/// 将用户的连续语音输入分解为多个独立的语义片段，
/// 支持多意图识别。
class SentenceSplitter {
  /// 强分隔符（明确的句子边界）
  static final _strongDelimiters = RegExp(r'[。！？；\n]');

  /// 连接词（表示新事件开始）
  static final _connectors = [
    '然后',
    '还有',
    '另外',
    '接着',
    '之后',
    '后来',
    '再',
    '又',
    '以及',
    '同时',
  ];

  /// 时间转换词（表示新时间点/新事件）
  static final _timeTransitions = [
    '早上',
    '上午',
    '中午',
    '下午',
    '晚上',
    '昨天',
    '今天',
    '明天',
    '刚才',
    '后来',
    '回来',
    '回去',
  ];

  /// 动作动词（判断语义完整性）
  static final _actionVerbs = [
    '花',
    '买',
    '吃',
    '喝',
    '打车',
    '坐',
    '付',
    '给',
    '收',
    '转',
    '消费',
    '支出',
    '收入',
    '存',
    '取',
    '充值',
    '打开',
    '查看',
    '看看',
  ];

  /// 分句配置
  final SplitterConfig config;

  SentenceSplitter({this.config = const SplitterConfig()});

  /// 分割输入文本为多个语义片段
  ///
  /// 处理流程：
  /// 1. 按强分隔符分割
  /// 2. 检测连接词边界
  /// 3. 检测时间转换边界
  /// 4. 按逗号分割多笔交易
  /// 5. 合并过短片段
  /// 6. 过滤空白和无意义片段
  List<String> split(String text) {
    if (text.trim().isEmpty) {
      return [];
    }

    // 1. 按强分隔符分割
    var segments = _splitByStrongDelimiters(text);

    // 2. 按连接词进一步分割
    segments = _splitByConnectors(segments);

    // 3. 按时间转换词分割
    segments = _splitByTimeTransitions(segments);

    // 4. 按逗号分割多笔交易（如"打车15，买菜18"）
    segments = _splitByCommaWithAction(segments);

    // 5. 合并过短且无动作的片段
    segments = _mergeShortSegments(segments);

    // 6. 过滤和清理
    segments = _cleanSegments(segments);

    return segments;
  }

  /// 按逗号分割包含多个动作的句子
  ///
  /// 处理如"打车花了15，买菜花了18"或"打车花了15，买菜花了，28"这样的句子
  List<String> _splitByCommaWithAction(List<String> segments) {
    final result = <String>[];

    for (final segment in segments) {
      // 按逗号分割
      final parts = segment.split(RegExp(r'[，,]'));

      if (parts.length <= 1) {
        result.add(segment);
        continue;
      }

      // 预处理：合并"动作"和紧随的"金额"部分
      // 例如：["买菜花了", "28"] → ["买菜花了28"]
      final mergedParts = <String>[];
      var i = 0;
      while (i < parts.length) {
        final current = parts[i].trim();
        if (current.isEmpty) {
          i++;
          continue;
        }

        final hasAction = _hasActionVerb(current);
        final hasAmount = RegExp(r'\d+|[一二三四五六七八九十百千万两]+').hasMatch(current);

        // 如果当前部分只有动作没有金额，检查下一个部分
        if (hasAction && !hasAmount && i + 1 < parts.length) {
          final next = parts[i + 1].trim();
          final nextHasAmount = RegExp(r'^\d+|^[一二三四五六七八九十百千万两]+').hasMatch(next);
          final nextHasAction = _hasActionVerb(next);

          if (nextHasAmount && !nextHasAction) {
            // 合并动作和金额
            mergedParts.add('$current$next');
            i += 2;
            continue;
          }
        }

        mergedParts.add(current);
        i++;
      }

      // 检查每个部分是否有独立的动作+金额
      final validParts = <String>[];
      var buffer = '';

      for (final part in mergedParts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;

        final hasAction = _hasActionVerb(trimmed);
        final hasAmount = RegExp(r'\d+|[一二三四五六七八九十百千万两]+').hasMatch(trimmed);

        if (hasAction && hasAmount) {
          // 这是一个独立的交易记录
          if (buffer.isNotEmpty) {
            // 先把 buffer 中的内容加到这个部分前面
            validParts.add('$buffer，$trimmed');
            buffer = '';
          } else {
            validParts.add(trimmed);
          }
        } else if (hasAction || hasAmount) {
          // 有动作或金额但不完整，暂存
          if (buffer.isNotEmpty) {
            buffer = '$buffer，$trimmed';
          } else {
            buffer = trimmed;
          }
        } else {
          // 没有动作和金额，作为修饰语暂存
          if (buffer.isNotEmpty) {
            buffer = '$buffer，$trimmed';
          } else {
            buffer = trimmed;
          }
        }
      }

      // 处理剩余的 buffer
      if (buffer.isNotEmpty) {
        if (validParts.isNotEmpty) {
          // 合并到最后一个有效部分
          validParts[validParts.length - 1] = '${validParts.last}，$buffer';
        } else {
          validParts.add(buffer);
        }
      }

      if (validParts.isEmpty) {
        result.add(segment);
      } else {
        result.addAll(validParts);
      }
    }

    return result;
  }

  /// 按强分隔符分割
  List<String> _splitByStrongDelimiters(String text) {
    return text
        .split(_strongDelimiters)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 按连接词分割
  List<String> _splitByConnectors(List<String> segments) {
    final result = <String>[];

    for (final segment in segments) {
      result.addAll(_splitByPatterns(segment, _connectors));
    }

    return result;
  }

  /// 按时间转换词分割
  List<String> _splitByTimeTransitions(List<String> segments) {
    final result = <String>[];

    for (final segment in segments) {
      result.addAll(_splitByPatterns(segment, _timeTransitions));
    }

    return result;
  }

  /// 按模式列表分割文本
  List<String> _splitByPatterns(String text, List<String> patterns) {
    // 查找所有模式的位置
    final splits = <_SplitPoint>[];

    for (final pattern in patterns) {
      var index = 0;
      while (true) {
        final pos = text.indexOf(pattern, index);
        if (pos == -1) break;

        // 只在非开头位置分割，避免丢失开头的时间词
        if (pos > 0) {
          // 检查前一个字符是否为逗号或空格，这种情况更适合分割
          final prevChar = text[pos - 1];
          final isSoftBoundary = prevChar == '，' || prevChar == ',' || prevChar == ' ';

          splits.add(_SplitPoint(
            position: pos,
            pattern: pattern,
            isSoftBoundary: isSoftBoundary,
          ));
        }

        index = pos + pattern.length;
      }
    }

    if (splits.isEmpty) {
      return [text];
    }

    // 按位置排序
    splits.sort((a, b) => a.position.compareTo(b.position));

    // 分割文本
    final result = <String>[];
    var lastEnd = 0;

    for (final split in splits) {
      // 获取分割点之前的文本
      var before = text.substring(lastEnd, split.position).trim();

      // 移除尾部的逗号
      if (before.endsWith('，') || before.endsWith(',')) {
        before = before.substring(0, before.length - 1).trim();
      }

      if (before.isNotEmpty) {
        result.add(before);
      }

      lastEnd = split.position;
    }

    // 添加最后一段
    final last = text.substring(lastEnd).trim();
    if (last.isNotEmpty) {
      result.add(last);
    }

    return result;
  }

  /// 合并过短且无动作的片段
  List<String> _mergeShortSegments(List<String> segments) {
    if (segments.length <= 1) {
      return segments;
    }

    final result = <String>[];
    var buffer = '';

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // 检查片段是否有独立的动作意图
      final hasAction = _hasActionVerb(segment);
      final isShort = segment.length < config.minSegmentLength;

      if (isShort && !hasAction && buffer.isNotEmpty) {
        // 短片段无动作，合并到前一个
        buffer = '$buffer，$segment';
      } else if (isShort && !hasAction && i < segments.length - 1) {
        // 短片段无动作，暂存准备合并到后一个
        buffer = segment;
      } else {
        // 有动作或足够长，作为独立片段
        if (buffer.isNotEmpty) {
          // 决定buffer合并到前还是后
          if (result.isNotEmpty && !hasAction) {
            // 合并到前一个
            result[result.length - 1] = '${result.last}，$buffer';
            buffer = '';
          } else if (hasAction) {
            // 合并到当前
            result.add('$buffer，$segment');
            buffer = '';
            continue;
          }
        }

        if (buffer.isNotEmpty) {
          result.add(buffer);
          buffer = '';
        }
        result.add(segment);
      }
    }

    // 处理剩余的buffer
    if (buffer.isNotEmpty) {
      if (result.isNotEmpty) {
        result[result.length - 1] = '${result.last}，$buffer';
      } else {
        result.add(buffer);
      }
    }

    return result;
  }

  /// 清理片段
  List<String> _cleanSegments(List<String> segments) {
    return segments
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .where((s) => s.length >= config.minSegmentLength || _hasActionVerb(s))
        .toList();
  }

  /// 检查文本是否包含动作动词
  bool _hasActionVerb(String text) {
    return _actionVerbs.any((verb) => text.contains(verb));
  }

  /// 检查片段是否为完整的语义单元
  bool isSemanticComplete(String segment) {
    // 有动作动词且有数量/金额表达通常是完整的
    if (_hasActionVerb(segment)) {
      // 检查是否有数字
      final hasNumber = RegExp(r'\d').hasMatch(segment);
      if (hasNumber) return true;
    }

    // 导航意图通常是完整的
    final navKeywords = ['打开', '进入', '去', '跳转', '查看', '看看'];
    if (navKeywords.any((k) => segment.contains(k))) {
      return true;
    }

    return false;
  }
}

/// 分割点信息
class _SplitPoint {
  final int position;
  final String pattern;
  final bool isSoftBoundary;

  _SplitPoint({
    required this.position,
    required this.pattern,
    required this.isSoftBoundary,
  });
}

/// 分句器配置
class SplitterConfig {
  /// 最小片段长度
  final int minSegmentLength;

  /// 是否保留标点符号
  final bool preservePunctuation;

  /// 是否启用时间词分割
  final bool enableTimeSplit;

  /// 是否启用连接词分割
  final bool enableConnectorSplit;

  const SplitterConfig({
    this.minSegmentLength = 2,
    this.preservePunctuation = false,
    this.enableTimeSplit = true,
    this.enableConnectorSplit = true,
  });
}
