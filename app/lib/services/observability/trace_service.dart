import 'dart:async';
import 'dart:math';

/// 追踪 Span 状态
enum SpanStatus {
  /// 未设置
  unset,

  /// 成功
  ok,

  /// 错误
  error,
}

/// 追踪 Span 类型
enum SpanKind {
  /// 内部操作
  internal,

  /// 服务端
  server,

  /// 客户端
  client,

  /// 生产者
  producer,

  /// 消费者
  consumer,
}

/// Span 上下文
class SpanContext {
  /// Trace ID (128-bit)
  final String traceId;

  /// Span ID (64-bit)
  final String spanId;

  /// 父 Span ID
  final String? parentSpanId;

  /// 追踪标志
  final int traceFlags;

  /// 追踪状态
  final String? traceState;

  const SpanContext({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    this.traceFlags = 1, // 默认采样
    this.traceState,
  });

  /// 是否被采样
  bool get isSampled => (traceFlags & 1) == 1;

  /// 转换为 W3C Trace Context 格式
  String toTraceparent() {
    return '00-$traceId-$spanId-${traceFlags.toRadixString(16).padLeft(2, '0')}';
  }

  /// 从 W3C Trace Context 解析
  static SpanContext? fromTraceparent(String traceparent) {
    final parts = traceparent.split('-');
    if (parts.length < 4) return null;

    return SpanContext(
      traceId: parts[1],
      spanId: parts[2],
      traceFlags: int.tryParse(parts[3], radix: 16) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'spanId': spanId,
    if (parentSpanId != null) 'parentSpanId': parentSpanId,
    'traceFlags': traceFlags,
    if (traceState != null) 'traceState': traceState,
  };
}

/// Span 事件
class SpanEvent {
  /// 事件名称
  final String name;

  /// 时间戳
  final DateTime timestamp;

  /// 属性
  final Map<String, dynamic>? attributes;

  SpanEvent({
    required this.name,
    DateTime? timestamp,
    this.attributes,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    if (attributes != null) 'attributes': attributes,
  };
}

/// Span 链接
class SpanLink {
  /// 链接的 Span 上下文
  final SpanContext context;

  /// 属性
  final Map<String, dynamic>? attributes;

  const SpanLink({
    required this.context,
    this.attributes,
  });

  Map<String, dynamic> toJson() => {
    'context': context.toJson(),
    if (attributes != null) 'attributes': attributes,
  };
}

/// 追踪 Span
class Span {
  /// Span 上下文
  final SpanContext context;

  /// Span 名称
  final String name;

  /// Span 类型
  final SpanKind kind;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  DateTime? endTime;

  /// 状态
  SpanStatus status;

  /// 状态消息
  String? statusMessage;

  /// 属��
  final Map<String, dynamic> attributes = {};

  /// 事件
  final List<SpanEvent> events = [];

  /// 链接
  final List<SpanLink> links = [];

  /// 是否已结束
  bool _ended = false;

  Span({
    required this.context,
    required this.name,
    this.kind = SpanKind.internal,
    DateTime? startTime,
    this.status = SpanStatus.unset,
  }) : startTime = startTime ?? DateTime.now();

  /// 是否已结束
  bool get isEnded => _ended;

  /// 持续时间
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// 设置属性
  void setAttribute(String key, dynamic value) {
    if (_ended) return;
    attributes[key] = value;
  }

  /// 批量设置属性
  void setAttributes(Map<String, dynamic> attrs) {
    if (_ended) return;
    attributes.addAll(attrs);
  }

  /// 添加事件
  void addEvent(String name, {Map<String, dynamic>? attributes}) {
    if (_ended) return;
    events.add(SpanEvent(name: name, attributes: attributes));
  }

  /// 添加链接
  void addLink(SpanContext context, {Map<String, dynamic>? attributes}) {
    if (_ended) return;
    links.add(SpanLink(context: context, attributes: attributes));
  }

  /// 设置状态
  void setStatus(SpanStatus status, {String? message}) {
    if (_ended) return;
    this.status = status;
    statusMessage = message;
  }

  /// 记录异常
  void recordException(
    dynamic exception, {
    StackTrace? stackTrace,
    bool escaped = false,
  }) {
    if (_ended) return;

    addEvent('exception', attributes: {
      'exception.type': exception.runtimeType.toString(),
      'exception.message': exception.toString(),
      if (stackTrace != null) 'exception.stacktrace': stackTrace.toString(),
      'exception.escaped': escaped,
    });

    if (status == SpanStatus.unset) {
      setStatus(SpanStatus.error, message: exception.toString());
    }
  }

  /// 结束 Span
  void end({DateTime? endTime}) {
    if (_ended) return;
    _ended = true;
    this.endTime = endTime ?? DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'context': context.toJson(),
    'name': name,
    'kind': kind.name,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'status': status.name,
    if (statusMessage != null) 'statusMessage': statusMessage,
    'attributes': attributes,
    'events': events.map((e) => e.toJson()).toList(),
    'links': links.map((l) => l.toJson()).toList(),
  };
}

/// TraceID 全链路追踪服务
///
/// 核心功能：
/// 1. 生成和传播 Trace ID
/// 2. Span 管理
/// 3. 上下文传播
/// 4. 采样策略
///
/// 对应设计文档：第25章/第29章 TraceID全链路追踪
/// 对应实施方案：轨道L 可观测性模块
class TracingService {
  static final TracingService _instance = TracingService._();
  factory TracingService() => _instance;
  TracingService._();

  TracingConfig _config = const TracingConfig();
  bool _initialized = false;

  /// 当前 Span 栈
  final List<Span> _spanStack = [];

  /// 所有活跃 Span
  final Map<String, Span> _activeSpans = {};

  /// 已完成 Span（等待导出）
  final List<Span> _pendingSpans = [];

  /// 导出回调
  Future<void> Function(List<Span> spans)? _onExport;

  /// 导出定时器
  Timer? _exportTimer;

  /// 初始化服务
  Future<void> initialize({
    TracingConfig? config,
    Future<void> Function(List<Span> spans)? onExport,
  }) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }
    _onExport = onExport;

    // 启动定期导出
    if (_config.enableAutoExport) {
      _exportTimer = Timer.periodic(_config.exportInterval, (_) => flush());
    }

    _initialized = true;
  }

  /// 获取当前 Span
  Span? get currentSpan => _spanStack.isNotEmpty ? _spanStack.last : null;

  /// 获取当前 Trace ID
  String? get currentTraceId => currentSpan?.context.traceId;

  /// 获取当前 Span ID
  String? get currentSpanId => currentSpan?.context.spanId;

  /// 生成新的 Trace ID
  String generateTraceId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 生成新的 Span ID
  String generateSpanId() {
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 开始新的 Span
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    SpanContext? parentContext,
    Map<String, dynamic>? attributes,
    List<SpanLink>? links,
  }) {
    // 确定父上下文
    final effectiveParent = parentContext ?? currentSpan?.context;

    // 生成上下文
    final context = SpanContext(
      traceId: effectiveParent?.traceId ?? generateTraceId(),
      spanId: generateSpanId(),
      parentSpanId: effectiveParent?.spanId,
      traceFlags: _shouldSample() ? 1 : 0,
    );

    // 创建 Span
    final span = Span(
      context: context,
      name: name,
      kind: kind,
    );

    // 设置属性
    if (attributes != null) {
      span.setAttributes(attributes);
    }

    // 添加链接
    if (links != null) {
      for (final link in links) {
        span.links.add(link);
      }
    }

    // 入栈
    _spanStack.add(span);
    _activeSpans[context.spanId] = span;

    return span;
  }

  /// 结束当前 Span
  void endSpan({SpanStatus? status, String? statusMessage}) {
    if (_spanStack.isEmpty) return;

    final span = _spanStack.removeLast();
    _activeSpans.remove(span.context.spanId);

    if (status != null) {
      span.setStatus(status, message: statusMessage);
    }

    span.end();

    // 添加到待导出列表
    if (span.context.isSampled) {
      _pendingSpans.add(span);
    }

    // 检查是否需要立即导出
    if (_pendingSpans.length >= _config.maxPendingSpans) {
      flush();
    }
  }

  /// 包装异步操作
  Future<T> trace<T>(
    String name,
    Future<T> Function() operation, {
    SpanKind kind = SpanKind.internal,
    Map<String, dynamic>? attributes,
  }) async {
    final span = startSpan(name, kind: kind, attributes: attributes);

    try {
      final result = await operation();
      span.setStatus(SpanStatus.ok);
      return result;
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      rethrow;
    } finally {
      endSpan();
    }
  }

  /// 包装同步操作
  T traceSync<T>(
    String name,
    T Function() operation, {
    SpanKind kind = SpanKind.internal,
    Map<String, dynamic>? attributes,
  }) {
    final span = startSpan(name, kind: kind, attributes: attributes);

    try {
      final result = operation();
      span.setStatus(SpanStatus.ok);
      return result;
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      rethrow;
    } finally {
      endSpan();
    }
  }

  /// 使用 Zone 传播上下文
  Future<T> runInContext<T>(
    SpanContext context,
    Future<T> Function() operation,
  ) {
    return Zone.current.fork(
      zoneValues: {#traceContext: context},
    ).run(operation);
  }

  /// 从 Zone 获取上下文
  SpanContext? getContextFromZone() {
    return Zone.current[#traceContext] as SpanContext?;
  }

  /// 注入追踪头到 HTTP 请求
  Map<String, String> injectHeaders({Map<String, String>? headers}) {
    final result = headers ?? <String, String>{};

    final current = currentSpan;
    if (current != null) {
      result['traceparent'] = current.context.toTraceparent();
      if (current.context.traceState != null) {
        result['tracestate'] = current.context.traceState!;
      }
    }

    return result;
  }

  /// 从 HTTP 响应提取上下文
  SpanContext? extractContext(Map<String, String> headers) {
    final traceparent = headers['traceparent'];
    if (traceparent == null) return null;

    return SpanContext.fromTraceparent(traceparent);
  }

  /// 刷新待导出 Span
  Future<void> flush() async {
    if (_pendingSpans.isEmpty || _onExport == null) return;

    final spans = List<Span>.from(_pendingSpans);
    _pendingSpans.clear();

    try {
      await _onExport!(spans);
    } catch (e) {
      // 导出失败，放回队列（限制数量避免内存溢出）
      if (_pendingSpans.length < _config.maxPendingSpans) {
        _pendingSpans.addAll(spans);
      }
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _exportTimer?.cancel();
    await flush();
    _spanStack.clear();
    _activeSpans.clear();
    _initialized = false;
  }

  // ==================== 预定义追踪方法 ====================

  /// 追踪 HTTP 请求
  Future<T> traceHttpRequest<T>(
    String method,
    String url,
    Future<T> Function() request,
  ) {
    return trace(
      '$method ${Uri.parse(url).path}',
      request,
      kind: SpanKind.client,
      attributes: {
        'http.method': method,
        'http.url': url,
        'http.scheme': Uri.parse(url).scheme,
        'http.host': Uri.parse(url).host,
      },
    );
  }

  /// 追踪数据库操作
  Future<T> traceDbOperation<T>(
    String operation,
    String table,
    Future<T> Function() query,
  ) {
    return trace(
      'DB $operation $table',
      query,
      kind: SpanKind.client,
      attributes: {
        'db.operation': operation,
        'db.table': table,
        'db.system': 'sqlite',
      },
    );
  }

  // ==================== 私有方法 ====================

  bool _shouldSample() {
    if (_config.sampleRate >= 1.0) return true;
    if (_config.sampleRate <= 0.0) return false;

    return Random().nextDouble() < _config.sampleRate;
  }
}

/// 追踪配置
class TracingConfig {
  /// 服务名称
  final String serviceName;

  /// 采样率 (0.0 - 1.0)
  final double sampleRate;

  /// 是否启用自动导出
  final bool enableAutoExport;

  /// 导出间隔
  final Duration exportInterval;

  /// 最大待导出 Span 数
  final int maxPendingSpans;

  const TracingConfig({
    this.serviceName = 'ai-bookkeeping-app',
    this.sampleRate = 1.0,
    this.enableAutoExport = true,
    this.exportInterval = const Duration(seconds: 30),
    this.maxPendingSpans = 100,
  });
}

/// 全局追踪实例
final tracer = TracingService();
