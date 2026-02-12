import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../models/email_account.dart';
import '../import_exceptions.dart';

/// 邮件消息模型
class EmailMessage {
  final String messageId;
  final String subject;
  final String senderAddress;
  final DateTime date;
  final String? htmlBody;
  final String? textBody;
  final List<EmailAttachment> attachments;

  EmailMessage({
    required this.messageId,
    required this.subject,
    required this.senderAddress,
    required this.date,
    this.htmlBody,
    this.textBody,
    this.attachments = const [],
  });
}

/// 邮件附件模型
class EmailAttachment {
  final String filename;
  final String mimeType;
  final Uint8List data;

  EmailAttachment({
    required this.filename,
    required this.mimeType,
    required this.data,
  });
}

/// 账单邮件发件人常量
class BillEmailSenders {
  // 招行信用卡 - 两个常见发件地址
  static const cmbCreditCard = 'creditcard@cmbchina.com';
  static const cmbDaily = 'ccsvc@message.cmbchina.com';
  // 微信支付
  static const wechatPay = 'wechatpay-noreply@tenpay.com';
  // 支付宝
  static const alipay = 'service@mail.alipay.com';

  static const all = [cmbCreditCard, cmbDaily, wechatPay, alipay];
}

/// 文件夹内邮件定位
class _FolderMessage {
  final String folder;
  final int sequenceNumber;
  _FolderMessage(this.folder, this.sequenceNumber);
}

/// IMAP 邮件服务
/// 使用 dart:io SecureSocket 直接实现 IMAP 协议
class EmailImapService {
  SecureSocket? _socket;
  int _tagCounter = 0;
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription? _subscription;
  Completer<String>? _responseCompleter;
  String _currentFolder = '';

  /// 连接邮箱服务器
  Future<void> connect(EmailAccount account) async {
    try {
      debugPrint('[EmailImapService] 正在连接 ${account.imapHost}:${account.imapPort}...');
      _socket = await SecureSocket.connect(
        account.imapHost,
        account.imapPort,
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[EmailImapService] SSL连接成功');

      // 读取服务器问候语
      _setupListenerSync();
      await _waitForGreeting();
      debugPrint('[EmailImapService] 收到服务器问候语');

      // 登录
      debugPrint('[EmailImapService] 正在登录...');
      final loginResponse = await _sendCommand(
        'LOGIN "${_escapeImapString(account.emailAddress)}" "${_escapeImapString(account.authCode)}"',
      );

      if (!loginResponse.contains('OK')) {
        debugPrint('[EmailImapService] 登录失败: $loginResponse');
        await disconnect();
        throw EmailAuthException('授权码验证失败，请检查邮箱地址和授权码');
      }
      debugPrint('[EmailImapService] 登录成功');
    } on EmailAuthException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[EmailImapService] SocketException: $e');
      throw EmailConnectionException(
        '无法连接到邮箱服务器 ${account.imapHost}',
        originalError: e,
      );
    } on HandshakeException catch (e) {
      debugPrint('[EmailImapService] HandshakeException: $e');
      throw EmailConnectionException(
        'SSL握手失败',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      debugPrint('[EmailImapService] TimeoutException: $e');
      throw EmailConnectionException(
        '连接超时，请检查网络',
        originalError: e,
      );
    } catch (e) {
      debugPrint('[EmailImapService] 连接异常: $e');
      if (e is EmailConnectionException) rethrow;
      throw EmailConnectionException(
        '连接失败: $e',
        originalError: e,
      );
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (_socket != null) {
        await _sendCommand('LOGOUT').timeout(
          const Duration(seconds: 5),
          onTimeout: () => '',
        );
      }
    } catch (_) {
      // 忽略断开连接时的错误
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _socket?.destroy();
      _socket = null;
      _buffer.clear();
    }
  }

  /// 列出所有可搜索的文件夹
  Future<List<String>> _listFolders() async {
    final response = await _sendCommand('LIST "" "*"');
    final folders = <String>[];
    final lines = response.split('\r\n');
    for (final line in lines) {
      if (!line.startsWith('* LIST')) continue;
      // 跳过 \NoSelect 文件夹
      if (line.contains('\\NoSelect')) continue;
      // 提取文件夹名：最后一个空格后的引号内容或无引号字符串
      final match = RegExp(r'"([^"]+)"$|(\S+)$').firstMatch(line);
      if (match != null) {
        final folder = match.group(1) ?? match.group(2) ?? '';
        if (folder.isNotEmpty) folders.add(folder);
      }
    }
    debugPrint('[EmailImapService] 发现 ${folders.length} 个文件夹: $folders');
    return folders;
  }

  /// 选择文件夹
  Future<bool> _selectFolder(String folder) async {
    if (_currentFolder == folder) return true;
    try {
      final response = await _sendCommand('SELECT "$folder"');
      if (response.contains('OK')) {
        _currentFolder = folder;
        return true;
      }
    } catch (e) {
      debugPrint('[EmailImapService] 选择文件夹 "$folder" 失败: $e');
    }
    return false;
  }

  /// 搜索账单邮件（跨所有文件夹）
  Future<List<_FolderMessage>> searchBillEmailsAcrossFolders({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? senderFilter,
  }) async {
    if (_socket == null) {
      throw EmailConnectionException('未连接到邮箱服务器');
    }

    final senders = senderFilter ?? BillEmailSenders.all;
    final sinceDate = _formatImapDate(startDate);
    final allResults = <_FolderMessage>[];

    // 列出所有文件夹
    final folders = await _listFolders();

    for (final folder in folders) {
      if (!await _selectFolder(folder)) continue;

      for (final sender in senders) {
        try {
          final cmd = 'SEARCH SINCE $sinceDate FROM "$sender"';
          final searchResponse = await _sendCommand(cmd);
          final numbers = _parseSearchResponse(searchResponse);
          if (numbers.isNotEmpty) {
            debugPrint('[EmailImapService] 文件夹 "$folder" 找到 ${numbers.length} 封来自 $sender');
            for (final n in numbers) {
              allResults.add(_FolderMessage(folder, n));
            }
          }
        } catch (e) {
          debugPrint('[EmailImapService] 搜索 "$folder" $sender 失败: $e');
        }
      }
    }

    debugPrint('[EmailImapService] 跨文件夹总共找到 ${allResults.length} 封账单邮件');
    return allResults;
  }

  /// 兼容旧接口 - 搜索账单邮件（返回 sequence numbers）
  Future<List<int>> searchBillEmails({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? senderFilter,
  }) async {
    // 委托给跨文件夹搜索，结果由 fetchMessagesFromFolders 处理
    final results = await searchBillEmailsAcrossFolders(
      startDate: startDate,
      endDate: endDate,
      senderFilter: senderFilter,
    );
    // 存储结果供 fetchMessages 使用
    _pendingFolderMessages = results;
    return List.generate(results.length, (i) => i); // 返回虚拟序号
  }

  List<_FolderMessage> _pendingFolderMessages = [];

  /// 批量获取邮件内容（支持跨文件夹）
  Future<List<EmailMessage>> fetchMessages(
    List<int> sequenceNumbers, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (_socket == null) {
      throw EmailConnectionException('未连接到邮箱服务器');
    }

    final messages = <EmailMessage>[];
    final total = _pendingFolderMessages.length;

    // 按文件夹分组以减少 SELECT 切换
    final byFolder = <String, List<int>>{};
    for (final fm in _pendingFolderMessages) {
      byFolder.putIfAbsent(fm.folder, () => []).add(fm.sequenceNumber);
    }

    int fetched = 0;
    for (final entry in byFolder.entries) {
      final folder = entry.key;
      final seqNums = entry.value;

      if (!await _selectFolder(folder)) {
        fetched += seqNums.length;
        continue;
      }

      const batchSize = 10;
      for (int i = 0; i < seqNums.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, seqNums.length);
        final batch = seqNums.sublist(i, end);
        final seqSet = batch.join(',');

        try {
          final fetchResponse = await _sendCommand(
            'FETCH $seqSet (ENVELOPE BODY[])',
            timeout: const Duration(seconds: 60),
          );

          final parsed = _parseFetchResponse(fetchResponse);
          messages.addAll(parsed);
        } catch (e) {
          debugPrint('[EmailImapService] Fetch batch failed in "$folder": $e');
        }

        fetched += batch.length;
        onProgress?.call(fetched.clamp(0, total), total);
      }
    }

    _pendingFolderMessages = [];
    return messages;
  }

  // === IMAP 协议实现 ===

  void _setupListenerSync() {
    _subscription = _socket!.listen(
      (data) {
        _buffer.write(utf8.decode(data, allowMalformed: true));
        _checkResponseComplete();
      },
      onError: (error) {
        _responseCompleter?.completeError(
          EmailConnectionException('连接中断', originalError: error),
        );
      },
      onDone: () {
        _responseCompleter?.completeError(
          EmailConnectionException('服务器关闭了连接'),
        );
      },
    );
  }

  Future<void> _waitForGreeting() async {
    // 等待服务器问候语（* OK ...）
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final content = _buffer.toString();
      if (content.contains('\r\n')) {
        debugPrint('[EmailImapService] 问候语: ${content.trim()}');
        _buffer.clear();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    throw EmailConnectionException('等待服务器响应超时');
  }

  Future<String> _sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final tag = 'A${++_tagCounter}';
    final fullCommand = '$tag $command\r\n';

    _buffer.clear();
    _responseCompleter = Completer<String>();

    _socket!.add(utf8.encode(fullCommand));
    await _socket!.flush();

    // 等待完整响应（以 tag 开头的行）
    try {
      final response = await _responseCompleter!.future.timeout(timeout);
      return response;
    } on TimeoutException {
      throw EmailConnectionException('命令执行超时: ${command.split(' ').first}');
    }
  }

  void _checkResponseComplete() {
    if (_responseCompleter == null || _responseCompleter!.isCompleted) return;

    final content = _buffer.toString();
    final tag = 'A$_tagCounter';

    // 检查是否包含完整的响应（以 tag OK/NO/BAD 结尾的行）
    final lines = content.split('\r\n');
    for (final line in lines) {
      if (line.startsWith('$tag ')) {
        _responseCompleter!.complete(content);
        return;
      }
    }
  }

  String _formatImapDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }

  String _escapeImapString(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  List<int> _parseSearchResponse(String response) {
    final numbers = <int>[];
    final lines = response.split('\r\n');
    for (final line in lines) {
      if (line.startsWith('* SEARCH')) {
        final parts = line.substring('* SEARCH'.length).trim().split(' ');
        for (final part in parts) {
          final num = int.tryParse(part.trim());
          if (num != null) numbers.add(num);
        }
      }
    }
    return numbers;
  }

  List<EmailMessage> _parseFetchResponse(String response) {
    final messages = <EmailMessage>[];

    // 按邮件边界分割响应
    final messageBlocks = _splitFetchBlocks(response);

    for (final block in messageBlocks) {
      try {
        final message = _parseMessageBlock(block);
        if (message != null) {
          messages.add(message);
        }
      } catch (e) {
        debugPrint('[EmailImapService] Failed to parse message: $e');
      }
    }

    return messages;
  }

  List<String> _splitFetchBlocks(String response) {
    final blocks = <String>[];
    final regex = RegExp(r'\* \d+ FETCH');
    final matches = regex.allMatches(response).toList();

    for (int i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : response.length;
      blocks.add(response.substring(start, end));
    }

    return blocks;
  }

  EmailMessage? _parseMessageBlock(String block) {
    // 优先从 ENVELOPE 结构提取（可靠），header regex 作为后备
    final subject = _extractFromEnvelope(block, 1) ??
        _extractHeaderFromBody(block, 'Subject') ??
        '(无主题)';
    final sender = _extractSenderFromEnvelope(block) ?? '';
    final dateStr = _extractFromEnvelope(block, 0);
    final messageId = _extractFromEnvelope(block, -1) ?? '${DateTime.now().millisecondsSinceEpoch}';

    DateTime date;
    if (dateStr != null) {
      date = _parseEmailDate(dateStr) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    // 提取 BODY 内容
    final bodyContent = _extractBodyContent(block);
    if (bodyContent == null) return null;

    // 解析 MIME 内容
    String? htmlBody;
    String? textBody;
    final attachments = <EmailAttachment>[];

    _parseMimeContent(bodyContent, (contentType, content, filename) {
      // 从当前 part 内容中提取 encoding（不是整个 block）
      final encoding = _extractEncoding(content, contentType);
      final lowerFilename = filename?.toLowerCase() ?? '';
      if (filename != null && (lowerFilename.endsWith('.csv') || lowerFilename.endsWith('.zip'))) {
        attachments.add(EmailAttachment(
          filename: filename,
          mimeType: contentType,
          data: _decodeContent(content, encoding),
        ));
      } else if (contentType.contains('text/html')) {
        htmlBody = _decodeTextContent(content, encoding);
      } else if (contentType.contains('text/plain') && textBody == null) {
        textBody = _decodeTextContent(content, encoding);
      }
    });

    return EmailMessage(
      messageId: messageId,
      subject: _decodeEncodedWord(subject),
      senderAddress: sender,
      date: date,
      htmlBody: htmlBody,
      textBody: textBody,
      attachments: attachments,
    );
  }

  /// 从 BODY 内容的邮件头部分提取字段（仅在 ENVELOPE 解析失败时使用）
  String? _extractHeaderFromBody(String block, String field) {
    // 先定位 BODY[] 内容
    final bodyStart = RegExp(r'BODY\[\]\s*\{\d+\}\r\n').firstMatch(block);
    if (bodyStart == null) return null;
    final headerSection = block.substring(bodyStart.end);
    // 邮件头以空行结束
    final headerEnd = headerSection.indexOf('\r\n\r\n');
    final headers = headerEnd > 0 ? headerSection.substring(0, headerEnd) : headerSection.substring(0, (headerSection.length).clamp(0, 2000));
    final regex = RegExp('^$field:\\s*(.+)', caseSensitive: false, multiLine: true);
    final match = regex.firstMatch(headers);
    return match?.group(1)?.trim();
  }

  String? _extractFromEnvelope(String block, int index) {
    final envelopeMatch = RegExp(r'ENVELOPE\s*\(').firstMatch(block);
    if (envelopeMatch == null) return null;

    // 简化的 ENVELOPE 解析 - 提取引号内的字段
    final start = envelopeMatch.end;
    final fields = <String>[];
    int pos = start;
    int depth = 0;
    bool inQuote = false;
    final current = StringBuffer();

    while (pos < block.length && (depth > 0 || fields.length <= 10)) {
      final char = block[pos];
      if (char == '"' && (pos == 0 || block[pos - 1] != '\\')) {
        inQuote = !inQuote;
        if (!inQuote) {
          fields.add(current.toString());
          current.clear();
        }
      } else if (inQuote) {
        current.write(char);
      } else if (char == '(') {
        depth++;
      } else if (char == ')') {
        if (depth == 0) break;
        depth--;
      }
      pos++;
    }

    if (index == -1) {
      return fields.isNotEmpty ? fields.last : null;
    }
    if (index >= 0 && index < fields.length) {
      return fields[index];
    }
    return null;
  }

  String? _extractSenderFromEnvelope(String block) {
    // 尝试从 From header 提取
    final fromMatch = RegExp(r'From:\s*.*?<([^>]+)>', caseSensitive: false).firstMatch(block);
    if (fromMatch != null) return fromMatch.group(1)?.toLowerCase();

    // 从 ENVELOPE 的 FROM 字段提取
    final envelopeMatch = RegExp(r'ENVELOPE\s*\(').firstMatch(block);
    if (envelopeMatch == null) return null;

    // ENVELOPE 中 FROM 是第三个字段（date, subject, from, sender, ...）
    // 格式：((name NIL mailbox host))
    final fromFieldMatch = RegExp(r'\(\((?:NIL|"[^"]*")\s+(?:NIL|"[^"]*")\s+"([^"]*)"\s+"([^"]*)"\)\)').firstMatch(
      block.substring(envelopeMatch.start),
    );
    if (fromFieldMatch != null) {
      return '${fromFieldMatch.group(1)}@${fromFieldMatch.group(2)}'.toLowerCase();
    }

    return null;
  }

  DateTime? _parseEmailDate(String dateStr) {
    try {
      // 尝试多种邮件日期格式
      // "Mon, 15 Jan 2024 10:30:00 +0800"
      // "15 Jan 2024 10:30:00 +0800"
      final cleaned = dateStr.replaceAll(RegExp(r'\s+'), ' ').trim();
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };

      final match = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})').firstMatch(cleaned);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = months[match.group(2)!.toLowerCase()] ?? 1;
        final year = int.parse(match.group(3)!);
        final hour = int.parse(match.group(4)!);
        final minute = int.parse(match.group(5)!);
        final second = int.parse(match.group(6)!);
        return DateTime(year, month, day, hour, minute, second);
      }

      return DateTime.tryParse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String? _extractBodyContent(String block) {
    // 查找 BODY[] 的内容 - 通常在 {size} 标记之后
    final bodyMatch = RegExp(r'BODY\[\]\s*\{(\d+)\}').firstMatch(block);
    if (bodyMatch != null) {
      final size = int.parse(bodyMatch.group(1)!);
      final start = bodyMatch.end + 2; // 跳过 \r\n
      if (start + size <= block.length) {
        return block.substring(start, start + size);
      }
      // 如果大小不精确匹配，返回剩余内容
      return block.substring(start);
    }

    // 尝试查找邮件头与正文的分隔（空行）
    final headerEnd = block.indexOf('\r\n\r\n');
    if (headerEnd >= 0) {
      return block.substring(headerEnd + 4);
    }

    return null;
  }

  void _parseMimeContent(
    String content,
    void Function(String contentType, String body, String? filename) onPart, {
    int depth = 0,
  }) {
    if (depth > 5) return; // 防止无限递归

    // 查找 Content-Type 中的 boundary
    final boundaryMatch = RegExp(r'boundary="?([^"\s;]+)"?', caseSensitive: false).firstMatch(content);

    if (boundaryMatch != null) {
      // Multipart 消息
      final boundary = boundaryMatch.group(1)!;
      final parts = content.split('--$boundary');

      for (final part in parts) {
        if (part.trim().isEmpty || part.trim() == '--') continue;

        // 展开折叠的 MIME 头部（CRLF + 空白 → 单空格）
        final headerEnd = part.indexOf('\r\n\r\n');
        final headerSection = headerEnd > 0 ? part.substring(0, headerEnd) : part;
        final unfoldedHeader = headerSection.replaceAll(RegExp(r'\r\n[ \t]+'), ' ');

        final contentTypeMatch = RegExp(r'Content-Type:\s*([^\s;]+)', caseSensitive: false).firstMatch(unfoldedHeader);
        // 支持 RFC 2047 编码和普通文件名
        final filenameMatch = RegExp(r'''(?:filename|name)=["']?([^"'\r\n;]+)["']?''', caseSensitive: false).firstMatch(unfoldedHeader);
        final contentType = contentTypeMatch?.group(1)?.toLowerCase() ?? 'text/plain';
        var filename = filenameMatch?.group(1)?.trim();

        // 解码 RFC 2047 编码的文件名
        if (filename != null && filename.contains('=?')) {
          filename = _decodeEncodedWord(filename);
        }

        debugPrint('[EmailImapService] MIME part: type=$contentType, filename=$filename');

        // 递归处理嵌套 multipart
        if (contentType.startsWith('multipart/')) {
          _parseMimeContent(part, onPart, depth: depth + 1);
        } else {
          final bodyStart = part.indexOf('\r\n\r\n');
          if (bodyStart >= 0) {
            onPart(contentType, part.substring(bodyStart + 4), filename);
          }
        }
      }
    } else {
      // 单部分消息
      final contentTypeMatch = RegExp(r'Content-Type:\s*([^\s;]+)', caseSensitive: false).firstMatch(content);
      final contentType = contentTypeMatch?.group(1)?.toLowerCase() ?? 'text/html';
      onPart(contentType, content, null);
    }
  }

  String? _extractEncoding(String block, String contentType) {
    final encodingMatch = RegExp(
      r'Content-Transfer-Encoding:\s*(\S+)',
      caseSensitive: false,
    ).firstMatch(block);
    return encodingMatch?.group(1)?.toLowerCase();
  }

  Uint8List _decodeContent(String content, String? encoding) {
    switch (encoding) {
      case 'base64':
        try {
          final cleaned = content.replaceAll(RegExp(r'\s'), '');
          return base64Decode(cleaned);
        } catch (e) {
          return utf8.encode(content);
        }
      case 'quoted-printable':
        return utf8.encode(_decodeQuotedPrintable(content));
      default:
        return utf8.encode(content);
    }
  }

  String _decodeTextContent(String content, String? encoding) {
    switch (encoding) {
      case 'base64':
        try {
          final cleaned = content.replaceAll(RegExp(r'\s'), '');
          return utf8.decode(base64Decode(cleaned), allowMalformed: true);
        } catch (e) {
          return content;
        }
      case 'quoted-printable':
        return _decodeQuotedPrintable(content);
      default:
        return content;
    }
  }

  String _decodeQuotedPrintable(String input) {
    final buffer = StringBuffer();
    int i = 0;
    while (i < input.length) {
      if (input[i] == '=' && i + 2 < input.length) {
        if (input[i + 1] == '\r' || input[i + 1] == '\n') {
          // 软换行
          i += 2;
          if (i < input.length && input[i] == '\n') i++;
        } else {
          try {
            final hex = input.substring(i + 1, i + 3);
            buffer.writeCharCode(int.parse(hex, radix: 16));
            i += 3;
          } catch (e) {
            buffer.write(input[i]);
            i++;
          }
        }
      } else {
        buffer.write(input[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// 解码 RFC 2047 编码的单词（如 =?UTF-8?B?...?= 或 =?GBK?Q?...?=）
  String _decodeEncodedWord(String input) {
    final regex = RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?=');
    return input.replaceAllMapped(regex, (match) {
      final encoding = match.group(2)!.toUpperCase();
      final encodedText = match.group(3)!;

      try {
        if (encoding == 'B') {
          return utf8.decode(base64Decode(encodedText), allowMalformed: true);
        } else if (encoding == 'Q') {
          return _decodeQuotedPrintable(encodedText.replaceAll('_', ' '));
        }
      } catch (e) {
        // 解码失败，返回原文
      }
      return match.group(0)!;
    });
  }
}
