import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../qwen_service.dart';
import '../voice_service_coordinator.dart' show VoiceIntentType;
import '../voice_navigation_service.dart';
import '../location_data_services.dart';
import 'voice_intent_router.dart';
import 'agent/hybrid_intent_router.dart' show NetworkStatus, RoutingMode;
import 'unified_intent_type.dart' as unified;
import 'intelligence_engine/models.dart' show RecognitionResultType;

/// 智能意图识别器
///
/// LLM优先架构，规则兜底：
///
/// ```
/// 主路径: LLM识别（优先，~1-2s）
///    ↓ 失败/超时/不可用
/// 兜底路径:
///   Layer 1: 精确规则匹配（最快，~1ms）
///      ↓ 未命中
///   Layer 2: 同义词扩展匹配（快，~5ms）
///      ↓ 未命中
///   Layer 3: 意图模板匹配（较快，~10ms）
///      ↓ 未命中
///   Layer 4: 学习缓存匹配（快，~5ms）
/// ```
class SmartIntentRecognizer {
  final VoiceIntentRouter _ruleRouter;
  final QwenService _qwenService;
  final VoiceNavigationService _navigationService;

  /// 学习缓存
  final Map<String, LearnedPattern> _learnedCache = {};

  /// 是否已加载缓存
  bool _cacheLoaded = false;

  /// 缓存的用户城市名称（APP启动时预加载）
  String _cachedCityName = '深圳';  // 默认深圳

  /// 网络状态提供者（可选）
  /// 返回null时表示网络状态未知，将允许LLM调用
  NetworkStatus? Function()? networkStatusProvider;

  /// 渐进式反馈回调（可选）
  void Function(String message)? onProgressiveFeedback;

  SmartIntentRecognizer({
    VoiceIntentRouter? ruleRouter,
    QwenService? qwenService,
    VoiceNavigationService? navigationService,
    this.networkStatusProvider,
    this.onProgressiveFeedback,
  })  : _ruleRouter = ruleRouter ?? VoiceIntentRouter(),
        _qwenService = qwenService ?? QwenService(),
        _navigationService = navigationService ?? VoiceNavigationService();

  /// 预加载用户城市信息（在APP启动时调用）
  ///
  /// 从位置服务获取当前城市，缓存起来供LLM prompt使用
  /// 这样在语音识别时就不会有延迟
  Future<void> preloadUserCity() async {
    try {
      final cityService = CityLocationService();
      final cityInfo = await cityService.getCurrentCity();
      if (cityInfo != null && cityInfo.name.isNotEmpty) {
        // 移除"市"后缀
        _cachedCityName = cityInfo.name.replaceAll('市', '');
        debugPrint('[SmartIntent] 预加载城市信息成功: $_cachedCityName');
      } else {
        debugPrint('[SmartIntent] 无法获取城市信息，使用默认值: $_cachedCityName');
      }
    } catch (e) {
      debugPrint('[SmartIntent] 预加载城市信息失败: $e，使用默认值: $_cachedCityName');
    }
  }

  /// 获取当前缓存的城市名称
  String get cachedCityName => _cachedCityName;

  /// LLM调用超时时间（毫秒）
  static const int _llmTimeoutMs = 5000; // 5秒超时，平衡响应速度和成功率

  /// 识别意图（LLM优先，规则兜底）
  Future<SmartIntentResult> recognize(
    String input, {
    String? pageContext,
  }) async {
    if (input.trim().isEmpty) {
      return SmartIntentResult.error('输入为空');
    }

    final normalizedInput = _normalize(input);
    debugPrint('[SmartIntent] 开始识别: $input');

    // ═══════════════════════════════════════════════════════════════
    // 检查网络状态，决定是否使用LLM
    // ═══════════════════════════════════════════════════════════════
    final networkStatus = networkStatusProvider?.call();
    final shouldUseLLM = networkStatus == null ||
                         networkStatus.recommendedMode != RoutingMode.ruleOnly;

    if (!shouldUseLLM) {
      debugPrint('[SmartIntent] 网络状态: 离线模式，跳过LLM直接使用规则');
      return _fallbackToRules(normalizedInput, input, pageContext);
    }

    // ═══════════════════════════════════════════════════════════════
    // 主路径: LLM识别（优先）
    // 使用标准化输入，移除ASR产生的多余标点符号
    // ═══════════════════════════════════════════════════════════════
    if (_qwenService.isAvailable) {
      debugPrint('[SmartIntent] 尝试LLM识别...');

      // 2秒后显示渐进式反馈
      Future.delayed(const Duration(milliseconds: 2000), () {
        onProgressiveFeedback?.call('正在思考...');
      });

      final llmResult = await _tryLLMWithTimeout(normalizedInput, pageContext);
      if (llmResult != null && llmResult.isSuccess && llmResult.confidence >= 0.7) {
        debugPrint('[SmartIntent] LLM识别成功: ${llmResult.intentType}, 置信度: ${llmResult.confidence}');
        // 反向学习：将LLM结果加入缓存，加速后续相似请求
        if (llmResult.confidence >= 0.85) {
          await _learnPattern(normalizedInput, llmResult);
        }
        return llmResult;
      }
      debugPrint('[SmartIntent] LLM识别失败或置信度不足，使用规则兜底');
      onProgressiveFeedback?.call('切换到快速模式');
    } else {
      debugPrint('[SmartIntent] LLM不可用（未配置API Key），使用规则兜底');
    }

    // ═══════════════════════════════════════════════════════════════
    // 兜底路径: 规则匹配
    // ═══════════════════════════════════════════════════════════════
    return _fallbackToRules(normalizedInput, input, pageContext);
  }

  /// 带超时的LLM调用
  Future<SmartIntentResult?> _tryLLMWithTimeout(
    String input,
    String? pageContext,
  ) async {
    try {
      return await _layer5LLMFallback(input, pageContext)
          .timeout(Duration(milliseconds: _llmTimeoutMs));
    } catch (e) {
      debugPrint('[SmartIntent] LLM调用超时或失败: $e');
      return null;
    }
  }

  /// 识别多操作意图（支持一次输入包含多个操作）
  Future<MultiOperationResult> recognizeMultiOperation(
    String input, {
    String? pageContext,
  }) async {
    if (input.trim().isEmpty) {
      return MultiOperationResult.error('输入为空');
    }

    final normalizedInput = _normalize(input);
    debugPrint('[SmartIntent] 开始多操作识别: $input');

    // ═══════════════════════════════════════════════════════════════
    // 检查网络状态，决定是否使用LLM
    // ═══════════════════════════════════════════════════════════════
    final networkStatus = networkStatusProvider?.call();
    debugPrint('[SmartIntent] 网络状态检查: provider=${networkStatusProvider != null}, '
        'status=${networkStatus != null ? "有" : "null"}, '
        'mode=${networkStatus?.recommendedMode}, '
        'qwenAvailable=${_qwenService.isAvailable}');

    final shouldUseLLM = _qwenService.isAvailable &&
        (networkStatus == null || networkStatus.recommendedMode != RoutingMode.ruleOnly);

    if (!shouldUseLLM) {
      final reason = !_qwenService.isAvailable
          ? '未配置API Key'
          : '网络状态: ${networkStatus?.recommendedMode}';
      debugPrint('[SmartIntent] 跳过LLM，直接使用规则兜底 ($reason)');
      return _multiOperationFallbackToRules(normalizedInput, input, pageContext);
    }

    // ═══════════════════════════════════════════════════════════════
    // 主路径: LLM识别（优先）
    // 使用标准化输入，移除ASR产生的多余标点符号
    // ═══════════════════════════════════════════════════════════════
    debugPrint('[SmartIntent] 尝试LLM多操作识别...');
    final llmResult = await _tryMultiOperationLLMWithTimeout(normalizedInput, pageContext);
    if (llmResult != null && llmResult.isSuccess) {
      // LLM成功识别（包括 operation、chat、clarify 三种情况）
      debugPrint('[SmartIntent] LLM识别成功: resultType=${llmResult.resultType}, '
          'operations=${llmResult.operations.length}, '
          'isChat=${llmResult.isChat}, '
          'needsClarify=${llmResult.needsClarify}');
      return llmResult;
    }
    debugPrint('[SmartIntent] LLM识别失败或超时，使用规则兜底');

    // ═══════════════════════════════════════════════════════════════
    // 兜底路径: 使用现有单操作识别
    // ═══════════════════════════════════════════════════════════════
    return _multiOperationFallbackToRules(normalizedInput, input, pageContext);
  }

  /// 多操作规则兜底识别
  ///
  /// 仅在离线模式下使用，当 LLM 不可用时作为兜底
  Future<MultiOperationResult> _multiOperationFallbackToRules(
    String normalizedInput,
    String originalInput,
    String? pageContext,
  ) async {
    debugPrint('[SmartIntent] 使用规则兜底识别（离线模式）...');
    final singleResult = await _fallbackToRules(normalizedInput, originalInput, pageContext);

    if (singleResult.isSuccess) {
      debugPrint('[SmartIntent] 规则识别成功: ${singleResult.intentType}');
      return MultiOperationResult(
        resultType: RecognitionResultType.operation,
        operations: [_convertToOperation(singleResult)],
        chatContent: null,
        confidence: singleResult.confidence,
        source: singleResult.source,
        originalInput: originalInput,
        isOfflineMode: true,  // 标识为离线模式
      );
    }

    // 规则也无法识别，返回 chat 类型并提示离线模式
    // 避免返回 failed 导致用户看到错误信息
    debugPrint('[SmartIntent] 规则无法识别，返回 chat 类型（离线模式）');
    return MultiOperationResult(
      resultType: RecognitionResultType.chat,
      operations: [],
      chatContent: originalInput,
      confidence: 0.5,
      source: RecognitionSource.error,
      originalInput: originalInput,
      isOfflineMode: true,  // 标识为离线模式
    );
  }

  /// 带超时的多操作LLM调用
  Future<MultiOperationResult?> _tryMultiOperationLLMWithTimeout(
    String input,
    String? pageContext,
  ) async {
    try {
      return await _multiOperationLLMRecognition(input, pageContext)
          .timeout(Duration(milliseconds: _llmTimeoutMs));
    } catch (e) {
      debugPrint('[SmartIntent] 多操作LLM调用超时或失败: $e');
      return null;
    }
  }

  /// 多操作LLM识别
  Future<MultiOperationResult?> _multiOperationLLMRecognition(
    String input,
    String? pageContext,
  ) async {
    try {
      final prompt = _buildMultiOperationLLMPrompt(input, pageContext);
      debugPrint('[SmartIntent] LLM输入: $input');
      final response = await _qwenService.chat(prompt);

      if (response == null || response.isEmpty) {
        debugPrint('[SmartIntent] LLM返回为空');
        return null;
      }

      debugPrint('[SmartIntent] LLM原始返回: $response');
      return _parseMultiOperationLLMResponse(response, input);
    } catch (e) {
      debugPrint('[SmartIntent] 多操作LLM调用失败: $e');
      return null;
    }
  }

  /// 构建多操作LLM Prompt
  String _buildMultiOperationLLMPrompt(String input, String? pageContext) {
    final highAdaptPages = _navigationService.highAdaptationPages;
    final pageList = highAdaptPages
        .take(30)
        .map((p) => '${p.name}(${p.route})')
        .join('、');

    return '''
你是一个记账助手，请理解用户输入并返回JSON。

【核心规则 - 必须严格遵守】
1. 记账(add_transaction)必须同时满足两个条件：
   ✅ 有明确的数字金额（如"35"、"五十"、"三块五"）
   ✅ 有分类或用途说明（如"餐饮"、"打车"、"买东西"）
   ❌ 只有金额没有分类 → clarify
   ❌ 只有分类没有金额 → clarify
   ❌ 两者都没有 → clarify

2. 【重要】单独的分类名称不是有效记账指令：
   - 用户只说"餐饮"、"交通"、"购物"、"娱乐"、"居住"、"医疗"、"其他"等分类名称
   - 没有金额，不能生成add_transaction
   - result_type为"clarify"
   - 澄清话术：请说完整的记账指令，比如"{分类}50元"或"{分类}消费100"

3. 【重要】单独的金额不是有效记账指令：
   - 用户只说"30元"、"五十块"、"100"等金额
   - 没有分类或用途，不能生成add_transaction
   - result_type为"clarify"
   - 澄清话术：请说明这笔{金额}是什么类型的消费，比如"餐饮"或"交通"

4. 闲聊、提问、询问功能等不包含操作意图的内容，result_type为"chat"

5. 用户表达模糊、信息不足时，主动反问澄清而不是猜测

6. 【重要】疑问句优先判断为查询：
   - "花了多少钱"、"多少钱"、"花了多少"等疑问句 → query（查询统计）
   - "花了35块"等陈述句+金额 → add_transaction（记账）
   - 区分方法：有"？"或"多少"且无具体金额 = 查询；有具体金额 = 记账

7. 【重要】跨句子语义关联：
   - 用户可能先说金额后补充用途，或先说用途后补充金额，这都属于同一笔交易
   - 模式A - 先金额后用途：
     - "花了15块钱吃了肠粉" → 15元餐饮（肠粉）
     - "中午花了30吃了外卖" → 30元餐饮（午餐外卖）
   - 模式B - 先用途后金额（常见于口语，中间可能有停顿词"呃"、"是"、"大概"等）：
     - "今天的午餐是25块" → 25元餐饮（午餐）
     - "今天的午餐呃是大概25块钱" → 25元餐饮（午餐）
     - "还有今天的午餐大概是25块钱" → 25元餐饮（午餐）
     - "早餐呃七块" → 7元餐饮（早餐）
   - 必须综合分析整个输入的上下文，将相关联的金额和用途正确配对
   - 关键：识别"早餐/午餐/晚餐/打车/买菜"等用途词，并与后面的金额关联
   - 忽略停顿词：用户口语中的"呃"、"嗯"、"是"、"大概是"等不影响语义理解

8. 【重要】多笔交易完整性检查：
   - 用户可能一次说多笔交易，如"早餐7块午餐18晚餐25"
   - 必须逐一检查每个金额，确保都生成对应的add_transaction
   - 连接词"然后"、"还有"、"另外"表示新的一笔交易
   - 时间词"早上/中午/晚上"、"早餐/午餐/晚餐"表示不同的交易
   - 检查方法：统计输入中的金额数量，输出的operations数量应该匹配
   - 例如："早餐7块然后午餐18然后晚上25" → 3笔交易（7元、18元、25元）

【用户输入】$input
【页面上下文】${pageContext ?? '首页'}

【结果类型 result_type】
- operation: 有明确操作意图，可以执行
- chat: 闲聊/提问/无需操作
- clarify: 意图模糊，需要反问用户获取更多信息

【操作类型】
- add_transaction: 记账（必须有明确数字金额）
- navigate: 导航（打开某页面）
- query: 查询统计（用户明确要查数据）
- modify: 修改记录
- delete: 删除记录

【查询类型 queryType】
- summary: 总额统计（"今天花了多少"、"本月支出"）
- recent: 最近记录（"最近的账单"、"最近10笔"）
- trend: 趋势分析（"最近三个月的消费趋势"、"每月支出变化"）
- distribution: 分布查询（"各分类占比"、"餐饮这个月花了多少"）
- comparison: 对比查询（"本月和上月对比"、"今年和去年对比"）

【分组维度 groupBy】
- month: 按月份分组（"每月"、"按月"）
- date: 按日期分组（"每天"、"按日"）
- category: 按分类分组（"各分类"、"按分类"）

【优先级】
- immediate: 导航
- normal: 查询
- deferred: 记账

【返回格式】
{"result_type":"operation|chat|clarify","operations":[],"chat_content":"对话内容或null","clarify_question":"澄清问题或null"}

【记账参数说明】
- amount: 金额（必填）
- category: 分类（必填）
- merchant: 商户名称（可选，如"深圳地铁"、"美团外卖"、"星巴克"等）
- note: 用途说明（可选，简洁描述，如"去程"、"返程"、"午餐"等）

【商户和备注提取规则】
- 用户所在城市：$_cachedCityName（用于推断本地商户名称）
- 地铁/公交：商户填"城市名+交通方式"（如"$_cachedCityName地铁"、"$_cachedCityName公交"）
- 外卖平台：商户填平台名（如"美团外卖"、"饿了么"）
- 网购：商户填平台（如"淘宝"、"京东"）
- 打车：商户填平台（如"滴滴出行"）

【备注提取原则 - 记录有意义的内容】
- 保留具体信息：用户说的具体物品、地点、用途都要保留
  - "吃了肠粉" → note="肠粉"（保留具体食物）
  - "从福田到南山" → note="福田到南山"（保留路线）
  - "买了个闹钟" → note="闹钟"（保留具体商品）
- 去除口语填充词：移除"呃"、"嗯"、"大概是"、"今天的"等无意义词
- 合理规范化：
  - "去的时候" / "回来的时候" → "去程" / "返程"
  - "上班" / "下班" → "通勤-上班" / "通勤-下班"
- 不要过度简化：保留用户表达的关键语义，让记录具有回溯价值

【查询参数说明】
- queryType: 查询类型（summary/recent/trend/distribution/comparison）
- time: 时间范围（今天/昨天/本周/本月/上月/最近N天/最近N个月）
- category: 分类筛选（可选）
- groupBy: 分组维度（可选，month/date/category）
- limit: 结果数量限制（可选，当用户问"最多的一项"、"最少的一项"、"前N项"时使用）

【分类】餐饮、交通、购物、娱乐、居住、医疗、其他
【常用页面】$pageList

【导航操作参数】
- targetPage: 目标页面名称（如"交易列表"、"统计"等）
- route: 目标路由（可选，如"/transaction-list"）
- category: 分类筛选（餐饮/交通/购物/娱乐/居住/医疗/其他）
- timeRange: 时间范围（今天/昨天/本周/本月/上月）
- source: 来源筛选（支付宝/微信/银行卡等）
- account: 账户筛选

【示例】
输入："打车35，吃饭50"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":35,"category":"交通","note":"打车"}},{"type":"add_transaction","priority":"deferred","params":{"amount":50,"category":"餐饮","note":"吃饭"}}],"chat_content":null,"clarify_question":null}

输入："早餐七块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":7,"category":"餐饮","note":"早餐"}}],"chat_content":null,"clarify_question":null}

输入："午餐十五，晚餐二十"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":15,"category":"餐饮","note":"午餐"}},{"type":"add_transaction","priority":"deferred","params":{"amount":20,"category":"餐饮","note":"晚餐"}}],"chat_content":null,"clarify_question":null}

输入："花了15块钱吃了肠粉"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":15,"category":"餐饮","note":"肠粉"}}],"chat_content":null,"clarify_question":null}

输入："中午花了30吃了外卖"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":30,"category":"餐饮","note":"午餐外卖"}}],"chat_content":null,"clarify_question":null}

输入："今天早餐吃了七块然后中午又花了15块钱吃了一碗肠粉"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":7,"category":"餐饮","note":"早餐"}},{"type":"add_transaction","priority":"deferred","params":{"amount":15,"category":"餐饮","note":"肠粉"}}],"chat_content":null,"clarify_question":null}

输入："早上花了10块买了包子晚上又花了25吃了米粉"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":10,"category":"餐饮","note":"包子"}},{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","note":"米粉"}}],"chat_content":null,"clarify_question":null}

输入："今天早餐花了7块吃了肠粉然后午餐花了18块吃了蛋包饭然后晚上吃云吞面嗯25"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":7,"category":"餐饮","note":"肠粉"}},{"type":"add_transaction","priority":"deferred","params":{"amount":18,"category":"餐饮","note":"蛋包饭"}},{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","note":"云吞面"}}],"chat_content":null,"clarify_question":null}

输入："早餐7块午餐18块晚餐25"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":7,"category":"餐饮","note":"早餐"}},{"type":"add_transaction","priority":"deferred","params":{"amount":18,"category":"餐饮","note":"午餐"}},{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","note":"晚餐"}}],"chat_content":null,"clarify_question":null}

输入："今天的午餐呃是大概25块钱"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","note":"午餐"}}],"chat_content":null,"clarify_question":null}

输入："早餐呃七块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":7,"category":"餐饮","note":"早餐"}}],"chat_content":null,"clarify_question":null}

输入："还有今天的午餐大概是25块钱"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","note":"午餐"}}],"chat_content":null,"clarify_question":null}

输入："晚餐是35"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":35,"category":"餐饮","note":"晚餐"}}],"chat_content":null,"clarify_question":null}

输入："今天打车呃花了20块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":20,"category":"交通","merchant":"滴滴出行","note":"打车"}}],"chat_content":null,"clarify_question":null}

输入："今天地铁去的时候三块回来的时候也是三块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":3,"category":"交通","merchant":"$_cachedCityName地铁","note":"去程"}},{"type":"add_transaction","priority":"deferred","params":{"amount":3,"category":"交通","merchant":"$_cachedCityName地铁","note":"返程"}}],"chat_content":null,"clarify_question":null}

输入："上班地铁3块下班也是3块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":3,"category":"交通","merchant":"$_cachedCityName地铁","note":"通勤-上班"}},{"type":"add_transaction","priority":"deferred","params":{"amount":3,"category":"交通","merchant":"$_cachedCityName地铁","note":"通勤-下班"}}],"chat_content":null,"clarify_question":null}

输入："地铁从福田到南山5块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":5,"category":"交通","merchant":"$_cachedCityName地铁","note":"福田到南山"}}],"chat_content":null,"clarify_question":null}

输入："坐地铁花了5块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":5,"category":"交通","merchant":"$_cachedCityName地铁","note":"地铁"}}],"chat_content":null,"clarify_question":null}

输入："公交2块去见客户"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":2,"category":"交通","merchant":"$_cachedCityName公交","note":"见客户"}}],"chat_content":null,"clarify_question":null}

输入："美团外卖25块"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":25,"category":"餐饮","merchant":"美团外卖","note":"外卖"}}],"chat_content":null,"clarify_question":null}

输入："买了个闹钟11块，柜子200，桌子300"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":11,"category":"购物","note":"闹钟"}},{"type":"add_transaction","priority":"deferred","params":{"amount":200,"category":"购物","note":"柜子"}},{"type":"add_transaction","priority":"deferred","params":{"amount":300,"category":"购物","note":"桌子"}}],"chat_content":null,"clarify_question":null}

输入："淘宝买了件衣服199"
输出：{"result_type":"operation","operations":[{"type":"add_transaction","priority":"deferred","params":{"amount":199,"category":"购物","note":"淘宝买衣服"}}],"chat_content":null,"clarify_question":null}

输入："为什么要记账"
输出：{"result_type":"chat","operations":[],"chat_content":"为什么要记账","clarify_question":null}

输入："你会记账吗"
输出：{"result_type":"chat","operations":[],"chat_content":"你会记账吗","clarify_question":null}

输入："帮我记笔账"
输出：{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"好的，请告诉我金额和用途，比如：午餐花了35块"}

输入："记一下"
输出：{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请问要记录什么呢？可以说具体金额和用途"}

输入："买了个东西"
输出：{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请问花了多少钱呢？"}

输入："其他"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说完整的记账指令，比如：其他50元"}

输入："餐饮"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说完整的记账指令，比如：餐饮50元"}

输入："交通"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说完整的记账指令，比如：交通50元"}

输入："30元"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说明这笔30元是什么类型的消费，比如餐饮或交通"}

输入："五十块"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说明这笔50元是什么类型的消费，比如餐饮或交通"}

输入："100"
输出:{"result_type":"clarify","operations":[],"chat_content":null,"clarify_question":"请说明这笔100元是什么类型的消费，比如餐饮或交通"}


输入："查一下昨天花了多少"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"statistics","time":"昨天"}}],"chat_content":null,"clarify_question":null}

输入："今天花了多少钱"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"statistics","time":"今天"}}],"chat_content":null,"clarify_question":null}

输入："我这个月花了多少"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"statistics","time":"本月"}}],"chat_content":null,"clarify_question":null}

输入："最近一周花了多少"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"statistics","time":"本周"}}],"chat_content":null,"clarify_question":null}

输入："你好"
输出：{"result_type":"chat","operations":[],"chat_content":"你好","clarify_question":null}

输入："查看餐饮类的账单"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"交易列表","route":"/transaction-list","category":"餐饮"}}],"chat_content":null,"clarify_question":null}

输入："看看本周的交通消费"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"统计","route":"/statistics","category":"交通","timeRange":"本周"}}],"chat_content":null,"clarify_question":null}

输入："查看支付宝的支出"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"交易列表","route":"/transaction-list","source":"支付宝"}}],"chat_content":null,"clarify_question":null}

输入："打开本月的购物记录"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"交易列表","route":"/transaction-list","category":"购物","timeRange":"本月"}}],"chat_content":null,"clarify_question":null}

输入："看看昨天的账单"
输出：{"result_type":"operation","operations":[{"type":"navigate","priority":"immediate","params":{"targetPage":"交易列表","route":"/transaction-list","timeRange":"昨天"}}],"chat_content":null,"clarify_question":null}

输入："最近三个月的消费趋势"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"trend","time":"最近3个月","groupBy":"month"}}],"chat_content":null,"clarify_question":null}

输入："各分类占比"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"distribution","time":"本月","groupBy":"category"}}],"chat_content":null,"clarify_question":null}

输入："这个月花钱最多的是哪一项"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"distribution","time":"本月","groupBy":"category","limit":1}}],"chat_content":null,"clarify_question":null}

输入："餐饮这个月花了多少"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"distribution","time":"本月","category":"餐饮"}}],"chat_content":null,"clarify_question":null}

输入："本月和上月对比"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"comparison","time":"本月"}}],"chat_content":null,"clarify_question":null}

输入："每月支出变化"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"trend","time":"今年","groupBy":"month"}}],"chat_content":null,"clarify_question":null}

输入："最近一周每天花了多少"
输出：{"result_type":"operation","operations":[{"type":"query","priority":"normal","params":{"queryType":"trend","time":"本周","groupBy":"date"}}],"chat_content":null,"clarify_question":null}

只返回JSON：''';
  }

  /// 解析多操作LLM响应
  ///
  /// 根据 result_type 返回不同类型的 MultiOperationResult：
  /// - operation: 有操作意图，使用 withOperations
  /// - chat: 闲聊/提问，使用 chat
  /// - clarify: 需要澄清，使用 clarify
  MultiOperationResult? _parseMultiOperationLLMResponse(String response, String originalInput) {
    try {
      final jsonStr = _extractJson(response);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final resultType = json['result_type'] as String? ?? 'operation';
      final operationsJson = json['operations'] as List<dynamic>? ?? [];
      final chatContent = json['chat_content'] as String?;
      final clarifyQuestion = json['clarify_question'] as String?;

      debugPrint('[SmartIntent] LLM返回: result_type=$resultType, '
          'operations=${operationsJson.length}, '
          'chatContent=${chatContent != null ? "有" : "无"}, '
          'clarifyQuestion=${clarifyQuestion != null ? "有" : "无"}');

      // 根据 result_type 返回不同类型的结果
      switch (resultType) {
        case 'chat':
          // 闲聊模式：无需操作，返回 chat 类型结果
          return MultiOperationResult.chat(
            chatContent: chatContent ?? originalInput,
            source: RecognitionSource.llmFallback,
            originalInput: originalInput,
          );

        case 'clarify':
          // 澄清模式：需要反问用户
          return MultiOperationResult.clarify(
            clarifyQuestion: clarifyQuestion ?? '请问您具体想要做什么呢？',
            source: RecognitionSource.llmFallback,
            originalInput: originalInput,
          );

        case 'operation':
        default:
          // 操作模式：解析操作列表
          final operations = <Operation>[];
          for (final opJson in operationsJson) {
            final opMap = opJson as Map<String, dynamic>;
            final type = opMap['type'] as String? ?? 'unknown';
            final priority = opMap['priority'] as String? ?? 'normal';
            final params = opMap['params'] as Map<String, dynamic>? ?? {};

            debugPrint('[SmartIntent] 解析操作: type=$type, params=$params');

            operations.add(Operation(
              type: _parseOperationType(type),
              priority: _parseOperationPriority(priority),
              params: params,
              originalText: originalInput,
            ));
          }

          // 如果 result_type 是 operation 但没有操作，降级为 chat
          if (operations.isEmpty) {
            debugPrint('[SmartIntent] result_type=operation 但无操作，降级为 chat');
            return MultiOperationResult.chat(
              chatContent: chatContent ?? originalInput,
              source: RecognitionSource.llmFallback,
              originalInput: originalInput,
            );
          }

          return MultiOperationResult.withOperations(
            operations: operations,
            chatContent: chatContent,
            confidence: 0.9,
            source: RecognitionSource.llmFallback,
            originalInput: originalInput,
          );
      }
    } catch (e) {
      debugPrint('[SmartIntent] 解析多操作LLM响应失败: $e');
      return null;
    }
  }

  /// 将SmartIntentResult转换为Operation
  Operation _convertToOperation(SmartIntentResult result) {
    return Operation(
      type: _mapSmartIntentToOperationType(result.intentType),
      priority: _inferOperationPriority(result.intentType),
      params: result.entities,
      originalText: result.originalInput,
    );
  }

  /// 映射SmartIntentType到OperationType
  OperationType _mapSmartIntentToOperationType(SmartIntentType type) {
    switch (type) {
      case SmartIntentType.addTransaction:
        return OperationType.addTransaction;
      case SmartIntentType.navigate:
        return OperationType.navigate;
      case SmartIntentType.query:
        return OperationType.query;
      case SmartIntentType.modify:
        return OperationType.modify;
      case SmartIntentType.delete:
        return OperationType.delete;
      default:
        return OperationType.unknown;
    }
  }

  /// 推断操作优先级
  OperationPriority _inferOperationPriority(SmartIntentType type) {
    switch (type) {
      case SmartIntentType.navigate:
        return OperationPriority.immediate;
      case SmartIntentType.query:
        return OperationPriority.normal;
      case SmartIntentType.addTransaction:
      case SmartIntentType.modify:
      case SmartIntentType.delete:
        return OperationPriority.deferred;
      default:
        return OperationPriority.normal;
    }
  }

  /// 解析操作类型字符串
  OperationType _parseOperationType(String type) {
    switch (type.toLowerCase()) {
      case 'add_transaction':
        return OperationType.addTransaction;
      case 'navigate':
        return OperationType.navigate;
      case 'query':
        return OperationType.query;
      case 'modify':
        return OperationType.modify;
      case 'delete':
        return OperationType.delete;
      default:
        return OperationType.unknown;
    }
  }

  /// 解析操作优先级字符串
  OperationPriority _parseOperationPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'immediate':
        return OperationPriority.immediate;
      case 'normal':
        return OperationPriority.normal;
      case 'deferred':
        return OperationPriority.deferred;
      case 'background':
        return OperationPriority.background;
      default:
        return OperationPriority.normal;
    }
  }

  /// 规则兜底识别
  Future<SmartIntentResult> _fallbackToRules(
    String normalizedInput,
    String originalInput,
    String? pageContext,
  ) async {
    SmartIntentResult? result;

    // Layer 1: 精确规则匹配
    result = await _layer1ExactRule(normalizedInput);
    if (result != null && result.confidence >= 0.8) {
      debugPrint('[SmartIntent] 规则Layer1命中: ${result.intentType}');
      return result;
    }

    // Layer 2: 同义词扩展匹配
    result = await _layer2SynonymExpansion(normalizedInput);
    if (result != null && result.confidence >= 0.75) {
      debugPrint('[SmartIntent] 规则Layer2命中: ${result.intentType}');
      return result;
    }

    // Layer 3: 意图模板匹配
    result = await _layer3TemplateMatch(normalizedInput);
    if (result != null && result.confidence >= 0.7) {
      debugPrint('[SmartIntent] 规则Layer3命中: ${result.intentType}');
      return result;
    }

    // Layer 4: 学习缓存匹配
    result = await _layer4LearnedCache(normalizedInput);
    if (result != null && result.confidence >= 0.85) {
      debugPrint('[SmartIntent] 规则Layer4命中: ${result.intentType}');
      return result;
    }

    return SmartIntentResult.error('无法理解您的指令');
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer 1: 精确规则匹配
  // ═══════════════════════════════════════════════════════════════

  Future<SmartIntentResult?> _layer1ExactRule(String input) async {
    try {
      final result = await _ruleRouter.analyzeIntent(input);
      if (result.intent != VoiceIntentType.unknown) {
        return SmartIntentResult(
          intentType: _mapIntentType(result.intent),
          confidence: result.confidence,
          entities: _extractEntities(result),
          source: RecognitionSource.exactRule,
          originalInput: input,
        );
      }
    } catch (e) {
      debugPrint('[SmartIntent] Layer1异常: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer 2: 同义词扩展匹配
  // ═══════════════════════════════════════════════════════════════

  /// 导航动词同义词组
  static const _navigationSynonyms = {
    '打开': ['打开', '进入', '跳转', '去', '看看', '查看', '帮我打开', '想看', '想去', '进行'],
    '管理': ['管理', '设置', '配置', '调整', '修改'],
  };

  /// 导航目标同义词组
  static const _targetSynonyms = {
    '设置': ['设置', '配置', '系统设置', '设置页', '配置页', '设置界面', '配置界面'],
    '账本': ['账本', '账户', '账户管理', '账本管理', '我的账户', '账户列表'],
    '预算': ['预算', '预算管理', '预算设置', '月度预算'],
    '统计': ['统计', '报表', '分析', '统计报表', '消费统计', '支出统计'],
    '首页': ['首页', '主页', '主界面', '回到首页'],
    '分类': ['分类', '分类管理', '类别', '消费分类'],
    '钱龄': ['钱龄', '钱龄分析', '资金分析'],
    '储蓄': ['储蓄', '小金库', '存钱', '储蓄目标'],
  };

  /// 记账动词同义词组
  static const _addSynonyms = {
    '花了': ['花了', '花', '消费', '支出', '付了', '付', '买了', '买', '用了', '支付'],
    '收入': ['收入', '赚了', '进账', '收到', '工资', '奖金', '入账', '捡到', '捡了', '找到钱', '中奖', '返现', '退款'],
  };

  Future<SmartIntentResult?> _layer2SynonymExpansion(String input) async {
    // 检查导航意图
    final navResult = _checkNavigationWithSynonyms(input);
    if (navResult != null) {
      return navResult;
    }

    // 检查记账意图（用同义词扩展）
    final addResult = _checkAddWithSynonyms(input);
    if (addResult != null) {
      return addResult;
    }

    return null;
  }

  SmartIntentResult? _checkNavigationWithSynonyms(String input) {
    // ═══════════════════════════════════════════════════════════════
    // 先检查是否有导航意图（必须有导航动词才进行导航识别）
    // 避免"你好"等闲聊被误识别为导航
    // ═══════════════════════════════════════════════════════════════
    bool hasNavVerb = false;
    for (final synonyms in _navigationSynonyms.values) {
      if (synonyms.any((s) => input.contains(s))) {
        hasNavVerb = true;
        break;
      }
    }

    if (!hasNavVerb) {
      // 特殊情况：直接说目标+管理，如"账本管理"
      for (final entry in _targetSynonyms.entries) {
        for (final synonym in entry.value) {
          if (input.contains(synonym)) {
            // 检查是否有"管理"类词汇
            if (_navigationSynonyms['管理']!.any((s) => input.contains(s))) {
              hasNavVerb = true;
              break;
            }
          }
        }
        if (hasNavVerb) break;
      }
    }

    // 没有导航动词，不进行导航识别
    if (!hasNavVerb) return null;

    // ═══════════════════════════════════════════════════════════════
    // 有导航意图，使用 VoiceNavigationService 进行页面匹配
    // ═══════════════════════════════════════════════════════════════
    final navResult = _navigationService.parseNavigation(input);

    if (navResult.success && navResult.config != null) {
      final config = navResult.config!;

      // 根据匹配置信度调整结果置信度
      // VoiceNavigationService 返回的模糊匹配置信度为 0.7，精确匹配为 1.0
      final confidence = navResult.confidence >= 0.9 ? 0.9 : 0.8;

      return SmartIntentResult(
        intentType: SmartIntentType.navigate,
        confidence: confidence,
        entities: {
          'targetPage': config.name,
          'route': config.route,
          'module': config.module,
        },
        source: RecognitionSource.synonymExpansion,
        originalInput: input,
      );
    }

    // 检查目标页面（本地同义词作为兜底）
    for (final entry in _targetSynonyms.entries) {
      final targetKey = entry.key;
      final synonyms = entry.value;

      if (synonyms.any((s) => input.contains(s))) {
        return SmartIntentResult(
          intentType: SmartIntentType.navigate,
          confidence: 0.85,
          entities: {'targetPage': targetKey},
          source: RecognitionSource.synonymExpansion,
          originalInput: input,
        );
      }
    }

    return null;
  }

  SmartIntentResult? _checkAddWithSynonyms(String input) {
    // 检查是否有金额
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)|([一二三四五六七八九十百千万两]+)').firstMatch(input);
    if (amountMatch == null) return null;

    // 检查是否有消费/收入动词
    bool isExpense = false;
    bool isIncome = false;

    for (final synonym in _addSynonyms['花了']!) {
      if (input.contains(synonym)) {
        isExpense = true;
        break;
      }
    }

    for (final synonym in _addSynonyms['收入']!) {
      if (input.contains(synonym)) {
        isIncome = true;
        break;
      }
    }

    if (!isExpense && !isIncome) {
      // 如果有金额但没有明确动词，默认当作支出
      isExpense = true;
    }

    // 提取金额
    double? amount;
    final arabicMatch = RegExp(r'\d+(?:\.\d+)?').firstMatch(input);
    if (arabicMatch != null) {
      amount = double.tryParse(arabicMatch.group(0)!);
    } else {
      amount = _parseChineseNumber(input);
    }

    if (amount == null) return null;

    // 推断分类
    final category = _inferCategory(input);

    // 提取物品/用途说明
    final note = _extractItemNote(input, category);

    return SmartIntentResult(
      intentType: SmartIntentType.addTransaction,
      confidence: 0.8,
      entities: {
        'amount': amount,
        'category': category,
        'type': isIncome ? 'income' : 'expense',
        if (note != null) 'note': note,
      },
      source: RecognitionSource.synonymExpansion,
      originalInput: input,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer 3: 意图模板匹配
  // ═══════════════════════════════════════════════════════════════

  /// 意图模板定义
  /// 使用 {slot} 表示槽位，{slot?} 表示可选槽位
  static const _intentTemplates = <SmartIntentType, List<String>>{
    SmartIntentType.addTransaction: [
      '{time?}{item}{verb?}{amount}{unit?}',      // 午餐花了35块
      '{amount}{unit?}{的?}{item}',                // 35块的午餐
      '{item}{amount}{unit?}',                     // 午餐35
      '{verb}{amount}{unit?}{item?}',             // 花了35块吃饭
      '{time?}{verb}{amount}{unit?}{prep?}{item}', // 今天花了35块买菜
    ],
    SmartIntentType.navigate: [
      '{navVerb}{target}',                         // 打开设置
      '{想}{navVerb?}{target}',                    // 想看账本
      '{target}{管理}',                            // 账本管理
      '{帮我}{navVerb}{target}',                   // 帮我打开预算
      '{想}{进行}{target}{管理?}',                 // 想进行账本管理
    ],
    SmartIntentType.query: [
      '{time?}{verb?}多少{钱?}',                   // 这个月花了多少
      '查{看?}{time?}{的?}{category?}{统计?}',    // 查看本月餐饮统计
      '{time?}{category?}{消费|支出}{情况?}',     // 本月餐饮消费情况
    ],
    SmartIntentType.modify: [
      '{那笔|上一笔|刚才的}{改成|改为}{value}',   // 那笔改成50
      '{改}{category|amount}',                    // 改成交通
      '{不对}{是}{value}',                        // 不对，是50
    ],
    SmartIntentType.delete: [
      '{删除|删掉|去掉}{那笔|上一笔|这笔}',       // 删掉那笔
      '{不要了|取消}{那笔?}',                     // 不要了
    ],
    SmartIntentType.config: [
      '{开启|打开|启用|关闭|禁用}{configItem}',   // 开启零基预算
      '{configItem}{设置|调|改}{为?}{value}',     // 分类置信度阈值调到80%
      '{设置}{configItem}{为?}{value}',           // 设置预算结转上限500
    ],
    SmartIntentType.moneyAge: [
      '{查看|看看}{我的?}钱龄',                   // 查看钱龄
      '钱龄{分析|报告|情况}',                     // 钱龄分析
      '{我的?}资金{健康|健康度}',                 // 我的资金健康度
      '查看{资金池|FIFO}',                        // 查看资金池
      '钱龄{优化|提升}{建议}',                    // 钱龄优化建议
    ],
    SmartIntentType.habit: [
      '{打卡|签到}{今日?}',                       // 打卡
      '{今日|今天}打卡',                          // 今日打卡
      '{查看|看看}{挑战|挑战进度}',               // 查看挑战进度
      '{兑换|使用}{奖励|积分}',                   // 兑换奖励
      '{查看|我有}多少积分',                      // 查看积分
      '{开始|发起}{省钱|记账}挑战',               // 开始省钱挑战
    ],
    SmartIntentType.vault: [
      '{分配|存入}{amount}{到|进}{vaultName}',    // 分配1000到旅游
      '{vaultName}{还有|余额|剩余}多少',          // 旅游小金库还有多少
      '{各|所有}小金库{余额|情况}',               // 各小金库余额
      '{从}{vaultName}{取|取出}{amount}',         // 从旅游取出500
      '{把|将}{vaultName}的{amount}调到{target}', // 把餐饮的200调到购物
    ],
    SmartIntentType.dataOp: [
      '{立即|马上}备份',                          // 立即备份
      '备份{到|数据}{云端?}',                     // 备份到云端
      '{导出|下载}{time?}数据',                   // 导出本月数据
      '导出{年度|月度}报告',                      // 导出年度报告
      '{同步|刷新}数据',                          // 同步数据
      '强制{同步|刷新}',                          // 强制刷新
    ],
    SmartIntentType.share: [
      '{分享|发送}{月报|周报|年报}',              // 分享月报
      '{生成|创建}年度总结',                      // 生成年度总结
      '{邀请|分享给}好友',                        // 邀请好友
      '{生成|创建}邀请{链接|码}',                 // 生成邀请链接
    ],
    SmartIntentType.systemOp: [
      '{检查|有没有}更新',                        // 检查更新
      '{当前|查看}版本',                          // 当前版本
      '{提交|写}反馈',                            // 提交反馈
      '{联系|找}客服',                            // 联系客服
      '{清理|清除}缓存',                          // 清理缓存
      '{释放|节省}空间',                          // 释放空间
    ],
  };

  Future<SmartIntentResult?> _layer3TemplateMatch(String input) async {
    for (final entry in _intentTemplates.entries) {
      final intentType = entry.key;
      final templates = entry.value;

      for (final template in templates) {
        final matchResult = _matchTemplate(input, template);
        if (matchResult != null && matchResult['confidence'] >= 0.7) {
          return SmartIntentResult(
            intentType: intentType,
            confidence: matchResult['confidence'] as double,
            entities: matchResult['entities'] as Map<String, dynamic>,
            source: RecognitionSource.templateMatch,
            originalInput: input,
          );
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _matchTemplate(String input, String template) {
    // 简化的模板匹配逻辑
    // 将模板转换为关键词检查

    final entities = <String, dynamic>{};
    double confidence = 0.5;

    // 导航模板特殊处理 - 使用 VoiceNavigationService 的 237 页面配置
    if (template.contains('{navVerb}') || template.contains('{target}')) {
      final hasNavVerb = _navigationSynonyms.values
          .any((synonyms) => synonyms.any((s) => input.contains(s)));

      // 使用 VoiceNavigationService 进行页面匹配
      final navResult = _navigationService.parseNavigation(input);
      if (navResult.success && navResult.config != null) {
        final config = navResult.config!;
        entities['targetPage'] = config.name;
        entities['route'] = config.route;
        entities['module'] = config.module;
        confidence = hasNavVerb ? 0.85 : 0.75;
        return {'confidence': confidence, 'entities': entities};
      }

      // 兜底：使用本地同义词
      String? targetPage;
      for (final entry in _targetSynonyms.entries) {
        if (entry.value.any((s) => input.contains(s))) {
          targetPage = entry.key;
          break;
        }
      }

      if (targetPage != null) {
        entities['targetPage'] = targetPage;
        confidence = hasNavVerb ? 0.85 : 0.75;
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 记账模板特殊处理
    if (template.contains('{amount}')) {
      final amount = _extractAmount(input);
      if (amount != null) {
        final category = _inferCategory(input);
        entities['amount'] = amount;
        entities['category'] = category;
        // 提取物品/用途说明
        final note = _extractItemNote(input, category);
        if (note != null) {
          entities['note'] = note;
        }
        confidence = 0.75;
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 查询模板
    if (template.contains('多少') && input.contains('多少')) {
      entities['queryType'] = 'amount';
      confidence = 0.8;
      return {'confidence': confidence, 'entities': entities};
    }

    // 钱龄操作模板
    if (template.contains('钱龄') || template.contains('资金')) {
      if (input.contains('钱龄') || input.contains('资金健康')) {
        if (input.contains('优化') || input.contains('建议')) {
          entities['operation'] = 'optimize';
        } else if (input.contains('资金池') || input.contains('FIFO')) {
          entities['operation'] = 'pool';
        } else {
          entities['operation'] = 'query';
        }
        confidence = 0.85;
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 习惯操作模板
    if (template.contains('打卡') || template.contains('签到') ||
        template.contains('挑战') || template.contains('奖励') ||
        template.contains('积分')) {
      if (input.contains('打卡') || input.contains('签到')) {
        entities['operation'] = 'checkin';
        confidence = 0.9;
      } else if (input.contains('挑战')) {
        entities['operation'] = 'challenge';
        confidence = 0.85;
      } else if (input.contains('兑换') || input.contains('奖励')) {
        entities['operation'] = 'reward';
        confidence = 0.85;
      } else if (input.contains('积分')) {
        entities['operation'] = 'points';
        confidence = 0.85;
      }
      if (entities.containsKey('operation')) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 小金库操作模板
    if (template.contains('小金库') || template.contains('{vaultName}')) {
      if (input.contains('分配') || input.contains('存入')) {
        entities['operation'] = 'allocate';
        final amount = _extractAmount(input);
        if (amount != null) entities['amount'] = amount;
        entities['vaultName'] = _extractVaultName(input);
        confidence = 0.85;
      } else if (input.contains('取') || input.contains('取出')) {
        entities['operation'] = 'withdraw';
        final amount = _extractAmount(input);
        if (amount != null) entities['amount'] = amount;
        entities['vaultName'] = _extractVaultName(input);
        confidence = 0.85;
      } else if (input.contains('调') || input.contains('转')) {
        entities['operation'] = 'transfer';
        final amount = _extractAmount(input);
        if (amount != null) entities['amount'] = amount;
        confidence = 0.80;
      } else if (input.contains('还有') || input.contains('余额') ||
                 input.contains('剩余') || input.contains('多少')) {
        entities['operation'] = 'query';
        entities['vaultName'] = _extractVaultName(input);
        confidence = 0.85;
      }
      if (entities.containsKey('operation')) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 数据操作模板
    if (template.contains('备份') || template.contains('导出') ||
        template.contains('同步') || template.contains('刷新')) {
      if (input.contains('备份')) {
        entities['operation'] = 'backup';
        confidence = 0.9;
      } else if (input.contains('导出') || input.contains('下载')) {
        entities['operation'] = 'export';
        confidence = 0.85;
      } else if (input.contains('同步') || input.contains('刷新')) {
        entities['operation'] = 'sync';
        confidence = 0.85;
      } else if (input.contains('恢复')) {
        entities['operation'] = 'restore';
        confidence = 0.8;
      }
      if (entities.containsKey('operation')) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 分享操作模板
    if (template.contains('分享') || template.contains('邀请')) {
      if (input.contains('分享') && (input.contains('报') || input.contains('总结'))) {
        entities['operation'] = 'report';
        if (input.contains('月')) {
          entities['reportType'] = 'month';
        } else if (input.contains('周')) {
          entities['reportType'] = 'week';
        } else if (input.contains('年')) {
          entities['reportType'] = 'year';
        }
        confidence = 0.85;
      } else if (input.contains('邀请') || input.contains('好友')) {
        entities['operation'] = 'invite';
        confidence = 0.85;
      } else if (input.contains('总结')) {
        entities['operation'] = 'summary';
        confidence = 0.85;
      }
      if (entities.containsKey('operation')) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 系统操作模板
    if (template.contains('更新') || template.contains('版本') ||
        template.contains('反馈') || template.contains('客服') ||
        template.contains('缓存') || template.contains('空间')) {
      if (input.contains('更新') || input.contains('检查')) {
        entities['operation'] = 'update';
        confidence = 0.85;
      } else if (input.contains('版本')) {
        entities['operation'] = 'version';
        confidence = 0.85;
      } else if (input.contains('反馈')) {
        entities['operation'] = 'feedback';
        confidence = 0.85;
      } else if (input.contains('客服')) {
        entities['operation'] = 'support';
        confidence = 0.85;
      } else if (input.contains('缓存') || input.contains('清理')) {
        entities['operation'] = 'cache';
        confidence = 0.85;
      } else if (input.contains('空间') || input.contains('释放')) {
        entities['operation'] = 'space';
        confidence = 0.85;
      }
      if (entities.containsKey('operation')) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    // 配置操作模板
    if (template.contains('{configItem}') || template.contains('开启') ||
        template.contains('关闭') || template.contains('设置')) {
      if (input.contains('开启') || input.contains('打开') || input.contains('启用')) {
        entities['operation'] = 'enable';
        entities['configId'] = _extractConfigItem(input);
        confidence = 0.8;
      } else if (input.contains('关闭') || input.contains('禁用')) {
        entities['operation'] = 'disable';
        entities['configId'] = _extractConfigItem(input);
        confidence = 0.8;
      } else if (input.contains('设置') || input.contains('调') || input.contains('改')) {
        entities['operation'] = 'set';
        entities['configId'] = _extractConfigItem(input);
        confidence = 0.75;
      }
      if (entities.containsKey('operation') && entities['configId'] != null) {
        return {'confidence': confidence, 'entities': entities};
      }
    }

    return null;
  }

  /// 提取小金库名称
  String? _extractVaultName(String input) {
    // 常见小金库名称
    const vaultNames = ['旅游', '购物', '餐饮', '交通', '娱乐', '应急', '储蓄', '教育', '医疗'];
    for (final name in vaultNames) {
      if (input.contains(name)) return name;
    }
    // 尝试提取"到XXX"或"从XXX"格式
    final toMatch = RegExp(r'(?:到|进|向|从)(.+?)(?:小金库)?(?:取|分配|存入|$)').firstMatch(input);
    if (toMatch != null) return toMatch.group(1)?.trim();
    return null;
  }

  /// 提取配置项名称
  String? _extractConfigItem(String input) {
    // 常见配置项关键词
    const configItems = {
      '零基预算': 'budget.zero_based.enabled',
      '预算结转': 'budget.carryover.mode',
      '分类置信度': 'ai.category.confidence_threshold',
      '异常检测': 'ai.anomaly.sensitivity',
      '打卡提醒': 'habit.checkin.reminder_time',
      '自动备份': 'sync.auto_backup.enabled',
      '深色模式': 'theme.dark_mode.enabled',
      '手势识别': 'security.gesture.enabled',
    };
    for (final entry in configItems.entries) {
      if (input.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer 4: 学习缓存匹配
  // ═══════════════════════════════════════════════════════════════

  Future<SmartIntentResult?> _layer4LearnedCache(String input) async {
    await _ensureCacheLoaded();

    // 精确匹配
    if (_learnedCache.containsKey(input)) {
      final pattern = _learnedCache[input]!;
      return SmartIntentResult(
        intentType: pattern.intentType,
        confidence: 0.9,
        entities: pattern.entities,
        source: RecognitionSource.learnedCache,
        originalInput: input,
      );
    }

    // 模糊匹配（编辑距离）
    for (final entry in _learnedCache.entries) {
      final distance = _levenshteinDistance(input, entry.key);
      final similarity = 1 - (distance / input.length.clamp(1, 100));

      if (similarity >= 0.85) {
        final pattern = entry.value;
        return SmartIntentResult(
          intentType: pattern.intentType,
          confidence: similarity * 0.95,
          entities: pattern.entities,
          source: RecognitionSource.learnedCache,
          originalInput: input,
        );
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer 5: LLM兜底
  // ═══════════════════════════════════════════════════════════════

  Future<SmartIntentResult?> _layer5LLMFallback(
    String input,
    String? pageContext,
  ) async {
    try {
      final prompt = _buildLLMPrompt(input, pageContext);
      final response = await _qwenService.chat(prompt);

      if (response == null || response.isEmpty) {
        return null;
      }

      return _parseLLMResponse(response, input);
    } catch (e) {
      debugPrint('[SmartIntent] LLM调用失败: $e');
      return null;
    }
  }

  String _buildLLMPrompt(String input, String? pageContext) {
    // 获取高适配语音导航的页面列表
    final highAdaptPages = _navigationService.highAdaptationPages;
    final pageList = highAdaptPages
        .take(30) // 限制数量以控制 prompt 长度
        .map((p) => '${p.name}(${p.route})')
        .join('、');

    return '''
你是一个记账助手，请理解用户输入并返回JSON。

【用户输入】$input
【页面上下文】${pageContext ?? '首页'}

【意图类型】
- add_transaction: 记账（需要金额）
- navigate: 导航（打开某页面）
- query: 查询统计
- modify: 修改记录
- delete: 删除记录
- confirm: 确认
- cancel: 取消
- config: 配置操作（设置、开启/关闭功能）
- money_age: 钱龄操作（查看钱龄、资金健康度）
- habit: 习惯操作（打卡、挑战、奖励）
- vault: 小金库操作（分配、查询、调拨资金）
- data: 数据操作（备份、导出、同步）
- share: 分享操作（分享报告、邀请好友）
- system: 系统操作（检查更新、清理缓存）

【返回格式】
{"intent":"意图类型","confidence":0.9,"entities":{"amount":金额,"category":"分类","note":"具体物品或用途","targetPage":"页面名","route":"路由","operation":"操作类型","configId":"配置项ID","vaultName":"小金库名称"}}

【记账参数说明】
- amount: 金额（必填）
- category: 分类（必填）
- note: 物品/用途说明（可选，用户说了具体物品时必须提取，如"闹钟"、"衣服"、"打车"等）

【分类】餐饮、交通、购物、娱乐、居住、医疗、其他
【常用页面】$pageList

只返回JSON，不要其他内容：''';
  }

  SmartIntentResult? _parseLLMResponse(String response, String originalInput) {
    try {
      final jsonStr = _extractJson(response);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final intentStr = json['intent'] as String? ?? 'unknown';
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.7;
      final entities = json['entities'] as Map<String, dynamic>? ?? {};

      return SmartIntentResult(
        intentType: _parseIntentType(intentStr),
        confidence: confidence,
        entities: entities,
        source: RecognitionSource.llmFallback,
        originalInput: originalInput,
      );
    } catch (e) {
      debugPrint('[SmartIntent] 解析LLM响应失败: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 学习功能
  // ═══════════════════════════════════════════════════════════════

  /// 学习新模式
  Future<void> _learnPattern(String input, SmartIntentResult result) async {
    final pattern = LearnedPattern(
      intentType: result.intentType,
      entities: result.entities,
      learnedAt: DateTime.now(),
      hitCount: 1,
    );

    _learnedCache[input] = pattern;
    await _saveCache();

    debugPrint('[SmartIntent] 学习新模式: $input → ${result.intentType}');
  }

  /// 确保缓存已加载
  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString('smart_intent_cache');

      if (cacheJson != null) {
        final cacheMap = jsonDecode(cacheJson) as Map<String, dynamic>;
        for (final entry in cacheMap.entries) {
          _learnedCache[entry.key] = LearnedPattern.fromJson(entry.value);
        }
        debugPrint('[SmartIntent] 加载了${_learnedCache.length}个学习模式');
      }
    } catch (e) {
      debugPrint('[SmartIntent] 加载缓存失败: $e');
    }

    _cacheLoaded = true;
  }

  /// 保存缓存
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMap = _learnedCache.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString('smart_intent_cache', jsonEncode(cacheMap));
    } catch (e) {
      debugPrint('[SmartIntent] 保存缓存失败: $e');
    }
  }

  /// 手动添加学习模式（用户纠正时）
  Future<void> learnFromCorrection(
    String input,
    SmartIntentType correctIntent,
    Map<String, dynamic> correctEntities,
  ) async {
    final pattern = LearnedPattern(
      intentType: correctIntent,
      entities: correctEntities,
      learnedAt: DateTime.now(),
      hitCount: 1,
      isUserCorrection: true,
    );

    _learnedCache[_normalize(input)] = pattern;
    await _saveCache();

    debugPrint('[SmartIntent] 从纠正中学习: $input → $correctIntent');
  }

  // ═══════════════════════════════════════════════════════════════
  // 辅助方法
  // ═══════════════════════════════════════════════════════════════

  String _normalize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[。！？，、；：]'), '');
  }

  String? _extractJson(String response) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return response.substring(start, end + 1);
  }

  double? _extractAmount(String input) {
    // 阿拉伯数字
    final arabicMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(input);
    if (arabicMatch != null) {
      return double.tryParse(arabicMatch.group(1)!);
    }

    // 中文数字
    return _parseChineseNumber(input);
  }

  double? _parseChineseNumber(String input) {
    final chineseDigits = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '百': 100, '千': 1000, '万': 10000,
    };

    final match = RegExp(r'[零一二两三四五六七八九十百千万]+').firstMatch(input);
    if (match == null) return null;

    final chineseNum = match.group(0)!;
    double result = 0;
    double current = 0;

    for (int i = 0; i < chineseNum.length; i++) {
      final char = chineseNum[i];
      final value = chineseDigits[char];
      if (value == null) continue;

      if (value >= 10) {
        if (current == 0) current = 1;
        current *= value;
        if (value == 10 && i == chineseNum.length - 1) {
          result += current;
          current = 0;
        }
      } else {
        if (current > 0) {
          result += current;
        }
        current = value.toDouble();
      }
    }

    result += current;
    return result > 0 ? result : null;
  }

  String _inferCategory(String input) {
    final categoryKeywords = {
      '餐饮': ['吃', '饭', '餐', '午餐', '早餐', '晚餐', '外卖', '咖啡', '奶茶', '零食', '买菜'],
      '交通': ['打车', '滴滴', '出租', '公交', '地铁', '高铁', '火车', '飞机', '加油', '停车'],
      '购物': ['买', '购', '淘宝', '京东', '超市', '商场', '网购'],
      '娱乐': ['电影', '游戏', '旅游', 'KTV', '唱歌', '玩'],
      '居住': ['房租', '水电', '物业', '燃气', '暖气'],
      '医疗': ['医院', '看病', '药', '医疗', '体检'],
      '通讯': ['话费', '网费', '流量', '宽带'],
    };

    for (final entry in categoryKeywords.entries) {
      if (entry.value.any((k) => input.contains(k))) {
        return entry.key;
      }
    }

    return '其他';
  }

  /// 提取物品/用途说明
  ///
  /// 从输入中提取具体的物品名称或用途，作为交易备注
  /// 例如："买了个闹钟11块" → "闹钟"
  /// 例如："淘宝买衣服199" → "淘宝买衣服"
  String? _extractItemNote(String input, String category) {
    // 移除金额相关的部分
    String text = input
        .replaceAll(RegExp(r'\d+(\.\d+)?(元|块|毛|角|分|块钱|元钱)?'), '')
        .replaceAll(RegExp(r'[零一二两三四五六七八九十百千万]+(\s*(元|块|毛|角|分|块钱|元钱))?'), '');

    // 移除常见的动词和助词
    final removePatterns = [
      '花了', '花', '消费', '支出', '付了', '付', '买了', '买', '用了', '支付',
      '收入', '赚了', '进账', '收到', '入账',
      '一个', '一件', '一份', '一瓶', '一杯', '一碗', '一盒',
      '了', '的', '个', '只', '件', '把', '张', '台', '部',
    ];
    for (final pattern in removePatterns) {
      text = text.replaceAll(pattern, '');
    }

    // 清理空白和标点
    text = text
        .replaceAll(RegExp(r'[，。！？、；：,.!?;:\s]+'), '')
        .trim();

    // 如果提取的内容太短或太长，或者与分类相同，返回null
    if (text.isEmpty || text.length < 2 || text.length > 20 || text == category) {
      return null;
    }

    return text;
  }

  SmartIntentType _mapIntentType(VoiceIntentType type) {
    switch (type) {
      case VoiceIntentType.addTransaction:
        return SmartIntentType.addTransaction;
      case VoiceIntentType.deleteTransaction:
        return SmartIntentType.delete;
      case VoiceIntentType.modifyTransaction:
        return SmartIntentType.modify;
      case VoiceIntentType.queryTransaction:
        return SmartIntentType.query;
      case VoiceIntentType.navigateToPage:
        return SmartIntentType.navigate;
      case VoiceIntentType.confirmAction:
        return SmartIntentType.confirm;
      case VoiceIntentType.cancelAction:
        return SmartIntentType.cancel;
      default:
        return SmartIntentType.unknown;
    }
  }

  SmartIntentType _parseIntentType(String type) {
    switch (type.toLowerCase()) {
      case 'add_transaction':
        return SmartIntentType.addTransaction;
      case 'navigate':
        return SmartIntentType.navigate;
      case 'query':
        return SmartIntentType.query;
      case 'modify':
        return SmartIntentType.modify;
      case 'delete':
        return SmartIntentType.delete;
      case 'confirm':
        return SmartIntentType.confirm;
      case 'cancel':
        return SmartIntentType.cancel;
      case 'config':
        return SmartIntentType.config;
      case 'money_age':
        return SmartIntentType.moneyAge;
      case 'habit':
        return SmartIntentType.habit;
      case 'vault':
        return SmartIntentType.vault;
      case 'data':
        return SmartIntentType.dataOp;
      case 'share':
        return SmartIntentType.share;
      case 'system':
        return SmartIntentType.systemOp;
      default:
        return SmartIntentType.unknown;
    }
  }

  Map<String, dynamic> _extractEntities(IntentAnalysisResult result) {
    return Map<String, dynamic>.from(result.entities);
  }

  /// 计算编辑距离（Levenshtein Distance）
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List.generate(s2.length + 1, (i) => i);
    List<int> curr = List.filled(s2.length + 1, 0);

    for (int i = 1; i <= s1.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[s2.length];
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

/// 智能意图识别结果
class SmartIntentResult {
  final SmartIntentType intentType;
  final double confidence;
  final Map<String, dynamic> entities;
  final RecognitionSource source;
  final String originalInput;
  final String? errorMessage;

  const SmartIntentResult({
    required this.intentType,
    required this.confidence,
    required this.entities,
    required this.source,
    required this.originalInput,
    this.errorMessage,
  });

  factory SmartIntentResult.error(String message) {
    return SmartIntentResult(
      intentType: SmartIntentType.unknown,
      confidence: 0,
      entities: {},
      source: RecognitionSource.error,
      originalInput: '',
      errorMessage: message,
    );
  }

  bool get isSuccess => errorMessage == null && intentType != SmartIntentType.unknown;

  @override
  String toString() {
    return 'SmartIntentResult(type: $intentType, confidence: $confidence, source: $source)';
  }
}

/// 意图类型
enum SmartIntentType {
  addTransaction,
  navigate,
  query,
  modify,
  delete,
  confirm,
  cancel,
  config,        // 配置操作
  moneyAge,      // 钱龄操作
  habit,         // 习惯操作
  vault,         // 小金库操作
  dataOp,        // 数据操作
  share,         // 分享操作
  systemOp,      // 系统操作
  unknown,
}

/// 识别来源
enum RecognitionSource {
  exactRule,       // 精确规则匹配
  synonymExpansion, // 同义词扩展
  templateMatch,   // 模板匹配
  learnedCache,    // 学习缓存
  llmFallback,     // LLM兜底
  error,           // 错误
}

/// 学习的模式
class LearnedPattern {
  final SmartIntentType intentType;
  final Map<String, dynamic> entities;
  final DateTime learnedAt;
  final int hitCount;
  final bool isUserCorrection;

  LearnedPattern({
    required this.intentType,
    required this.entities,
    required this.learnedAt,
    this.hitCount = 0,
    this.isUserCorrection = false,
  });

  factory LearnedPattern.fromJson(Map<String, dynamic> json) {
    return LearnedPattern(
      intentType: SmartIntentType.values.firstWhere(
        (e) => e.name == json['intentType'],
        orElse: () => SmartIntentType.unknown,
      ),
      entities: json['entities'] as Map<String, dynamic>? ?? {},
      learnedAt: DateTime.parse(json['learnedAt'] as String),
      hitCount: json['hitCount'] as int? ?? 0,
      isUserCorrection: json['isUserCorrection'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intentType': intentType.name,
      'entities': entities,
      'learnedAt': learnedAt.toIso8601String(),
      'hitCount': hitCount,
      'isUserCorrection': isUserCorrection,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// 多操作识别数据模型
// ═══════════════════════════════════════════════════════════════

/// 多操作识别结果
class MultiOperationResult {
  /// 结果类型：operation/chat/clarify/failed
  final RecognitionResultType resultType;
  final List<Operation> operations;
  final String? chatContent;
  /// 澄清问题（当resultType为clarify时使用）
  final String? clarifyQuestion;
  final double confidence;
  final RecognitionSource source;
  final String originalInput;
  final String? errorMessage;
  /// 是否处于离线模式（LLM不可用，使用规则兜底）
  final bool isOfflineMode;

  const MultiOperationResult({
    required this.resultType,
    required this.operations,
    required this.chatContent,
    required this.confidence,
    required this.source,
    required this.originalInput,
    this.clarifyQuestion,
    this.errorMessage,
    this.isOfflineMode = false,
  });

  /// 有操作的结果
  factory MultiOperationResult.withOperations({
    required List<Operation> operations,
    String? chatContent,
    required double confidence,
    required RecognitionSource source,
    required String originalInput,
  }) {
    return MultiOperationResult(
      resultType: RecognitionResultType.operation,
      operations: operations,
      chatContent: chatContent,
      confidence: confidence,
      source: source,
      originalInput: originalInput,
    );
  }

  /// 闲聊结果（无需操作）
  factory MultiOperationResult.chat({
    required String chatContent,
    required RecognitionSource source,
    required String originalInput,
  }) {
    return MultiOperationResult(
      resultType: RecognitionResultType.chat,
      operations: [],
      chatContent: chatContent,
      confidence: 0.9,
      source: source,
      originalInput: originalInput,
    );
  }

  /// 需要澄清的结果
  factory MultiOperationResult.clarify({
    required String clarifyQuestion,
    required RecognitionSource source,
    required String originalInput,
  }) {
    return MultiOperationResult(
      resultType: RecognitionResultType.clarify,
      operations: [],
      chatContent: null,
      clarifyQuestion: clarifyQuestion,
      confidence: 0.9,
      source: source,
      originalInput: originalInput,
    );
  }

  /// LLM不可用时的失败结果
  factory MultiOperationResult.failed(String message) {
    return MultiOperationResult(
      resultType: RecognitionResultType.failed,
      operations: [],
      chatContent: null,
      confidence: 0,
      source: RecognitionSource.error,
      originalInput: '',
      errorMessage: message,
    );
  }

  /// 兼容旧的 error 工厂方法
  factory MultiOperationResult.error(String message) {
    return MultiOperationResult.failed(message);
  }

  /// 是否成功识别（包括operation、chat、clarify都算成功）
  bool get isSuccess => resultType != RecognitionResultType.failed;

  /// 是否有操作需要执行
  bool get hasOperations => resultType == RecognitionResultType.operation && operations.isNotEmpty;

  /// 是否是闲聊
  bool get isChat => resultType == RecognitionResultType.chat;

  /// 是否需要澄清
  bool get needsClarify => resultType == RecognitionResultType.clarify;

  @override
  String toString() {
    return 'MultiOperationResult(type: $resultType, operations: ${operations.length}, confidence: $confidence, source: $source)';
  }
}

/// 操作
class Operation {
  final OperationType type;
  final OperationPriority priority;
  final Map<String, dynamic> params;
  final String originalText;

  const Operation({
    required this.type,
    required this.priority,
    required this.params,
    required this.originalText,
  });

  @override
  String toString() {
    return 'Operation(type: $type, priority: $priority, params: $params)';
  }
}

/// 操作类型
///
/// @deprecated 请使用 [unified.UnifiedIntentType] 代替
/// 此枚举保留用于向后兼容，新代码应使用统一意图类型
enum OperationType {
  addTransaction,
  navigate,
  query,
  modify,
  delete,
  unknown,
}

/// OperationType 到 UnifiedIntentType 的转换扩展
extension OperationTypeConversion on OperationType {
  /// 转换为统一意图类型
  unified.UnifiedIntentType toUnified() {
    switch (this) {
      case OperationType.addTransaction:
        return unified.UnifiedIntentType.transactionAdd;
      case OperationType.navigate:
        return unified.UnifiedIntentType.navigationPage;
      case OperationType.query:
        return unified.UnifiedIntentType.transactionQuery;
      case OperationType.modify:
        return unified.UnifiedIntentType.transactionModify;
      case OperationType.delete:
        return unified.UnifiedIntentType.transactionDelete;
      case OperationType.unknown:
        return unified.UnifiedIntentType.unknown;
    }
  }

  /// 从统一意图类型创建
  static OperationType fromUnified(unified.UnifiedIntentType type) {
    switch (type) {
      case unified.UnifiedIntentType.transactionAdd:
        return OperationType.addTransaction;
      case unified.UnifiedIntentType.navigationPage:
      case unified.UnifiedIntentType.navigationBack:
      case unified.UnifiedIntentType.navigationHome:
        return OperationType.navigate;
      case unified.UnifiedIntentType.transactionQuery:
        return OperationType.query;
      case unified.UnifiedIntentType.transactionModify:
        return OperationType.modify;
      case unified.UnifiedIntentType.transactionDelete:
        return OperationType.delete;
      default:
        return OperationType.unknown;
    }
  }
}

/// 操作优先级
///
/// @deprecated 请使用 [unified.OperationPriority] 代替
enum OperationPriority {
  immediate,   // 立即执行（导航）
  normal,      // 快速执行（查询）
  deferred,    // 延迟执行（记账，可聚合）
  background,  // 后台执行（批量操作）
}
