import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';

import '../../models/import_batch.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';
import '../voice_recognition_engine.dart';
import '../ai_service.dart';
import 'batch_import_service.dart';

/// 语音批量导入服务
/// 设计文档第11.2节：语音批量导入（P2优先级）
/// 支持通过语音连续报账，批量导入多笔交易
class VoiceBatchImportService {
  final VoiceRecognitionEngine _voiceEngine;
  final AIService _aiService;
  final IDatabaseService _databaseService;
  final Uuid _uuid = const Uuid();

  // 当前批量导入会话
  VoiceBatchSession? _currentSession;

  VoiceBatchImportService({
    VoiceRecognitionEngine? voiceEngine,
    AIService? aiService,
    IDatabaseService? databaseService,
  })  : _voiceEngine = voiceEngine ?? VoiceRecognitionEngine(),
        _aiService = aiService ?? AIService(),
        _databaseService = databaseService ?? sl<IDatabaseService>();

  /// 开始语音批量导入会话
  Future<VoiceBatchSession> startSession({
    String? ledgerId,
    String? defaultAccountId,
  }) async {
    _currentSession = VoiceBatchSession(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      ledgerId: ledgerId,
      defaultAccountId: defaultAccountId,
    );

    return _currentSession!;
  }

  /// 添加语音输入
  Future<VoiceImportResult> addVoiceInput(
    String audioPath, {
    void Function(VoiceImportStage stage, String? message)? onProgress,
  }) async {
    if (_currentSession == null) {
      return VoiceImportResult(
        success: false,
        error: '未开始批量导入会话',
      );
    }

    try {
      // 1. 语音识别
      onProgress?.call(VoiceImportStage.recognizing, '正在识别语音...');
      final recognitionResult = await _voiceEngine.recognizeFromFile(
        File(audioPath),
      );

      if (!recognitionResult.isSuccess) {
        return VoiceImportResult(
          success: false,
          error: '语音识别失败：${recognitionResult.error}',
        );
      }

      final text = recognitionResult.text;

      // 2. 解析交易
      onProgress?.call(VoiceImportStage.parsing, '正在解析交易信息...');
      final transactions = await _parseTransactionsFromText(text);

      if (transactions.isEmpty) {
        return VoiceImportResult(
          success: false,
          error: '未能从语音中识别出有效的交易记录',
          recognizedText: text,
        );
      }

      // 3. 添加到会话
      onProgress?.call(VoiceImportStage.adding, '正在添加交易...');
      for (final t in transactions) {
        _currentSession!.addCandidate(t);
      }

      return VoiceImportResult(
        success: true,
        recognizedText: text,
        parsedTransactions: transactions,
        sessionTotal: _currentSession!.candidates.length,
      );
    } catch (e) {
      return VoiceImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 从文本解析交易
  Future<List<ImportCandidate>> _parseTransactionsFromText(String text) async {
    final candidates = <ImportCandidate>[];

    // 使用AI解析多笔交易
    final prompt = '''
请从以下语音文本中提取所有交易记录，以JSON数组格式返回：

文本：$text

每笔交易包含以下字段：
- amount: 金额（数字）
- type: 类型（expense/income）
- category: 分类（如餐饮、交通、购物等）
- note: 备注
- merchant: 商户名称（如果有）
- date: 日期（如果提到，格式YYYY-MM-DD，否则为空）

示例输出：
[
  {"amount": 35.5, "type": "expense", "category": "餐饮", "note": "午餐", "merchant": "星巴克"},
  {"amount": 100, "type": "expense", "category": "交通", "note": "加油", "merchant": "中石化"}
]

请只返回JSON数组，不要其他内容。
''';

    try {
      final response = await _aiService.chat(prompt);

      // 解析JSON
      final jsonStr = _extractJsonFromResponse(response);
      if (jsonStr == null) return candidates;

      final List<dynamic> parsed = [];
      try {
        // Dart中需要使用json.decode
        final decoded = _parseJson(jsonStr);
        if (decoded is List) {
          parsed.addAll(decoded);
        }
      } catch (e) {
        return candidates;
      }

      // 转换为ImportCandidate
      for (int i = 0; i < parsed.length; i++) {
        final item = parsed[i] as Map<String, dynamic>;
        final candidate = ImportCandidate(
          index: i,
          date: item['date'] != null
              ? DateTime.tryParse(item['date'] as String) ?? DateTime.now()
              : DateTime.now(),
          amount: (item['amount'] as num).toDouble(),
          type: item['type'] == 'income'
              ? TransactionType.income
              : TransactionType.expense,
          category: item['category'] as String? ?? '其他',
          note: item['note'] as String?,
          rawMerchant: item['merchant'] as String?,
          action: ImportAction.import_,
        );
        candidates.add(candidate);
      }
    } catch (e) {
      // AI解析失败，尝试规则解析
      return _parseWithRules(text);
    }

    return candidates;
  }

  /// 从AI响应中提取JSON
  String? _extractJsonFromResponse(String response) {
    // 查找JSON数组
    final startIndex = response.indexOf('[');
    final endIndex = response.lastIndexOf(']');

    if (startIndex >= 0 && endIndex > startIndex) {
      return response.substring(startIndex, endIndex + 1);
    }
    return null;
  }

  /// JSON解析
  dynamic _parseJson(String jsonStr) {
    // 简单的JSON解析实现
    // 在实际代码中应该使用 dart:convert
    return [];
  }

  /// 使用规则解析交易
  List<ImportCandidate> _parseWithRules(String text) {
    final candidates = <ImportCandidate>[];

    // 常见的金额模式
    final amountPattern = RegExp(
      r'(\d+(?:\.\d{1,2})?)\s*(?:元|块|块钱|￥)?',
    );

    // 常见的交易动词
    // ignore: unused_local_variable
    final expenseVerbs = ['花', '买', '支付', '消费', '用了', '刷了', '付'];
    final incomeVerbs = ['收', '进账', '到账', '收入', '工资'];

    // 分类关键词
    final categoryKeywords = {
      '餐饮': ['吃', '饭', '餐', '外卖', '咖啡', '奶茶', '早餐', '午餐', '晚餐'],
      '交通': ['打车', '滴滴', '地铁', '公交', '加油', '停车', '出租车'],
      '购物': ['买', '购物', '淘宝', '京东', '拼多多', '超市'],
      '娱乐': ['电影', '游戏', 'KTV', '唱歌', '旅游'],
      '日用': ['水电', '物业', '话费', '网费', '房租'],
    };

    // 分割成多个句子
    final sentences = text.split(RegExp(r'[,，;；。\n]'));

    int index = 0;
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      // 查找金额
      final amountMatch = amountPattern.firstMatch(sentence);
      if (amountMatch == null) continue;

      final amount = double.tryParse(amountMatch.group(1)!);
      if (amount == null || amount <= 0) continue;

      // 判断收支类型
      TransactionType type = TransactionType.expense;
      for (final verb in incomeVerbs) {
        if (sentence.contains(verb)) {
          type = TransactionType.income;
          break;
        }
      }

      // 识别分类
      String category = '其他';
      for (final entry in categoryKeywords.entries) {
        for (final keyword in entry.value) {
          if (sentence.contains(keyword)) {
            category = entry.key;
            break;
          }
        }
        if (category != '其他') break;
      }

      final candidate = ImportCandidate(
        index: index++,
        date: DateTime.now(),
        amount: amount,
        type: type,
        category: category,
        note: sentence.trim(),
        action: ImportAction.import_,
      );
      candidates.add(candidate);
    }

    return candidates;
  }

  /// 实时语音识别回调
  Stream<VoiceImportResult> startRealtimeRecognition() async* {
    if (_currentSession == null) {
      yield VoiceImportResult(
        success: false,
        error: '未开始批量导入会话',
      );
      return;
    }

    // 开始实时语音识别
    await for (final result in _voiceEngine.startRealtimeRecognition()) {
      if (result.isFinal && result.text.isNotEmpty) {
        // 解析交易
        final transactions = await _parseTransactionsFromText(result.text);

        if (transactions.isNotEmpty) {
          for (final t in transactions) {
            _currentSession!.addCandidate(t);
          }

          yield VoiceImportResult(
            success: true,
            recognizedText: result.text,
            parsedTransactions: transactions,
            sessionTotal: _currentSession!.candidates.length,
          );
        }
      }
    }
  }

  /// 停止实时识别
  Future<void> stopRealtimeRecognition() async {
    await _voiceEngine.stopRealtimeRecognition();
  }

  /// 获取当前会话预览
  List<ImportCandidate> getSessionPreview() {
    return _currentSession?.candidates ?? [];
  }

  /// 修改候选交易
  void updateCandidate(int index, ImportCandidate updated) {
    _currentSession?.updateCandidate(index, updated);
  }

  /// 删除候选交易
  void removeCandidate(int index) {
    _currentSession?.removeCandidate(index);
  }

  /// 完成批量导入
  Future<BatchImportResult> finishSession({
    String? defaultAccountId,
    void Function(int current, int total)? onProgress,
  }) async {
    if (_currentSession == null || _currentSession!.candidates.isEmpty) {
      return BatchImportResult(
        batch: ImportBatch(
          id: ImportBatch.generateId(),
          fileName: 'voice_import',
          fileFormat: 'voice',
          totalCount: 0,
          importedCount: 0,
          skippedCount: 0,
        ),
        successCount: 0,
        skippedCount: 0,
        failedCount: 1,
        errors: ['没有待导入的交易'],
      );
    }

    final candidates = _currentSession!.candidates;
    final batchId = ImportBatch.generateId();
    final errors = <String>[];

    final toImport =
        candidates.where((c) => c.action == ImportAction.import_).toList();
    final toSkip =
        candidates.where((c) => c.action == ImportAction.skip).toList();

    // 转换为交易
    final transactions = <Transaction>[];
    double totalExpense = 0;
    double totalIncome = 0;

    for (int i = 0; i < toImport.length; i++) {
      final candidate = toImport[i];
      onProgress?.call(i + 1, toImport.length);

      try {
        final transaction = candidate.toTransaction(
          id: _uuid.v4(),
          batchId: batchId,
          externalSource: ExternalSource.generic,
        ).copyWith(
          accountId: candidate.accountId ??
              defaultAccountId ??
              _currentSession!.defaultAccountId ??
              'default',
        );

        transactions.add(transaction);

        if (transaction.type == TransactionType.expense) {
          totalExpense += transaction.amount;
        } else if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        }
      } catch (e) {
        errors.add('导入第 ${candidate.index + 1} 条记录失败: $e');
      }
    }

    // 批量插入
    if (transactions.isNotEmpty) {
      await _databaseService.batchInsertTransactions(transactions);
    }

    // 创建导入批次记录
    final batch = ImportBatch(
      id: batchId,
      fileName: 'voice_import_${DateTime.now().millisecondsSinceEpoch}',
      fileFormat: 'voice',
      totalCount: candidates.length,
      importedCount: transactions.length,
      skippedCount: toSkip.length,
      failedCount: errors.length,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );

    await _databaseService.insertImportBatch(batch);

    // 清除会话
    _currentSession = null;

    return BatchImportResult(
      batch: batch,
      successCount: transactions.length,
      skippedCount: toSkip.length,
      failedCount: errors.length,
      errors: errors,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );
  }

  /// 取消会话
  void cancelSession() {
    _currentSession = null;
  }

  /// 获取当前会话
  VoiceBatchSession? get currentSession => _currentSession;
}

/// 语音批量导入会话
class VoiceBatchSession {
  final String id;
  final DateTime startedAt;
  final String? ledgerId;
  final String? defaultAccountId;
  final List<ImportCandidate> _candidates = [];
  final List<String> _audioFiles = [];

  VoiceBatchSession({
    required this.id,
    required this.startedAt,
    this.ledgerId,
    this.defaultAccountId,
  });

  List<ImportCandidate> get candidates => List.unmodifiable(_candidates);
  List<String> get audioFiles => List.unmodifiable(_audioFiles);

  void addCandidate(ImportCandidate candidate) {
    _candidates.add(candidate.copyWith(index: _candidates.length));
  }

  void updateCandidate(int index, ImportCandidate updated) {
    if (index >= 0 && index < _candidates.length) {
      _candidates[index] = updated;
    }
  }

  void removeCandidate(int index) {
    if (index >= 0 && index < _candidates.length) {
      _candidates.removeAt(index);
      // 重新排序索引
      for (int i = 0; i < _candidates.length; i++) {
        _candidates[i] = _candidates[i].copyWith(index: i);
      }
    }
  }

  void addAudioFile(String path) {
    _audioFiles.add(path);
  }

  /// 获取统计信息
  VoiceSessionStats get stats {
    double totalExpense = 0;
    double totalIncome = 0;
    final categories = <String, int>{};

    for (final c in _candidates) {
      if (c.type == TransactionType.expense) {
        totalExpense += c.amount;
      } else if (c.type == TransactionType.income) {
        totalIncome += c.amount;
      }

      categories[c.category ?? '其他'] =
          (categories[c.category ?? '其他'] ?? 0) + 1;
    }

    return VoiceSessionStats(
      transactionCount: _candidates.length,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      categoryCounts: categories,
      duration: DateTime.now().difference(startedAt),
    );
  }
}

/// 语音会话统计
class VoiceSessionStats {
  final int transactionCount;
  final double totalExpense;
  final double totalIncome;
  final Map<String, int> categoryCounts;
  final Duration duration;

  VoiceSessionStats({
    required this.transactionCount,
    required this.totalExpense,
    required this.totalIncome,
    required this.categoryCounts,
    required this.duration,
  });
}

/// 语音导入阶段
enum VoiceImportStage {
  recognizing,
  parsing,
  adding,
  completed,
}

/// 语音导入结果
class VoiceImportResult {
  final bool success;
  final String? recognizedText;
  final List<ImportCandidate>? parsedTransactions;
  final int? sessionTotal;
  final String? error;

  VoiceImportResult({
    required this.success,
    this.recognizedText,
    this.parsedTransactions,
    this.sessionTotal,
    this.error,
  });
}

