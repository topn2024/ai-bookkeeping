import 'package:flutter/foundation.dart';

import '../../../models/email_account.dart';
import '../../../models/import_candidate.dart';
import '../../../models/transaction.dart';
import '../duplicate_scorer.dart';
import '../import_exceptions.dart';
import 'email_imap_service.dart';
import 'cmb_credit_card_bill_parser.dart';
import 'email_attachment_extractor.dart';
import 'email_credential_service.dart';

/// 邮箱导入结果
class EmailImportResult {
  final List<ImportCandidate> candidates;
  final int totalEmailsFound;
  final int totalEmailsFetched;
  final int parseSuccessCount;
  final int parseFailCount;
  final List<String> errors;

  EmailImportResult({
    required this.candidates,
    required this.totalEmailsFound,
    required this.totalEmailsFetched,
    this.parseSuccessCount = 0,
    this.parseFailCount = 0,
    this.errors = const [],
  });
}

/// 邮箱导入流程编排
/// 协调 IMAP 连接、搜索、下载、解析、去重的完整流程
class EmailBillDispatcher {
  final EmailImapService _imapService;
  final CmbCreditCardBillParser _cmbParser;
  final EmailAttachmentExtractor _attachmentExtractor;
  final DuplicateScorer _duplicateScorer;
  final EmailCredentialService _credentialService;

  EmailBillDispatcher({
    EmailImapService? imapService,
    CmbCreditCardBillParser? cmbParser,
    EmailAttachmentExtractor? attachmentExtractor,
    DuplicateScorer? duplicateScorer,
    EmailCredentialService? credentialService,
  })  : _imapService = imapService ?? EmailImapService(),
        _cmbParser = cmbParser ?? CmbCreditCardBillParser(),
        _attachmentExtractor = attachmentExtractor ?? EmailAttachmentExtractor(),
        _duplicateScorer = duplicateScorer ?? DuplicateScorer(),
        _credentialService = credentialService ?? EmailCredentialService();

  /// 执行邮箱导入
  ///
  /// [account] 邮箱账户
  /// [startDate] 搜索起始日期
  /// [endDate] 搜索结束日期
  /// [senderFilter] 可选的发件人过滤列表
  /// [onProgress] 进度回调 (stage, current, total, message)
  Future<EmailImportResult> importFromEmail({
    required EmailAccount account,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? senderFilter,
    String? zipPassword,
    void Function(String stage, int current, int total, String? message)? onProgress,
  }) async {
    final errors = <String>[];

    // 阶段1: 连接服务器
    onProgress?.call('connecting', 0, 1, '正在连接 ${account.providerName}...');
    try {
      await _imapService.connect(account);
    } on EmailAuthException {
      rethrow;
    } on EmailConnectionException {
      rethrow;
    }
    onProgress?.call('connecting', 1, 1, '已连接');

    try {
      // 阶段2: 搜索邮件
      onProgress?.call('searching', 0, 1, '正在搜索账单邮件...');
      final sequenceNumbers = await _imapService.searchBillEmails(
        startDate: startDate,
        endDate: endDate,
        senderFilter: senderFilter,
      );
      onProgress?.call('searching', 1, 1, '找到 ${sequenceNumbers.length} 封邮件');

      if (sequenceNumbers.isEmpty) {
        await _imapService.disconnect();
        return EmailImportResult(
          candidates: [],
          totalEmailsFound: 0,
          totalEmailsFetched: 0,
        );
      }

      // 阶段3: 下载邮件
      debugPrint('[EmailBillDispatcher] 开始下载 ${sequenceNumbers.length} 封邮件');
      onProgress?.call('fetching', 0, sequenceNumbers.length, '正在下载邮件...');
      var messages = await _imapService.fetchMessages(
        sequenceNumbers,
        onProgress: (current, total) {
          onProgress?.call('fetching', current, total, '下载中 $current/$total');
        },
      );

      // 本地过滤 endDate（因为 QQ IMAP BEFORE+FROM 组合有 bug，SEARCH 只用了 SINCE）
      final endCutoff = endDate.add(const Duration(days: 1));
      messages = messages.where((m) => m.date.isBefore(endCutoff)).toList();
      debugPrint('[EmailBillDispatcher] 日期过滤后: ${messages.length} 封邮件');

      // 阶段4: 解析账单
      onProgress?.call('parsing', 0, messages.length, '正在解析账单...');
      final allCandidates = <ImportCandidate>[];
      int parseSuccess = 0;
      int parseFail = 0;

      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        debugPrint('[EmailBillDispatcher] 处理邮件 ${i+1}/${messages.length}: "${message.subject}" from=${message.senderAddress} 附件=${message.attachments.length}个 hasHtml=${message.htmlBody != null}');
        try {
          final candidates = await _dispatchMessage(message, allCandidates.length, zipPassword: zipPassword);
          debugPrint('[EmailBillDispatcher] 邮件 "${message.subject}" 解析出 ${candidates.length} 条记录');
          allCandidates.addAll(candidates);
          if (candidates.isNotEmpty) {
            parseSuccess++;
          }
        } catch (e) {
          debugPrint('[EmailBillDispatcher] 邮件 "${message.subject}" 解析失败: $e');
          parseFail++;
          errors.add('解析邮件 "${message.subject}" 失败: $e');
        }
        onProgress?.call('parsing', i + 1, messages.length, '解析中 ${i + 1}/${messages.length}');
      }

      // 阶段5: 检查重复
      if (allCandidates.isNotEmpty) {
        onProgress?.call('checking', 0, allCandidates.length, '正在检查重复...');
        await _duplicateScorer.checkDuplicates(
          allCandidates,
          externalSource: ExternalSource.email,
          onProgress: (current, total) {
            onProgress?.call('checking', current, total, '检查重复 $current/$total');
          },
        );
      }

      // 更新最后同步时间
      await _credentialService.updateLastSyncTime(account.id);

      return EmailImportResult(
        candidates: allCandidates,
        totalEmailsFound: sequenceNumbers.length,
        totalEmailsFetched: messages.length,
        parseSuccessCount: parseSuccess,
        parseFailCount: parseFail,
        errors: errors,
      );
    } finally {
      await _imapService.disconnect();
    }
  }

  /// 根据发件人路由到不同的解析器
  Future<List<ImportCandidate>> _dispatchMessage(
    EmailMessage message,
    int startIndex, {
    String? zipPassword,
  }) async {
    final sender = message.senderAddress.toLowerCase();

    // 招行信用卡账单
    if (sender.contains('cmbchina.com') || sender.contains('招商银行')) {
      return await _cmbParser.parseHtmlBill(message, startIndex);
    }

    // 微信/支付宝 CSV 附件
    if (sender.contains('tenpay.com') || sender.contains('alipay.com')) {
      return await _attachmentExtractor.extractAndParse(message, startIndex, zipPassword: zipPassword);
    }

    // 未知发件人 - 同时尝试 HTML 解析和附件提取
    final candidates = <ImportCandidate>[];

    // 先尝试附件
    if (message.attachments.isNotEmpty) {
      final attachmentCandidates = await _attachmentExtractor.extractAndParse(
        message,
        startIndex + candidates.length,
      );
      candidates.addAll(attachmentCandidates);
    }

    // 再尝试 HTML 解析
    if (candidates.isEmpty && message.htmlBody != null) {
      final htmlCandidates = await _cmbParser.parseHtmlBill(
        message,
        startIndex + candidates.length,
      );
      candidates.addAll(htmlCandidates);
    }

    return candidates;
  }
}
