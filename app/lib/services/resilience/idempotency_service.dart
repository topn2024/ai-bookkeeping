import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 幂等键生成策略
enum IdempotencyKeyStrategy {
  /// UUID生成
  uuid,

  /// 基于内容哈希
  contentHash,

  /// 客户端提供
  clientProvided,

  /// 混合策略（UUID + 时间戳）
  hybrid,
}

/// 幂等性检查结果
class IdempotencyCheckResult {
  /// 是否是重复请求
  final bool isDuplicate;

  /// 原始响应（如果是重复请求）
  final dynamic cachedResponse;

  /// 幂等键
  final String idempotencyKey;

  /// 原始请求时间
  final DateTime? originalRequestTime;

  /// 请求状态
  final IdempotencyStatus status;

  const IdempotencyCheckResult({
    required this.isDuplicate,
    this.cachedResponse,
    required this.idempotencyKey,
    this.originalRequestTime,
    required this.status,
  });

  factory IdempotencyCheckResult.newRequest(String key) {
    return IdempotencyCheckResult(
      isDuplicate: false,
      idempotencyKey: key,
      status: IdempotencyStatus.processing,
    );
  }

  factory IdempotencyCheckResult.duplicate({
    required String key,
    required dynamic response,
    required DateTime originalTime,
    required IdempotencyStatus status,
  }) {
    return IdempotencyCheckResult(
      isDuplicate: true,
      cachedResponse: response,
      idempotencyKey: key,
      originalRequestTime: originalTime,
      status: status,
    );
  }
}

/// 幂等状态
enum IdempotencyStatus {
  /// 处理中
  processing,

  /// 已完成
  completed,

  /// 失败
  failed,

  /// 已过期
  expired,
}

/// 幂等记录
class IdempotencyRecord {
  /// 幂等键
  final String key;

  /// 请求哈希（用于验证请求一致性）
  final String requestHash;

  /// 响应数据
  final dynamic response;

  /// 状态
  final IdempotencyStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 完成时间
  final DateTime? completedAt;

  /// 过期时间
  final DateTime expiresAt;

  /// 重试次数
  final int retryCount;

  const IdempotencyRecord({
    required this.key,
    required this.requestHash,
    this.response,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.expiresAt,
    this.retryCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isProcessing => status == IdempotencyStatus.processing;

  bool get isCompleted => status == IdempotencyStatus.completed;

  IdempotencyRecord copyWith({
    dynamic response,
    IdempotencyStatus? status,
    DateTime? completedAt,
    int? retryCount,
  }) {
    return IdempotencyRecord(
      key: key,
      requestHash: requestHash,
      response: response ?? this.response,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'requestHash': requestHash,
      'response': response,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory IdempotencyRecord.fromJson(Map<String, dynamic> json) {
    return IdempotencyRecord(
      key: json['key'],
      requestHash: json['requestHash'],
      response: json['response'],
      status: IdempotencyStatus.values.byName(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      expiresAt: DateTime.parse(json['expiresAt']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

/// 幂等性配置
class IdempotencyConfig {
  /// 默认过期时间
  final Duration defaultTtl;

  /// 最大重试次数
  final int maxRetries;

  /// 处理中状态超时时间
  final Duration processingTimeout;

  /// 是否允许并发处理相同请求
  final bool allowConcurrentProcessing;

  /// 是否验证请求内容
  final bool validateRequestContent;

  /// 清理间隔
  final Duration cleanupInterval;

  const IdempotencyConfig({
    this.defaultTtl = const Duration(hours: 24),
    this.maxRetries = 3,
    this.processingTimeout = const Duration(minutes: 5),
    this.allowConcurrentProcessing = false,
    this.validateRequestContent = true,
    this.cleanupInterval = const Duration(minutes: 30),
  });
}

/// 幂等性服务
///
/// 实现幂等性设计：
/// 1. 客户端生成幂等键（UUID）
/// 2. 本地存储 + 可选Redis后端
/// 3. 请求内容哈希验证
/// 4. 自动过期清理
///
/// 对应设计文档：第32章 高可用架构设计
/// 代码块：429
class IdempotencyService extends ChangeNotifier {
  static final IdempotencyService _instance = IdempotencyService._();
  factory IdempotencyService() => _instance;
  IdempotencyService._();

  IdempotencyConfig _config = const IdempotencyConfig();
  bool _initialized = false;

  final Uuid _uuid = const Uuid();

  // 本地存储（生产环境应使用Redis）
  final Map<String, IdempotencyRecord> _records = {};

  // 统计信息
  int _totalRequests = 0;
  int _duplicateRequests = 0;
  int _newRequests = 0;

  Timer? _cleanupTimer;

  /// 初始化服务
  Future<void> initialize({IdempotencyConfig? config}) async {
    if (_initialized) return;

    _config = config ?? const IdempotencyConfig();

    // 启动定期清理
    _cleanupTimer = Timer.periodic(
      _config.cleanupInterval,
      (_) => _cleanup(),
    );

    _initialized = true;

    if (kDebugMode) {
      debugPrint('IdempotencyService initialized with TTL=${_config.defaultTtl}');
    }
  }

  /// 生成幂等键
  String generateKey({
    IdempotencyKeyStrategy strategy = IdempotencyKeyStrategy.uuid,
    Map<String, dynamic>? requestData,
    String? prefix,
  }) {
    String key;

    switch (strategy) {
      case IdempotencyKeyStrategy.uuid:
        key = _uuid.v4();
        break;

      case IdempotencyKeyStrategy.contentHash:
        if (requestData == null) {
          throw ArgumentError('requestData is required for contentHash strategy');
        }
        key = _generateContentHash(requestData);
        break;

      case IdempotencyKeyStrategy.clientProvided:
        throw ArgumentError('Use clientProvided key directly, not generateKey');

      case IdempotencyKeyStrategy.hybrid:
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uuid = _uuid.v4();
        key = '$timestamp-$uuid';
        break;
    }

    return prefix != null ? '$prefix:$key' : key;
  }

  /// 检查并获取幂等记录
  Future<IdempotencyCheckResult> checkAndAcquire({
    required String idempotencyKey,
    required Map<String, dynamic> requestData,
    Duration? ttl,
  }) async {
    _totalRequests++;

    final requestHash = _generateContentHash(requestData);
    final effectiveTtl = ttl ?? _config.defaultTtl;

    // 检查是否存在记录
    final existingRecord = _records[idempotencyKey];

    if (existingRecord != null) {
      // 检查是否过期
      if (existingRecord.isExpired) {
        _records.remove(idempotencyKey);
      } else {
        // 验证请求内容一致性
        if (_config.validateRequestContent &&
            existingRecord.requestHash != requestHash) {
          throw IdempotencyConflictException(
            key: idempotencyKey,
            message: 'Request content mismatch for idempotency key',
          );
        }

        // 检查处理中状态是否超时
        if (existingRecord.isProcessing) {
          final processingTime = DateTime.now().difference(existingRecord.createdAt);
          if (processingTime > _config.processingTimeout) {
            // 处理超时，允许重试
            if (existingRecord.retryCount < _config.maxRetries) {
              final updatedRecord = existingRecord.copyWith(
                retryCount: existingRecord.retryCount + 1,
              );
              _records[idempotencyKey] = updatedRecord;
              _newRequests++;
              return IdempotencyCheckResult.newRequest(idempotencyKey);
            }
          }

          // 正在处理中，返回等待
          if (!_config.allowConcurrentProcessing) {
            _duplicateRequests++;
            return IdempotencyCheckResult.duplicate(
              key: idempotencyKey,
              response: null,
              originalTime: existingRecord.createdAt,
              status: IdempotencyStatus.processing,
            );
          }
        }

        // 返回缓存的响应
        _duplicateRequests++;
        return IdempotencyCheckResult.duplicate(
          key: idempotencyKey,
          response: existingRecord.response,
          originalTime: existingRecord.createdAt,
          status: existingRecord.status,
        );
      }
    }

    // 创建新记录
    final record = IdempotencyRecord(
      key: idempotencyKey,
      requestHash: requestHash,
      status: IdempotencyStatus.processing,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(effectiveTtl),
    );

    _records[idempotencyKey] = record;
    _newRequests++;

    return IdempotencyCheckResult.newRequest(idempotencyKey);
  }

  /// 完成请求（成功）
  Future<void> complete({
    required String idempotencyKey,
    required dynamic response,
  }) async {
    final record = _records[idempotencyKey];
    if (record == null) {
      if (kDebugMode) {
        debugPrint('Warning: No record found for idempotency key: $idempotencyKey');
      }
      return;
    }

    _records[idempotencyKey] = record.copyWith(
      response: response,
      status: IdempotencyStatus.completed,
      completedAt: DateTime.now(),
    );

    notifyListeners();
  }

  /// 标记请求失败
  Future<void> fail({
    required String idempotencyKey,
    dynamic error,
  }) async {
    final record = _records[idempotencyKey];
    if (record == null) return;

    _records[idempotencyKey] = record.copyWith(
      response: error?.toString(),
      status: IdempotencyStatus.failed,
      completedAt: DateTime.now(),
    );

    notifyListeners();
  }

  /// 删除幂等记录
  Future<void> remove(String idempotencyKey) async {
    _records.remove(idempotencyKey);
    notifyListeners();
  }

  /// 执行带幂等保护的操作
  Future<T> execute<T>({
    required String idempotencyKey,
    required Map<String, dynamic> requestData,
    required Future<T> Function() operation,
    Duration? ttl,
  }) async {
    final checkResult = await checkAndAcquire(
      idempotencyKey: idempotencyKey,
      requestData: requestData,
      ttl: ttl,
    );

    if (checkResult.isDuplicate) {
      if (checkResult.status == IdempotencyStatus.processing) {
        // 等待原始请求完成
        return await _waitForCompletion<T>(idempotencyKey);
      }

      if (checkResult.status == IdempotencyStatus.completed) {
        return checkResult.cachedResponse as T;
      }

      // 失败状态，允许重试
    }

    try {
      final result = await operation();
      await complete(idempotencyKey: idempotencyKey, response: result);
      return result;
    } catch (e) {
      await fail(idempotencyKey: idempotencyKey, error: e);
      rethrow;
    }
  }

  /// 获取统计信息
  IdempotencyStats getStats() {
    return IdempotencyStats(
      totalRequests: _totalRequests,
      duplicateRequests: _duplicateRequests,
      newRequests: _newRequests,
      activeRecords: _records.length,
      processingRecords: _records.values
          .where((r) => r.status == IdempotencyStatus.processing)
          .length,
    );
  }

  /// 清除所有记录
  void clearAll() {
    _records.clear();
    _totalRequests = 0;
    _duplicateRequests = 0;
    _newRequests = 0;
    notifyListeners();
  }

  // ==================== 私有方法 ====================

  String _generateContentHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<T> _waitForCompletion<T>(String idempotencyKey) async {
    const maxWaitTime = Duration(minutes: 5);
    const checkInterval = Duration(milliseconds: 500);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      final record = _records[idempotencyKey];

      if (record == null || record.isExpired) {
        throw IdempotencyExpiredException(key: idempotencyKey);
      }

      if (record.isCompleted) {
        return record.response as T;
      }

      if (record.status == IdempotencyStatus.failed) {
        throw IdempotencyFailedException(
          key: idempotencyKey,
          message: record.response?.toString(),
        );
      }

      await Future.delayed(checkInterval);
    }

    throw TimeoutException('Waiting for idempotent request completion timed out');
  }

  void _cleanup() {
    final expiredKeys = _records.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _records.remove(key);
    }

    if (expiredKeys.isNotEmpty && kDebugMode) {
      debugPrint('IdempotencyService: Cleaned up ${expiredKeys.length} expired records');
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _cleanupTimer?.cancel();
    _records.clear();
    _initialized = false;
  }
}

/// 幂等性统计信息
class IdempotencyStats {
  final int totalRequests;
  final int duplicateRequests;
  final int newRequests;
  final int activeRecords;
  final int processingRecords;

  const IdempotencyStats({
    required this.totalRequests,
    required this.duplicateRequests,
    required this.newRequests,
    required this.activeRecords,
    required this.processingRecords,
  });

  double get duplicateRate =>
      totalRequests > 0 ? duplicateRequests / totalRequests : 0.0;
}

/// 幂等冲突异常
class IdempotencyConflictException implements Exception {
  final String key;
  final String message;

  IdempotencyConflictException({
    required this.key,
    required this.message,
  });

  @override
  String toString() => 'IdempotencyConflictException: $message (key: $key)';
}

/// 幂等记录过期异常
class IdempotencyExpiredException implements Exception {
  final String key;

  IdempotencyExpiredException({required this.key});

  @override
  String toString() => 'IdempotencyExpiredException: Record expired (key: $key)';
}

/// 幂等请求失败异常
class IdempotencyFailedException implements Exception {
  final String key;
  final String? message;

  IdempotencyFailedException({required this.key, this.message});

  @override
  String toString() =>
      'IdempotencyFailedException: Original request failed (key: $key) $message';
}

/// 全局幂等服务实例
final idempotencyService = IdempotencyService();
