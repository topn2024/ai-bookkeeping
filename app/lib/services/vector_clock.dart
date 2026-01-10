import 'dart:math' show max;
import 'dart:convert';

/// 时钟比较结果
enum ClockComparison {
  /// 两个时钟相等
  equal,

  /// 当前时钟在另一个时钟之前
  before,

  /// 当前时钟在另一个时钟之后
  after,

  /// 并发（无法确定因果顺序）
  concurrent,
}

/// 向量时钟实现 - 用于CRDT冲突解决
///
/// 向量时钟是一种分布式系统中用于捕获因果关系的逻辑时钟。
/// 它可以确定两个事件之间的因果顺序，或者检测并发事件。
class VectorClock {
  final Map<String, int> _clock;

  VectorClock([Map<String, int>? clock]) : _clock = Map.from(clock ?? {});

  /// 从JSON创建向量时钟
  factory VectorClock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VectorClock();
    return VectorClock(
      json.map((key, value) => MapEntry(key, value as int)),
    );
  }

  /// 转换为JSON
  Map<String, int> toJson() => Map.from(_clock);

  /// 转换为Map（toJson的别名）
  Map<String, int> toMap() => toJson();

  /// 获取某个节点的时间戳
  int operator [](String nodeId) => _clock[nodeId] ?? 0;

  /// 获取所有节点
  Set<String> get nodes => _clock.keys.toSet();

  /// 判断当前时钟是否发生在另一个时钟之前
  ///
  /// ���果对于所有节点，当前时钟的时间戳都小于等于other的时间戳，
  /// 且至少有一个节点的时间戳严格小于other的时间戳，则返回true
  bool happensBefore(VectorClock other) {
    // 获取所有节点
    final allNodes = nodes.union(other.nodes);

    bool hasSmaller = false;

    for (final node in allNodes) {
      final thisValue = this[node];
      final otherValue = other[node];

      if (thisValue > otherValue) {
        return false; // 如果有任何一个节点大于other，则不是happens-before
      }
      if (thisValue < otherValue) {
        hasSmaller = true;
      }
    }

    return hasSmaller;
  }

  /// 判断两个时钟是否并发（无法确定因果顺序）
  bool isConcurrent(VectorClock other) {
    return !happensBefore(other) && !other.happensBefore(this) && this != other;
  }

  /// 合并两个向量时钟
  ///
  /// 对于每个节点，取两个时钟中的最大值
  VectorClock merge(VectorClock other) {
    final merged = Map<String, int>.from(_clock);

    for (final entry in other._clock.entries) {
      merged[entry.key] = max(merged[entry.key] ?? 0, entry.value);
    }

    return VectorClock(merged);
  }

  /// 递增指定节点的时间戳
  VectorClock increment(String nodeId) {
    final newClock = Map<String, int>.from(_clock);
    newClock[nodeId] = (newClock[nodeId] ?? 0) + 1;
    return VectorClock(newClock);
  }

  /// 比较两个向量时钟（返回int）
  ///
  /// 返回:
  /// - -1: this happens-before other
  /// - 1: other happens-before this
  /// - 0: 相等或并发
  int compareTo(VectorClock other) {
    if (happensBefore(other)) return -1;
    if (other.happensBefore(this)) return 1;
    return 0;
  }

  /// 比较两个向量时钟（返回ClockComparison枚举）
  ClockComparison compare(VectorClock other) {
    if (this == other) return ClockComparison.equal;
    if (happensBefore(other)) return ClockComparison.before;
    if (other.happensBefore(this)) return ClockComparison.after;
    return ClockComparison.concurrent;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VectorClock) return false;

    final allNodes = nodes.union(other.nodes);
    for (final node in allNodes) {
      if (this[node] != other[node]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _clock.hashCode;

  @override
  String toString() => 'VectorClock($_clock)';

  /// 创建一个空的向量时钟
  static VectorClock empty() => VectorClock();

  /// 从字符串解析
  static VectorClock? tryParse(String? clockString) {
    if (clockString == null || clockString.isEmpty) return null;
    try {
      final json = jsonDecode(clockString) as Map<String, dynamic>;
      return VectorClock.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 转换为字符串
  String encode() => jsonEncode(_clock);
}

/// 同步操作，包含向量时钟
class SyncOperation {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final VectorClock vectorClock;
  final String clientId;
  final DateTime timestamp;

  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.data,
    required this.vectorClock,
    required this.clientId,
    required this.timestamp,
  });

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncOperationType.update,
      ),
      data: json['data'] as Map<String, dynamic>,
      vectorClock: VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>?),
      clientId: json['clientId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'type': type.name,
    'data': data,
    'vectorClock': vectorClock.toJson(),
    'clientId': clientId,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 同步操作类型
enum SyncOperationType {
  create,
  update,
  delete,
}

/// 同步结果
class SyncResult {
  final SyncResultType type;
  final SyncOperation? acceptedOperation;
  final Map<String, dynamic>? mergedData;
  final String? message;

  const SyncResult._({
    required this.type,
    this.acceptedOperation,
    this.mergedData,
    this.message,
  });

  factory SyncResult.acceptRemote(SyncOperation remote) {
    return SyncResult._(
      type: SyncResultType.acceptRemote,
      acceptedOperation: remote,
    );
  }

  factory SyncResult.keepLocal(SyncOperation local) {
    return SyncResult._(
      type: SyncResultType.keepLocal,
      acceptedOperation: local,
    );
  }

  factory SyncResult.merged(Map<String, dynamic> mergedData) {
    return SyncResult._(
      type: SyncResultType.merged,
      mergedData: mergedData,
    );
  }

  factory SyncResult.conflict({required String message}) {
    return SyncResult._(
      type: SyncResultType.conflict,
      message: message,
    );
  }

  bool get isSuccess => type != SyncResultType.conflict;
}

/// 同步结果类型
enum SyncResultType {
  acceptRemote,
  keepLocal,
  merged,
  conflict,
}
