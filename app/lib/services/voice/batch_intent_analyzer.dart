import '../nlu_engine.dart';
import '../voice_service_coordinator.dart' show VoiceSessionContext;
import 'multi_intent_models.dart';
import 'voice_intent_router.dart';

/// 批量意图分析器
///
/// 并行分析多个语义片段，复用 VoiceIntentRouter 进行意图识别，
/// 返回每个片段的分析结果。
class BatchIntentAnalyzer {
  /// 语音意图路由器
  final VoiceIntentRouter _intentRouter;

  /// NLU 引擎用于实体提取
  final NLUEngine _nluEngine;

  /// 分析配置
  final BatchAnalyzerConfig config;

  BatchIntentAnalyzer({
    VoiceIntentRouter? intentRouter,
    NLUEngine? nluEngine,
    this.config = const BatchAnalyzerConfig(),
  })  : _intentRouter = intentRouter ?? VoiceIntentRouter(),
        _nluEngine = nluEngine ?? NLUEngine();

  /// 批量分析多个语义片段
  ///
  /// [segments] 分句后的语义片段列表
  /// [context] 可选的会话上下文
  ///
  /// Returns 每个片段的分析结果列表
  Future<List<SegmentAnalysis>> analyzeSegments(
    List<String> segments, {
    VoiceSessionContext? context,
  }) async {
    if (segments.isEmpty) {
      return [];
    }

    // 并行分析所有片段
    final futures = segments.map((segment) => _analyzeSegment(segment, context));
    final results = await Future.wait(futures);

    return results;
  }

  /// 分析单个语义片段
  Future<SegmentAnalysis> _analyzeSegment(
    String segment,
    VoiceSessionContext? context,
  ) async {
    try {
      // 1. 使用意图路由器分析意图
      final intentResult = await _intentRouter.analyzeIntent(
        segment,
        context: context,
      );

      // 2. 使用 NLU 引擎提取实体
      final nluResult = await _nluEngine.parse(segment);

      // 3. 提取金额
      final amount = _extractAmount(segment, intentResult, nluResult);

      // 4. 提取分类
      final category = _extractCategory(segment, intentResult, nluResult);

      // 5. 提取商家
      final merchant = _extractMerchant(segment, intentResult);

      // 6. 提取日期时间
      final dateTime = _extractDateTime(segment, nluResult);

      // 7. 判断是否为噪音
      final isNoise = _isNoise(segment, intentResult, amount);

      // 8. 计算综合置信度
      final confidence = _calculateConfidence(intentResult, nluResult, amount);

      return SegmentAnalysis(
        text: segment,
        intentResult: intentResult,
        entities: nluResult.entities,
        amount: amount,
        isNoise: isNoise,
        confidence: confidence,
        category: category,
        merchant: merchant,
        dateTime: dateTime,
      );
    } catch (e) {
      // 分析失败，返回低置信度结果
      return SegmentAnalysis(
        text: segment,
        entities: const [],
        isNoise: true,
        confidence: 0.0,
      );
    }
  }

  /// 提取金额
  ///
  /// 使用 VoiceIntentRouter.extractAmount 支持中文数字和阿拉伯数字
  double? _extractAmount(
    String text,
    IntentAnalysisResult intentResult,
    NLUResult nluResult,
  ) {
    // 优先使用意图结果中的金额（已由 VoiceIntentRouter 提取，支持中文数字）
    if (intentResult.entities.containsKey('amount')) {
      final amount = intentResult.entities['amount'];
      if (amount is double && amount > 0) {
        return amount;
      }
      if (amount is int && amount > 0) {
        return amount.toDouble();
      }
    }

    // 从 NLU 实体中提取
    for (final entity in nluResult.entities) {
      if (entity.type == EntityType.amount) {
        final parsed = double.tryParse(entity.value);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }

    // 使用 VoiceIntentRouter 的共享方法（支持中文数字）
    return VoiceIntentRouter.extractAmount(text);
  }

  /// 提取分类
  String? _extractCategory(
    String text,
    IntentAnalysisResult intentResult,
    NLUResult nluResult,
  ) {
    // 优先使用意图结果中的分类
    if (intentResult.entities.containsKey('category')) {
      return intentResult.entities['category'] as String?;
    }

    // 从 NLU 实体中提取
    for (final entity in nluResult.entities) {
      if (entity.type == EntityType.category) {
        return entity.value as String?;
      }
    }

    // 基于关键词推断分类
    return _inferCategory(text);
  }

  /// 基于关键词推断分类
  String? _inferCategory(String text) {
    final categoryKeywords = {
      '餐饮': ['吃', '餐', '饭', '菜', '喝', '咖啡', '茶', '早餐', '午餐', '晚餐', '外卖', '堂食'],
      '交通': ['打车', '地铁', '公交', '出租车', '滴滴', '油费', '加油', '停车', '车费', '火车', '飞机', '高铁'],
      '购物': ['买', '购', '商场', '淘宝', '京东', '超市', '拼多多', '商城'],
      '娱乐': ['电影', '游戏', 'ktv', '唱歌', '娱乐', '门票', '演出', '展览'],
      '医疗': ['医院', '看病', '药', '体检', '医疗', '诊所', '药店'],
      '居住': ['房租', '水电', '物业', '燃气', '宽带', '网费'],
      '通讯': ['话费', '流量', '充值', '手机'],
      '教育': ['学费', '培训', '课程', '书', '文具'],
    };

    for (final entry in categoryKeywords.entries) {
      if (entry.value.any((keyword) => text.contains(keyword))) {
        return entry.key;
      }
    }

    return null;
  }

  /// 提取商家
  String? _extractMerchant(String text, IntentAnalysisResult intentResult) {
    // 优先使用意图结果中的商家
    if (intentResult.entities.containsKey('merchant')) {
      return intentResult.entities['merchant'] as String?;
    }

    // 使用正则表达式匹配
    final patterns = [
      // 匹配 "在星巴克买"、"在肯德基吃"
      RegExp(r'在(.{2,10}?)(?:买|吃|花|消费|喝)'),
      // 匹配 "星巴克的咖啡"
      RegExp(r'(.{2,8}?)的(?:咖啡|午餐|晚餐|早餐|外卖)'),
      // 匹配 "去了麦当劳"
      RegExp(r'去了?(.{2,8}?)(?:吃|买|消费)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty) {
          return merchant;
        }
      }
    }

    return null;
  }

  /// 提取日期时间
  DateTime? _extractDateTime(String text, NLUResult nluResult) {
    // 从 NLU 实体中提取
    for (final entity in nluResult.entities) {
      if (entity.type == EntityType.date) {
        final parsed = DateTime.tryParse(entity.value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    // 基于关键词推断时间
    final now = DateTime.now();

    if (text.contains('今天')) {
      return now;
    }
    if (text.contains('昨天')) {
      return now.subtract(const Duration(days: 1));
    }
    if (text.contains('前天')) {
      return now.subtract(const Duration(days: 2));
    }
    if (text.contains('早上') || text.contains('上午')) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (text.contains('中午')) {
      return DateTime(now.year, now.month, now.day, 12, 0);
    }
    if (text.contains('下午')) {
      return DateTime(now.year, now.month, now.day, 15, 0);
    }
    if (text.contains('晚上')) {
      return DateTime(now.year, now.month, now.day, 19, 0);
    }

    return null;
  }

  /// 判断是否为噪音
  bool _isNoise(
    String text,
    IntentAnalysisResult intentResult,
    double? amount,
  ) {
    // 有金额的不是噪音
    if (amount != null && amount > 0) {
      return false;
    }

    // 导航意图不是噪音
    if (_isNavigationIntent(text)) {
      return false;
    }

    // 确认/取消意图不是噪音
    if (_isConfirmationIntent(text)) {
      return false;
    }

    // 低置信度
    if (intentResult.confidence < config.noiseThreshold) {
      return true;
    }

    // 无动作动词
    if (!_hasActionVerb(text)) {
      return true;
    }

    // 匹配状态描述模式
    if (_matchesStatePattern(text)) {
      return true;
    }

    return false;
  }

  /// 检查是否为导航意图
  bool _isNavigationIntent(String text) {
    final navKeywords = ['打开', '进入', '去', '跳转', '切换', '查看', '看看'];
    return navKeywords.any((k) => text.contains(k));
  }

  /// 检查是否为确认/取消意图
  bool _isConfirmationIntent(String text) {
    final confirmKeywords = ['确认', '取消', '是', '不', '好的', '算了', '对'];
    return confirmKeywords.any((k) => text.contains(k));
  }

  /// 检查是否有动作动词
  bool _hasActionVerb(String text) {
    final actionVerbs = [
      '花', '买', '吃', '喝', '打车', '坐', '付', '给', '收', '转',
      '消费', '支出', '收入', '存', '取', '充值', '打开', '查看',
    ];
    return actionVerbs.any((v) => text.contains(v));
  }

  /// 检查是否匹配状态描述模式
  bool _matchesStatePattern(String text) {
    final statePatterns = [
      RegExp(r'^(见了?|和|跟).*(朋友|同事|人)'),
      RegExp(r'^(去了?|到了?)[^花买吃喝付消费]+$'),
      RegExp(r'(聊了?|说了?).*(很久|一会)'),
    ];
    return statePatterns.any((p) => p.hasMatch(text));
  }

  /// 计算综合置信度
  double _calculateConfidence(
    IntentAnalysisResult intentResult,
    NLUResult nluResult,
    double? amount,
  ) {
    var confidence = intentResult.confidence;

    // 有金额加分
    if (amount != null && amount > 0) {
      confidence = (confidence + 0.2).clamp(0.0, 1.0);
    }

    // 有实体加分
    if (nluResult.entities.isNotEmpty) {
      confidence = (confidence + 0.1).clamp(0.0, 1.0);
    }

    return confidence;
  }
}

/// 批量分析器配置
class BatchAnalyzerConfig {
  /// 噪音过滤阈值
  final double noiseThreshold;

  /// 最大并行分析数量
  final int maxParallel;

  /// 单片段分析超时（毫秒）
  final int timeoutMs;

  const BatchAnalyzerConfig({
    this.noiseThreshold = 0.3,
    this.maxParallel = 10,
    this.timeoutMs = 1000,
  });
}
