import 'dart:async';

import 'package:flutter/foundation.dart';
import '../category_localization_service.dart';
import '../qwen_service.dart';

/// LLM响应生成器
///
/// 使用大语言模型生成自然、口语化的语音回复
/// 优先使用LLM，失败时降级到模板回复
class LLMResponseGenerator {
  static final LLMResponseGenerator _instance = LLMResponseGenerator._();
  static LLMResponseGenerator get instance => _instance;

  final QwenService _qwenService = QwenService();

  /// LLM调用超时时间
  static const Duration _timeout = Duration(seconds: 3);

  LLMResponseGenerator._();

  /// 检查LLM是否可用
  bool get isAvailable => _qwenService.isAvailable;

  /// 生成记账成功的回复
  ///
  /// [transactions] 记录的交易列表
  /// [userInput] 用户原始输入
  Future<String> generateTransactionResponse({
    required List<TransactionInfo> transactions,
    required String userInput,
  }) async {
    if (!isAvailable) {
      return _fallbackTransactionResponse(transactions);
    }

    try {
      final prompt = _buildTransactionPrompt(transactions, userInput);
      final response = await _qwenService.chat(prompt).timeout(
        _timeout,
        onTimeout: () => throw TimeoutException('LLM响应超时', _timeout),
      );

      if (response != null && response.isNotEmpty) {
        final cleaned = _cleanResponse(response);
        if (cleaned.isNotEmpty) {
          debugPrint('[LLMResponse] 生成回复: $cleaned');
          return cleaned;
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('[LLMResponse] LLM调用超时(${e.duration}), 降级到模板');
    } catch (e) {
      debugPrint('[LLMResponse] LLM调用失败，使用模板: $e');
    }

    return _fallbackTransactionResponse(transactions);
  }

  /// 生成通用回复
  ///
  /// [action] 执行的操作（如：记账、删除、修改、查询）
  /// [result] 操作结果描述
  /// [success] 是否成功
  /// [userInput] 用户原始输入
  Future<String> generateResponse({
    required String action,
    required String result,
    required bool success,
    String? userInput,
  }) async {
    if (!isAvailable) {
      return _fallbackResponse(action, result, success);
    }

    try {
      final prompt = _buildGeneralPrompt(action, result, success, userInput);
      final response = await _qwenService.chat(prompt).timeout(
        _timeout,
        onTimeout: () => throw TimeoutException('LLM响应超时', _timeout),
      );

      if (response != null && response.isNotEmpty) {
        final cleaned = _cleanResponse(response);
        if (cleaned.isNotEmpty) {
          debugPrint('[LLMResponse] 生成回复: $cleaned');
          return cleaned;
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('[LLMResponse] LLM调用超时(${e.duration}), 降级到模板');
    } catch (e) {
      debugPrint('[LLMResponse] LLM调用失败，使用模板: $e');
    }

    return _fallbackResponse(action, result, success);
  }

  /// 生成闲聊回复
  ///
  /// [userInput] 用户输入
  /// [chatIntent] 检测到的闲聊意图（可选，用于引导回复方向）
  /// [chatHistory] 之前的对话历史（用于多轮对话）
  Future<String> generateCasualChatResponse({
    required String userInput,
    String? chatIntent,
    String? chatHistory,
  }) async {
    if (!isAvailable) {
      return _fallbackCasualChatResponse(userInput, chatIntent);
    }

    try {
      final hour = DateTime.now().hour;
      String timeContext;
      if (hour >= 5 && hour < 12) {
        timeContext = '早上';
      } else if (hour >= 12 && hour < 18) {
        timeContext = '下午';
      } else {
        timeContext = '晚上';
      }

      // 检测是否是需要较长回复的请求
      final needsLongResponse = userInput.contains('故事') ||
          userInput.contains('笑话') ||
          userInput.contains('讲个') ||
          userInput.contains('说个') ||
          userInput.contains('来个') ||
          userInput.contains('诗') ||
          userInput.contains('歌词') ||
          userInput.contains('介绍') ||
          userInput.contains('解释') ||
          userInput.contains('详细');

      final lengthGuidance = needsLongResponse
          ? '可以适当展开，100-300字即可，内容完整有趣'
          : '简短自然（15-30字，最多不超过50字）';

      final prompt = '''
你是白记，一个可爱、活泼的记账助手。用户在和你闲聊，请用自然、亲切的方式回应。

当前时间：$timeContext
${chatHistory != null && chatHistory.isNotEmpty ? '\n$chatHistory\n' : ''}
用户现在说：$userInput
${chatIntent != null ? '（检测到的意图：$chatIntent）' : ''}

要求：
1. $lengthGuidance
2. 口语化，像朋友聊天
3. 可以用语气词如"嗯"、"哈哈"、"呀"、"~"等
4. 保持积极友好的态度
5. 根据上下文自然回应，保持对话连贯性
6. 可以适当引导到记账话题，但不要强行转换
7. 不要说"我是AI"或"我是机器人"
8. 如果用户表达情绪，先共情再回应
9. 如果用户想结束对话（说再见/拜拜），温馨告别
10. 如果用户想听故事/笑话/诗等，大方地满足请求，内容要有趣完整

直接输出回复内容，不要加引号：''';

      // 需要长回复的场景给更多时间
      final timeout = needsLongResponse ? const Duration(seconds: 10) : const Duration(seconds: 5);
      final response = await _qwenService.chat(prompt).timeout(timeout);
      if (response != null && response.isNotEmpty) {
        // 闲聊回复：普通回复50字，故事/笑话等允许更长（最多500字）
        final maxLen = needsLongResponse ? 500 : 100;
        final cleaned = _cleanResponse(response, maxLength: maxLen);
        if (cleaned.isNotEmpty) {
          debugPrint('[LLMResponse] 闲聊回复: $cleaned');
          return cleaned;
        }
      }
    } catch (e) {
      debugPrint('[LLMResponse] 闲聊回复生成失败: $e');
    }

    return _fallbackCasualChatResponse(userInput, chatIntent);
  }

  /// 闲聊模板回复（降级方案）
  String _fallbackCasualChatResponse(String userInput, String? chatIntent) {
    final lowerInput = userInput.toLowerCase();

    // 问候
    if (lowerInput.contains('你好') || lowerInput.contains('hi') || lowerInput.contains('hello')) {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) return '早上好呀~有什么需要帮忙的吗？';
      if (hour >= 12 && hour < 18) return '下午好~要记一笔账吗？';
      return '晚上好~今天花了多少呀？';
    }

    // 感谢
    if (lowerInput.contains('谢谢') || lowerInput.contains('感谢')) {
      return '不客气~有需要随时找我';
    }

    // 再见
    if (lowerInput.contains('再见') || lowerInput.contains('拜拜') || lowerInput.contains('晚安')) {
      return '拜拜~记得常来记账哦';
    }

    // 心情
    if (lowerInput.contains('累') || lowerInput.contains('烦') || lowerInput.contains('郁闷')) {
      return '辛苦啦~要不要看看这个月省了多少钱开心一下？';
    }

    if (lowerInput.contains('开心') || lowerInput.contains('高兴')) {
      return '开心就好~顺便记一笔账吧？';
    }

    // 询问能力
    if (lowerInput.contains('你能') || lowerInput.contains('你会') || lowerInput.contains('你是谁')) {
      return '我是白记呀~帮你记账、查账、管预算，这些我都行！';
    }

    // 讲笑话/讲故事
    if (lowerInput.contains('笑话') || lowerInput.contains('讲个')) {
      const jokes = [
        '为什么程序员总是分不清万圣节和圣诞节？因为Oct 31等于Dec 25！',
        '有一天小明问老师：为什么预算总是不够？老师说：因为你花得太快啦~',
        '钱包对主人说：你总是把我掏空，我很伤心。主人说：别担心，下个月工资会填满你的！',
      ];
      return jokes[DateTime.now().millisecond % jokes.length];
    }

    // 讲故事
    if (lowerInput.contains('故事')) {
      return '从前有个人坚持记账，后来他发现省下的钱够买一台新手机啦~记账真的有用哦！';
    }

    // 默认
    return '嗯嗯~要记账还是查账呢？';
  }

  /// 生成告别回复
  ///
  /// [farewellType] 告别类型：
  /// - 'userEnd': 用户主动说再见
  /// - 'silenceTimeout': 用户静默超时
  /// - 'sessionTimeout': 会话超时
  /// - 'default': 默认告别
  Future<String> generateFarewellResponse({
    String farewellType = 'default',
  }) async {
    if (!isAvailable) {
      return _fallbackFarewellResponse(farewellType);
    }

    try {
      final hour = DateTime.now().hour;
      String timeContext;
      if (hour >= 5 && hour < 12) {
        timeContext = '早上';
      } else if (hour >= 12 && hour < 18) {
        timeContext = '下午';
      } else if (hour >= 22 || hour < 5) {
        timeContext = '深夜';
      } else {
        timeContext = '晚上';
      }

      String scenario;
      switch (farewellType) {
        case 'userEnd':
          scenario = '用户主动说再见，请温馨告别';
          break;
        case 'silenceTimeout':
          scenario = '用户一段时间没说话，你准备先休息，但表示随时可以再聊';
          break;
        case 'sessionTimeout':
          scenario = '对话暂时结束，表示随时可以继续';
          break;
        default:
          scenario = '对话结束，温馨告别';
      }

      final prompt = '''
你是白记，一个可爱的记账助手。现在对话要结束了，请用自然、亲切的方式告别。

当前时间：$timeContext
场景：$scenario

要求：
1. 简短自然（10-20字）
2. 口语化，像朋友告别
3. 可以根据时间给一句关心的话（如晚上提醒早点休息）
4. 【重要】让每次告别都有变化，不要总说"有需要随时叫我"
5. 可以用一些变化的表达，如"下次见"、"记得常来记账哦"、"拜拜啦"等
6. 保持积极友好的态度

直接输出回复内容，不要加引号：''';

      final response = await _qwenService.chat(prompt).timeout(_timeout);
      if (response != null && response.isNotEmpty) {
        final cleaned = _cleanResponse(response, maxLength: 40);
        if (cleaned.isNotEmpty) {
          debugPrint('[LLMResponse] 告别回复: $cleaned');
          return cleaned;
        }
      }
    } catch (e) {
      debugPrint('[LLMResponse] 告别回复生成失败: $e');
    }

    return _fallbackFarewellResponse(farewellType);
  }

  /// 告别模板回复（降级方案）
  String _fallbackFarewellResponse(String farewellType) {
    final hour = DateTime.now().hour;
    final random = DateTime.now().millisecond;

    List<String> templates;
    switch (farewellType) {
      case 'userEnd':
        templates = [
          '拜拜~记得常来记账哦',
          '好的，下次见~',
          '再见啦，祝你开心',
        ];
        break;
      case 'silenceTimeout':
        templates = [
          '你不说话我就先休息啦，随时可以叫我~',
          '那我先休息咯，有事叫我~',
          '先不打扰你啦，回头见~',
        ];
        break;
      default:
        templates = [
          '好的，有需要随时叫我~',
          '下次再聊~',
          '好嘞，有事叫我~',
        ];
    }

    // 深夜特殊关心
    if (hour >= 22 || hour < 5) {
      templates = [
        '这么晚了，早点休息哦~',
        '夜深了，记得早点睡~',
        '好的，晚安~',
      ];
    }

    return templates[random % templates.length];
  }

  /// 生成错误/异常回复
  Future<String> generateErrorResponse({
    required String errorType,
    String? errorDetail,
    String? userInput,
  }) async {
    if (!isAvailable) {
      return _fallbackErrorResponse(errorType, errorDetail);
    }

    try {
      final prompt = '''
你是一个友好的记账助手。用户的操作遇到了问题，请用温和、口语化的方式回复。

错误类型：$errorType
${errorDetail != null ? '详情：$errorDetail' : ''}
${userInput != null ? '用户说的是：$userInput' : ''}

要求：
1. 简短（20字以内）
2. 口语化、亲切
3. 如果可能，给出简单建议
4. 不要说"抱歉"太多次

直接输出回复内容：''';

      final response = await _qwenService.chat(prompt).timeout(_timeout);
      if (response != null && response.isNotEmpty) {
        return _cleanResponse(response);
      }
    } catch (e) {
      debugPrint('[LLMResponse] 错误回复生成失败: $e');
    }

    return _fallbackErrorResponse(errorType, errorDetail);
  }

  // ═══════════════════════════════════════════════════════════════
  // Prompt 构建
  // ═══════════════════════════════════════════════════════════════

  String _buildTransactionPrompt(List<TransactionInfo> transactions, String userInput) {
    final txList = transactions.map((tx) {
      final type = tx.isIncome ? '收入' : '支出';
      return '$type ${tx.amount}元 ${tx.category.localizedCategoryName}${tx.merchant != null ? ' (${tx.merchant})' : ''}';
    }).join('、');

    return '''
你是一个可爱的记账助手白记。用户刚才通过语音记录了一笔账，请用简短、口语化、活泼的方式确认。

用户说：$userInput
记录内容：$txList

要求：
1. 简短（15字以内最好，最多25字）
2. 口语化，像朋友聊天
3. 可以用语气词如"嗯"、"好的呀"、"记好啦"等
4. 不要重复所有详情，简单提一下金额或类别即可
5. 偶尔可以加一句贴心的话（如"记得适度消费哦"）但不要每次都加

直接输出回复内容，不要加引号：''';
  }

  String _buildGeneralPrompt(String action, String result, bool success, String? userInput) {
    return '''
你是一个友好的记账助手白记。请根据操作结果，用简短、口语化的方式回复用户。

操作：$action
结果：$result
是否成功：${success ? '是' : '否'}
${userInput != null ? '用户说的是：$userInput' : ''}

要求：
1. 简短（15-20字）
2. 口语化、亲切
3. 成功时语气轻快，失败时温和安慰
4. 不要太啰嗦

直接输出回复内容：''';
  }

  // ═══════════════════════════════════════════════════════════════
  // 模板回复（降级方案）
  // ═══════════════════════════════════════════════════════════════

  String _fallbackTransactionResponse(List<TransactionInfo> transactions) {
    if (transactions.isEmpty) {
      return '没有识别到有效的记账信息';
    }

    if (transactions.length == 1) {
      final tx = transactions.first;
      final type = tx.isIncome ? '收入' : '支出';
      return '记好了，$type${tx.amount.toStringAsFixed(0)}元';
    }

    return '已记录${transactions.length}笔交易';
  }

  String _fallbackResponse(String action, String result, bool success) {
    if (success) {
      switch (action) {
        case '记账':
          return '记好了';
        case '删除':
          return '已删除';
        case '修改':
          return '已修改';
        case '查询':
          return result;
        default:
          return '操作完成';
      }
    } else {
      return '操作失败，请再试一次';
    }
  }

  String _fallbackErrorResponse(String errorType, String? errorDetail) {
    switch (errorType) {
      case 'network':
        return '网络不太好，稍后再试';
      case 'parse':
        return '没听清楚，再说一遍？';
      case 'duplicate':
        return '这笔好像已经记过了';
      case 'invalid':
        return errorDetail ?? '没有理解，换个说法试试？';
      default:
        return '出了点小问题，再试一次吧';
    }
  }

  /// 清理LLM响应
  String _cleanResponse(String response, {int maxLength = 50}) {
    // 移除引号、多余空白
    var cleaned = response.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned.startsWith("'") && cleaned.endsWith("'")) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    // 移除换行符，用空格替换（防止被SentenceBuffer分割成多个句子）
    cleaned = cleaned.replaceAll('\n', ' ').replaceAll('\r', ' ');
    // 合并多个空格为一个
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // 移除常见的LLM前缀（如"好的，让我来回复："等）
    final prefixPatterns = [
      RegExp(r'^(好的|OK|ok)[\s,，:：]*'),
      RegExp(r'^让我(来)?[\s,，]*'),
      RegExp(r'^我来[\s,，]*'),
      RegExp(r'^(下面是|以下是)[\s,，:：]*'),
      RegExp(r'^回复[\s,，:：]*'),
      RegExp(r'^(生成|输出)[\s,，:：]*'),
    ];
    for (final pattern in prefixPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }

    // 限制长度
    cleaned = cleaned.trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned.trim();
  }
}

/// 交易信息（用于生成回复）
class TransactionInfo {
  final double amount;
  final String category;
  final bool isIncome;
  final String? merchant;
  final String? description;

  TransactionInfo({
    required this.amount,
    required this.category,
    this.isIncome = false,
    this.merchant,
    this.description,
  });
}
