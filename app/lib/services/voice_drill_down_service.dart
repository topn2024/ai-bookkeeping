import 'dart:async';
import 'package:flutter/foundation.dart';

/// 语音下钻指令类型
enum VoiceDrillDownCommandType {
  /// 下钻到分类
  drillDownCategory,

  /// 下钻到时间
  drillDownTime,

  /// 下钻到账户
  drillDownAccount,

  /// 下钻到家庭成员
  drillDownMember,

  /// 下钻到位置
  drillDownLocation,

  /// 返回上一级
  goBack,

  /// 返回首页
  goHome,

  /// 切换视图
  switchView,

  /// 筛选
  filter,

  /// 查询
  query,

  /// 比较
  compare,

  /// 展示详情
  showDetail,

  /// 分享
  share,
}

/// 语音下钻指令
class VoiceDrillDownCommand {
  /// 指令类型
  final VoiceDrillDownCommandType type;

  /// 目标值（如分类名、时间范围等）
  final String? target;

  /// 参数
  final Map<String, dynamic>? params;

  /// 原始语音文本
  final String? rawText;

  /// 置信度（0-1）
  final double confidence;

  /// 创建时间
  final DateTime createdAt;

  VoiceDrillDownCommand({
    required this.type,
    this.target,
    this.params,
    this.rawText,
    this.confidence = 1.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() =>
      'VoiceDrillDownCommand($type, target=$target, confidence=$confidence)';
}

/// 指令解析结果
class CommandParseResult {
  /// 是否成功
  final bool success;

  /// 解析出的指令
  final VoiceDrillDownCommand? command;

  /// 错误信息
  final String? errorMessage;

  /// 候选指令列表（用于消歧）
  final List<VoiceDrillDownCommand>? candidates;

  const CommandParseResult({
    required this.success,
    this.command,
    this.errorMessage,
    this.candidates,
  });

  factory CommandParseResult.success(VoiceDrillDownCommand command) {
    return CommandParseResult(success: true, command: command);
  }

  factory CommandParseResult.failure(String message) {
    return CommandParseResult(success: false, errorMessage: message);
  }

  factory CommandParseResult.ambiguous(List<VoiceDrillDownCommand> candidates) {
    return CommandParseResult(
      success: false,
      errorMessage: '请选择您想要的操作',
      candidates: candidates,
    );
  }
}

/// 指令模式
class CommandPattern {
  /// 正则表达式
  final RegExp pattern;

  /// 指令类型
  final VoiceDrillDownCommandType type;

  /// 目标提取函数
  final String? Function(Match match)? targetExtractor;

  /// 参数提取函数
  final Map<String, dynamic>? Function(Match match)? paramsExtractor;

  const CommandPattern({
    required this.pattern,
    required this.type,
    this.targetExtractor,
    this.paramsExtractor,
  });
}

/// 语音下钻指令解析器配置
class VoiceDrillDownParserConfig {
  /// 自定义指令模式
  final List<CommandPattern> customPatterns;

  /// 是否启用模糊匹配
  final bool enableFuzzyMatching;

  /// 模糊匹配阈值
  final double fuzzyMatchThreshold;

  /// 是否启用上下文理解
  final bool enableContextAwareness;

  const VoiceDrillDownParserConfig({
    this.customPatterns = const [],
    this.enableFuzzyMatching = true,
    this.fuzzyMatchThreshold = 0.7,
    this.enableContextAwareness = true,
  });
}

/// 语音下钻指令与可视化系统集成服务
///
/// 核心功能：
/// 1. 解析语音指令
/// 2. 生成下钻命令
/// 3. 与可视化组件集成
/// 4. 上下文理解
/// 5. 多轮对话支持
///
/// 对应设计文档：第12.7节 语音下钻指令与可视化系统集成
///
/// 使用示例：
/// ```dart
/// final service = VoiceDrillDownService();
///
/// // 解析语音指令
/// final result = service.parseCommand('看看餐饮的详细消费');
/// if (result.success) {
///   drillDownService.execute(result.command!);
/// }
/// ```
class VoiceDrillDownService extends ChangeNotifier {
  /// 配置
  VoiceDrillDownParserConfig _config;

  /// 指令历史
  final List<VoiceDrillDownCommand> _commandHistory = [];

  /// 当前上下文
  Map<String, dynamic> _context = {};

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  /// 内置指令模式
  static final List<CommandPattern> _builtInPatterns = [
    // 下钻到分类
    CommandPattern(
      pattern: RegExp(r'(看看|查看|显示|展开|进入)?(.+?)(的|类)?(?:详细|详情|消费|支出|收入)?'),
      type: VoiceDrillDownCommandType.drillDownCategory,
      targetExtractor: (match) => match.group(2)?.trim(),
    ),

    // 时间下钻
    CommandPattern(
      pattern: RegExp(r'(本月|上月|本周|上周|今天|昨天|今年|去年|(\d+)月|(\d+)号)(?:的)?(?:消费|支出|收入|数据)?'),
      type: VoiceDrillDownCommandType.drillDownTime,
      targetExtractor: (match) => match.group(1),
    ),

    // 返回
    CommandPattern(
      pattern: RegExp(r'(返回|后退|上一级|回去)'),
      type: VoiceDrillDownCommandType.goBack,
    ),

    // 回到首页
    CommandPattern(
      pattern: RegExp(r'(首页|主页|回到首页|返回首页|回到开始)'),
      type: VoiceDrillDownCommandType.goHome,
    ),

    // 切换视图
    CommandPattern(
      pattern: RegExp(r'(切换|显示|换成)(?:到)?(饼图|柱状图|趋势图|列表|热力图)'),
      type: VoiceDrillDownCommandType.switchView,
      targetExtractor: (match) => match.group(2),
    ),

    // 筛选
    CommandPattern(
      pattern: RegExp(r'(筛选|过滤|只看|仅显示)(.+)'),
      type: VoiceDrillDownCommandType.filter,
      targetExtractor: (match) => match.group(2)?.trim(),
    ),

    // 比较
    CommandPattern(
      pattern: RegExp(r'(比较|对比)(.+?)(?:和|与|跟)(.+)'),
      type: VoiceDrillDownCommandType.compare,
      paramsExtractor: (match) => {
        'first': match.group(2)?.trim(),
        'second': match.group(3)?.trim(),
      },
    ),

    // 查询
    CommandPattern(
      pattern: RegExp(r'(.+?)(?:花了|消费了|支出|收入)(?:多少|是多少)'),
      type: VoiceDrillDownCommandType.query,
      targetExtractor: (match) => match.group(1)?.trim(),
    ),

    // 分享
    CommandPattern(
      pattern: RegExp(r'(分享|发送|导出)(?:这个|当前)?(?:图表|报表|数据)?'),
      type: VoiceDrillDownCommandType.share,
    ),

    // 看详情
    CommandPattern(
      pattern: RegExp(r'(详情|详细信息|展开|更多)'),
      type: VoiceDrillDownCommandType.showDetail,
    ),

    // 家庭成员下钻
    CommandPattern(
      pattern: RegExp(r'(看看|查看)?(.+?)(的消费|花了多少|支出)'),
      type: VoiceDrillDownCommandType.drillDownMember,
      targetExtractor: (match) => match.group(2)?.trim(),
    ),

    // 位置下钻
    CommandPattern(
      pattern: RegExp(r'(?:在)?(.+?)(?:的|花费|消费|支出)'),
      type: VoiceDrillDownCommandType.drillDownLocation,
      targetExtractor: (match) => match.group(1)?.trim(),
    ),
  ];

  /// 分类别名映射
  static final Map<String, String> _categoryAliases = {
    '吃饭': '餐饮',
    '吃的': '餐饮',
    '饭钱': '餐饮',
    '外卖': '餐饮',
    '买菜': '餐饮',
    '出行': '交通',
    '打车': '交通',
    '加油': '交通',
    '坐车': '交通',
    '购物': '购物',
    '买东西': '购物',
    '娱乐': '娱乐',
    '玩': '娱乐',
    '房租': '住房',
    '水电': '住房',
    '话费': '通讯',
    '网费': '通讯',
  };

  /// 时间别名映射
  static final Map<String, Map<String, dynamic>> _timeAliases = {
    '今天': {'type': 'day', 'offset': 0},
    '昨天': {'type': 'day', 'offset': -1},
    '前天': {'type': 'day', 'offset': -2},
    '本周': {'type': 'week', 'offset': 0},
    '上周': {'type': 'week', 'offset': -1},
    '本月': {'type': 'month', 'offset': 0},
    '上月': {'type': 'month', 'offset': -1},
    '上个月': {'type': 'month', 'offset': -1},
    '今年': {'type': 'year', 'offset': 0},
    '去年': {'type': 'year', 'offset': -1},
  };

  VoiceDrillDownService({
    VoiceDrillDownParserConfig config = const VoiceDrillDownParserConfig(),
  }) : _config = config;

  VoiceDrillDownParserConfig get config => _config;
  List<VoiceDrillDownCommand> get commandHistory => List.unmodifiable(_commandHistory);
  Map<String, dynamic> get context => Map.unmodifiable(_context);

  /// 更新配置
  void updateConfig(VoiceDrillDownParserConfig config) {
    _config = config;
  }

  /// 设置上下文
  void setContext(Map<String, dynamic> context) {
    _context = Map.from(context);
  }

  /// 更新上下文
  void updateContext(String key, dynamic value) {
    _context[key] = value;
  }

  /// 解析语音指令
  CommandParseResult parseCommand(String text) {
    if (text.trim().isEmpty) {
      return CommandParseResult.failure('请说出您的指令');
    }

    final normalizedText = _normalizeText(text);

    // 尝试匹配指令模式
    final allPatterns = [
      ..._builtInPatterns,
      ..._config.customPatterns,
    ];

    final matches = <VoiceDrillDownCommand>[];

    for (final pattern in allPatterns) {
      final match = pattern.pattern.firstMatch(normalizedText);
      if (match != null) {
        var target = pattern.targetExtractor?.call(match);
        final params = pattern.paramsExtractor?.call(match);

        // 别名转换
        if (target != null) {
          target = _resolveAlias(target, pattern.type);
        }

        final command = VoiceDrillDownCommand(
          type: pattern.type,
          target: target,
          params: params,
          rawText: text,
          confidence: _calculateConfidence(match, normalizedText),
        );

        matches.add(command);
      }
    }

    if (matches.isEmpty) {
      // 尝试模糊匹配
      if (_config.enableFuzzyMatching) {
        final fuzzyResult = _tryFuzzyMatch(normalizedText);
        if (fuzzyResult != null) {
          return CommandParseResult.success(fuzzyResult);
        }
      }
      return CommandParseResult.failure('无法理解指令，请重新说明');
    }

    if (matches.length == 1) {
      _addToHistory(matches.first);
      return CommandParseResult.success(matches.first);
    }

    // 多个匹配，按置信度排序
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));

    // 如果最高置信度明显高于其他，直接返回
    if (matches.first.confidence > 0.9 &&
        matches.first.confidence - matches[1].confidence > 0.2) {
      _addToHistory(matches.first);
      return CommandParseResult.success(matches.first);
    }

    // 返回候选项
    return CommandParseResult.ambiguous(matches.take(3).toList());
  }

  /// 规范化文本
  String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  /// 解析别名
  String _resolveAlias(String text, VoiceDrillDownCommandType type) {
    switch (type) {
      case VoiceDrillDownCommandType.drillDownCategory:
        return _categoryAliases[text] ?? text;
      case VoiceDrillDownCommandType.drillDownTime:
        // 时间别名在params中处理
        return text;
      default:
        return text;
    }
  }

  /// 计算置信度
  double _calculateConfidence(Match match, String text) {
    // 基于匹配覆盖率计算置信度
    final matchLength = match.group(0)?.length ?? 0;
    final textLength = text.length;

    if (textLength == 0) return 0;

    return (matchLength / textLength).clamp(0.0, 1.0);
  }

  /// 尝试模糊匹配
  VoiceDrillDownCommand? _tryFuzzyMatch(String text) {
    // 检查是否包含常见分类关键词
    for (final entry in _categoryAliases.entries) {
      if (text.contains(entry.key) || text.contains(entry.value)) {
        return VoiceDrillDownCommand(
          type: VoiceDrillDownCommandType.drillDownCategory,
          target: entry.value,
          rawText: text,
          confidence: _config.fuzzyMatchThreshold,
        );
      }
    }

    // 检查是否包含时间关键词
    for (final entry in _timeAliases.entries) {
      if (text.contains(entry.key)) {
        return VoiceDrillDownCommand(
          type: VoiceDrillDownCommandType.drillDownTime,
          target: entry.key,
          params: entry.value,
          rawText: text,
          confidence: _config.fuzzyMatchThreshold,
        );
      }
    }

    return null;
  }

  /// 添加到历史
  void _addToHistory(VoiceDrillDownCommand command) {
    _commandHistory.add(command);
    if (_commandHistory.length > maxHistorySize) {
      _commandHistory.removeAt(0);
    }

    // 更新上下文
    if (_config.enableContextAwareness) {
      _updateContextFromCommand(command);
    }

    notifyListeners();
  }

  /// 从命令更新上下文
  void _updateContextFromCommand(VoiceDrillDownCommand command) {
    switch (command.type) {
      case VoiceDrillDownCommandType.drillDownCategory:
        _context['currentCategory'] = command.target;
        break;
      case VoiceDrillDownCommandType.drillDownTime:
        _context['currentTime'] = command.target;
        _context['currentTimeParams'] = command.params;
        break;
      case VoiceDrillDownCommandType.drillDownMember:
        _context['currentMember'] = command.target;
        break;
      case VoiceDrillDownCommandType.drillDownLocation:
        _context['currentLocation'] = command.target;
        break;
      case VoiceDrillDownCommandType.goHome:
        _context.clear();
        break;
      default:
        break;
    }
  }

  /// 获取建议指令
  List<String> getSuggestions() {
    final suggestions = <String>[];

    // 基于当前上下文提供建议
    if (_context.isEmpty) {
      suggestions.addAll([
        '看看本月消费',
        '餐饮花了多少',
        '显示趋势图',
      ]);
    } else {
      if (_context.containsKey('currentCategory')) {
        suggestions.addAll([
          '返回上一级',
          '看看详细列表',
          '分享这个图表',
        ]);
      }
      if (_context.containsKey('currentTime')) {
        suggestions.addAll([
          '对比上个月',
          '按分类显示',
        ]);
      }
    }

    return suggestions;
  }

  /// 清除历史
  void clearHistory() {
    _commandHistory.clear();
    _context.clear();
    notifyListeners();
  }

  /// 获取最后一个命令
  VoiceDrillDownCommand? getLastCommand() {
    return _commandHistory.isNotEmpty ? _commandHistory.last : null;
  }

  /// 撤销最后一个命令
  VoiceDrillDownCommand? undoLastCommand() {
    if (_commandHistory.isEmpty) return null;

    final lastCommand = _commandHistory.removeLast();
    notifyListeners();
    return lastCommand;
  }
}

/// 语音下钻执行器
/// 负责将解析出的命令执行到可视化系统
class VoiceDrillDownExecutor {
  /// 下钻回调
  final void Function(String dimension, String target)? onDrillDown;

  /// 返回回调
  final void Function()? onGoBack;

  /// 回到首页回调
  final void Function()? onGoHome;

  /// 切换视图回调
  final void Function(String viewType)? onSwitchView;

  /// 筛选回调
  final void Function(String filter)? onFilter;

  /// 分享回调
  final void Function()? onShare;

  /// 显示详情回调
  final void Function()? onShowDetail;

  /// 比较回调
  final void Function(String first, String second)? onCompare;

  /// 查询回调
  final Future<String> Function(String query)? onQuery;

  VoiceDrillDownExecutor({
    this.onDrillDown,
    this.onGoBack,
    this.onGoHome,
    this.onSwitchView,
    this.onFilter,
    this.onShare,
    this.onShowDetail,
    this.onCompare,
    this.onQuery,
  });

  /// 执行命令
  Future<String?> execute(VoiceDrillDownCommand command) async {
    switch (command.type) {
      case VoiceDrillDownCommandType.drillDownCategory:
        onDrillDown?.call('category', command.target ?? '');
        return '正在查看${command.target}的消费详情';

      case VoiceDrillDownCommandType.drillDownTime:
        onDrillDown?.call('time', command.target ?? '');
        return '正在查看${command.target}的消费数据';

      case VoiceDrillDownCommandType.drillDownAccount:
        onDrillDown?.call('account', command.target ?? '');
        return '正在查看${command.target}账户详情';

      case VoiceDrillDownCommandType.drillDownMember:
        onDrillDown?.call('member', command.target ?? '');
        return '正在查看${command.target}的消费记录';

      case VoiceDrillDownCommandType.drillDownLocation:
        onDrillDown?.call('location', command.target ?? '');
        return '正在查看${command.target}的消费热力图';

      case VoiceDrillDownCommandType.goBack:
        onGoBack?.call();
        return '已返回上一级';

      case VoiceDrillDownCommandType.goHome:
        onGoHome?.call();
        return '已返回首页';

      case VoiceDrillDownCommandType.switchView:
        onSwitchView?.call(command.target ?? '');
        return '已切换到${command.target}视图';

      case VoiceDrillDownCommandType.filter:
        onFilter?.call(command.target ?? '');
        return '已筛选${command.target}';

      case VoiceDrillDownCommandType.share:
        onShare?.call();
        return '正在准备分享...';

      case VoiceDrillDownCommandType.showDetail:
        onShowDetail?.call();
        return '正在显示详情';

      case VoiceDrillDownCommandType.compare:
        final first = command.params?['first'] as String?;
        final second = command.params?['second'] as String?;
        if (first != null && second != null) {
          onCompare?.call(first, second);
          return '正在对比$first和$second';
        }
        return '无法识别对比项';

      case VoiceDrillDownCommandType.query:
        if (onQuery != null) {
          return await onQuery!(command.target ?? '');
        }
        return null;
    }
  }
}
