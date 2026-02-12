import '../../models/import_candidate.dart';

/// 权限异常
class PermissionException implements Exception {
  final String message;

  PermissionException(this.message);

  @override
  String toString() => 'PermissionException: $message';
}

/// 网络异常
class NetworkException implements Exception {
  final String message;
  final dynamic originalError;

  NetworkException(this.message, {this.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

/// AI解析异常
class AIParseException implements Exception {
  final String message;
  final int parsedCount;
  final int failedCount;
  final List<ImportCandidate>? partialCandidates;

  AIParseException({
    required this.message,
    this.parsedCount = 0,
    this.failedCount = 0,
    this.partialCandidates,
  });

  @override
  String toString() => 'AIParseException: $message (parsed: $parsedCount, failed: $failedCount)';
}

/// 短信读取异常
class SmsReadException implements Exception {
  final String message;

  SmsReadException(this.message);

  @override
  String toString() => 'SmsReadException: $message';
}

/// 邮箱连接异常
class EmailConnectionException implements Exception {
  final String message;
  final dynamic originalError;

  EmailConnectionException(this.message, {this.originalError});

  @override
  String toString() => 'EmailConnectionException: $message';
}

/// 邮箱认证异常
class EmailAuthException implements Exception {
  final String message;

  EmailAuthException(this.message);

  @override
  String toString() => 'EmailAuthException: $message';
}
