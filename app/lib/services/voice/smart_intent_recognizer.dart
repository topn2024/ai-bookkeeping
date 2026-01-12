import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../qwen_service.dart';
import '../voice_service_coordinator.dart' show VoiceIntentType;
import '../voice_navigation_service.dart';
import 'voice_intent_router.dart';

/// 智能意图识别器
///
/// 多层递进架构，平衡速度和准确性：
///
/// ```
/// Layer 1: 精确规则匹配（最快，~1ms）
///    ↓ 未命中
/// Layer 2: 同义词扩展匹配（快，~5ms）
///    ↓ 未命中
/// Layer 3: 意图模板匹配（较快，~10ms）
///    ↓ 未命中
/// Layer 4: 学习缓存匹配（快，~5ms）
///    ↓ 未命中
/// Layer 5: LLM兜底（慢，~2-3s）
///    ↓ 成功后
/// 反向学习: 将结果加入Layer 4缓存
/// ```
class SmartIntentRecognizer {
  final VoiceIntentRouter _ruleRouter;
  final QwenService _qwenService;
  final VoiceNavigationService _navigationService;

  /// 学习缓存
  final Map<String, LearnedPattern> _learnedCache = {};

  /// 是否已加载缓存
  bool _cacheLoaded = false;

  SmartIntentRecognizer({
    VoiceIntentRouter? ruleRouter,
    QwenService? qwenService,
    VoiceNavigationService? navigationService,
  })  : _ruleRouter = ruleRouter ?? VoiceIntentRouter(),
        _qwenService = qwenService ?? QwenService(),
        _navigationService = navigationService ?? VoiceNavigationService();

  /// 识别意图（多层递进）
  Future<SmartIntentResult> recognize(
    String input, {
    String? pageContext,
  }) async {
    if (input.trim().isEmpty) {
      return SmartIntentResult.error('输入为空');
    }

    final normalizedInput = _normalize(input);
    debugPrint('[SmartIntent] 开始识别: $input');

    // Layer 1: 精确规则匹配
    var result = await _layer1ExactRule(normalizedInput);
    if (result != null && result.confidence >= 0.8) {
      debugPrint('[SmartIntent] Layer1命中: ${result.intentType}');
      return result;
    }

    // Layer 2: 同义词扩展匹配
    result = await _layer2SynonymExpansion(normalizedInput);
    if (result != null && result.confidence >= 0.75) {
      debugPrint('[SmartIntent] Layer2命中: ${result.intentType}');
      return result;
    }

    // Layer 3: 意图模板匹配
    result = await _layer3TemplateMatch(normalizedInput);
    if (result != null && result.confidence >= 0.7) {
      debugPrint('[SmartIntent] Layer3命中: ${result.intentType}');
      return result;
    }

    // Layer 4: 学习缓存匹配
    result = await _layer4LearnedCache(normalizedInput);
    if (result != null && result.confidence >= 0.85) {
      debugPrint('[SmartIntent] Layer4命中: ${result.intentType}');
      return result;
    }

    // Layer 5: LLM兜底
    debugPrint('[SmartIntent] 进入Layer5 LLM兜底');
    result = await _layer5LLMFallback(input, pageContext);

    // 反向学习：成功识别后加入缓存
    if (result != null && result.isSuccess && result.confidence >= 0.85) {
      await _learnPattern(normalizedInput, result);
    }

    return result ?? SmartIntentResult.error('无法理解您的指令');
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
    '收入': ['收入', '赚了', '进账', '收到', '工资', '奖金', '入账'],
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
    // 使用 VoiceNavigationService 进行导航识别
    // 它包含 237 个页面的丰富别名配置、模式匹配和模糊匹配
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

    // 如果 VoiceNavigationService 未匹配，回退到本地同义词检查
    // 检查是否包含导航动词（或同义词）
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

    if (!hasNavVerb) return null;

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

    return SmartIntentResult(
      intentType: SmartIntentType.addTransaction,
      confidence: 0.8,
      entities: {
        'amount': amount,
        'category': category,
        'type': isIncome ? 'income' : 'expense',
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
        entities['amount'] = amount;
        entities['category'] = _inferCategory(input);
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
{"intent":"意图类型","confidence":0.9,"entities":{"amount":金额,"category":"分类","targetPage":"页面名","route":"路由","operation":"操作类型","configId":"配置项ID","vaultName":"小金库名称"}}

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
