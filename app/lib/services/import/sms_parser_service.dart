import 'dart:convert';
import '../../models/sms_message.dart';
import '../../models/parsed_transaction.dart';
import '../../models/import_candidate.dart';
import '../ai_service.dart';
import 'wechat_bill_parser.dart';
import 'import_exceptions.dart';

/// 短信解析服务
/// 负责使用AI解析短信内容并转换为ImportCandidate
class SmsParserService {
  final AIService _aiService;
  final WechatBillParser _billParser; // 用于调用inferCategory

  SmsParserService({AIService? aiService})
      : _aiService = aiService ?? AIService(),
        _billParser = WechatBillParser();

  /// 批量解析短信
  ///
  /// [messages] 短信列表
  /// [batchSize] 每批处理数量
  /// [onProgress] 进度回调
  Future<List<ParsedTransaction?>> parseBatch(
    List<SmsMessage> messages, {
    int batchSize = 15,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <ParsedTransaction?>[];
    int totalParsed = 0;
    int totalFailed = 0;

    // 分批处理
    for (int i = 0; i < messages.length; i += batchSize) {
      final batch = messages.skip(i).take(batchSize).toList();

      try {
        final batchResults = await _parseSmsBatch(batch);
        results.addAll(batchResults);

        // 统计成功和失败数量
        for (final result in batchResults) {
          if (result != null) {
            totalParsed++;
          } else {
            totalFailed++;
          }
        }
      } catch (e) {
        // 批次解析失败，添加null
        results.addAll(List.filled(batch.length, null));
        totalFailed += batch.length;
      }

      onProgress?.call(i + batch.length, messages.length);
    }

    // 如果所有短信都解析失败，抛出异常
    if (totalParsed == 0 && totalFailed > 0) {
      throw AIParseException(
        message: '所有短信解析失败，请检查网络连接或稍后重试',
        parsedCount: 0,
        failedCount: totalFailed,
      );
    }

    // 如果部分失败，但有成功的，记录警告但继续
    if (totalFailed > 0 && totalParsed > 0) {
      // 可以在这里记录日志
      // 部分短信解析失败，但继续处理成功的部分
    }

    return results;
  }

  /// 解析单批短信（调用AI）
  Future<List<ParsedTransaction?>> _parseSmsBatch(
    List<SmsMessage> messages,
  ) async {
    final prompt = _buildPrompt(messages);

    try {
      final response = await _aiService.chat(prompt);
      return _parseAIResponse(response, messages);
    } on NetworkException {
      rethrow; // 重新抛出网络异常
    } catch (e) {
      // 其他错误转换为网络异常
      throw NetworkException(
        'AI服务调用失败',
        originalError: e,
      );
    }
  }

  /// 构建AI Prompt
  String _buildPrompt(List<SmsMessage> messages) {
    final smsListText = messages
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. [发件人: ${e.value.address}] ${e.value.body}')
        .join('\n');

    return '''
你是一个专业的交易记录解析助手。请从以下短信中提取交易信息，返回JSON数组格式。

短信列表：
$smsListText

要求：
- 只提取交易相关的短信，忽略验证码、广告、通知等非交易信息
- 每条交易包含以下字段：
  - amount（金额，数字类型）
  - type（类型："income"表示收入，"expense"表示支出）
  - date（日期，ISO 8601格式，如"2024-01-20T10:30:00"）
  - merchant（商户名称，字符串）
  - note（备注说明，字符串）
  - category（分类ID，如"food_drink"、"transport_taxi"、"shopping_clothing"等）
- 如果短信不包含交易信息，返回null
- 返回格式必须是JSON数组：[{...}, {...}, null, ...]
- 数组长度必须与短信数量一致
- 分类ID参考：
  - 餐饮美食: food_drink
  - 交通出行: transport_taxi, transport_metro, transport_bus
  - 购物消费: shopping_clothing, shopping_electronics, shopping_daily
  - 生活服务: life_utilities, life_rent, life_medical
  - 娱乐休闲: entertainment_movie, entertainment_game
  - 其他: other

请直接返回JSON数组，不要包含任何其他文字说明。
''';
  }

  /// 解析AI响应
  List<ParsedTransaction?> _parseAIResponse(
    String response,
    List<SmsMessage> messages,
  ) {
    try {
      // 提取JSON内容（可能包含在markdown代码块中）
      String jsonText = response.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final jsonList = jsonDecode(jsonText) as List;
      final results = <ParsedTransaction?>[];

      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        if (item == null) {
          results.add(null);
        } else {
          final originalSms = i < messages.length ? messages[i].body : '';
          results.add(ParsedTransaction.fromJson(item as Map<String, dynamic>, originalSms));
        }
      }

      return results;
    } catch (e) {
      // 解析失败，返回null列表
      return List.filled(messages.length, null);
    }
  }

  /// 转换为ImportCandidate
  ImportCandidate toImportCandidate(
    ParsedTransaction transaction,
    int index,
  ) {
    // 分类推断：AI直接分类 + 规则兜底
    String category = transaction.category ?? '';

    // 如果AI未返回分类或分类无效，使用规则引擎兜底
    if (category.isEmpty || !_isValidCategory(category)) {
      category = _billParser.inferCategory(
        transaction.merchant,
        transaction.note,
        transaction.type,
      );
    }

    return ImportCandidate(
      index: index,
      amount: transaction.amount,
      type: transaction.type,
      date: transaction.date,
      rawMerchant: transaction.merchant,
      note: transaction.note,
      category: category,
      action: ImportAction.import_, // 默认导入
      rawData: {
        'source': '短信导入',
        'originalSms': transaction.originalSmsBody,
      },
    );
  }

  /// 验证分类ID是否有效
  bool _isValidCategory(String categoryId) {
    return categoryId.isNotEmpty && !categoryId.startsWith('unknown');
  }
}
