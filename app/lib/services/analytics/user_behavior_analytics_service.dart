import 'dart:async';
import 'dart:convert';

/// 用户行为分析埋点服务
///
/// 提供用户行为追踪、事件记录、数据上报等功能
/// 支持自动埋点、手动埋点、页面访问追踪等
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== 事件类型定义 ====================

/// 事件类型
enum EventType {
  /// 页面浏览
  pageView,

  /// 用户操作
  action,

  /// 业务事件
  business,

  /// 性能事件
  performance,

  /// 错误事件
  error,

  /// 自定义事件
  custom,
}

/// 页面类型
enum PageType {
  home,
  transaction,
  budget,
  statistics,
  settings,
  account,
  category,
  moneyAge,
  other,
}

/// 操作类型
enum ActionType {
  tap,
  swipe,
  longPress,
  scroll,
  input,
  submit,
  cancel,
  share,
  other,
}

// ==================== 事件模型 ====================

/// 分析事件
class AnalyticsEvent {
  final String eventId;
  final EventType type;
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? sessionId;
  final String? userId;
  final String? deviceId;
  final Map<String, dynamic>? context;

  AnalyticsEvent({
    required this.eventId,
    required this.type,
    required this.name,
    this.properties = const {},
    DateTime? timestamp,
    this.sessionId,
    this.userId,
    this.deviceId,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'type': type.name,
        'name': name,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
        'session_id': sessionId,
        'user_id': userId,
        'device_id': deviceId,
        'context': context,
      };

  @override
  String toString() => 'AnalyticsEvent($name, ${type.name})';
}

/// 页面访问事件
class PageViewEvent extends AnalyticsEvent {
  final PageType pageType;
  final String pageName;
  final String? referrer;
  final Duration? duration;

  PageViewEvent({
    required super.eventId,
    required this.pageType,
    required this.pageName,
    this.referrer,
    this.duration,
    super.properties = const {},
    super.timestamp,
    super.sessionId,
    super.userId,
    super.deviceId,
    super.context,
  }) : super(
          type: EventType.pageView,
          name: 'page_view',
        );

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'page_type': pageType.name,
        'page_name': pageName,
        'referrer': referrer,
        'duration_ms': duration?.inMilliseconds,
      };
}

/// 用户操作事件
class ActionEvent extends AnalyticsEvent {
  final ActionType actionType;
  final String target;
  final String? targetId;

  ActionEvent({
    required super.eventId,
    required super.name,
    required this.actionType,
    required this.target,
    this.targetId,
    super.properties = const {},
    super.timestamp,
    super.sessionId,
    super.userId,
    super.deviceId,
    super.context,
  }) : super(type: EventType.action);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'action_type': actionType.name,
        'target': target,
        'target_id': targetId,
      };
}

/// 业务事件
class BusinessEvent extends AnalyticsEvent {
  final String businessType;
  final double? value;
  final String? currency;

  BusinessEvent({
    required super.eventId,
    required super.name,
    required this.businessType,
    this.value,
    this.currency,
    super.properties = const {},
    super.timestamp,
    super.sessionId,
    super.userId,
    super.deviceId,
    super.context,
  }) : super(type: EventType.business);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'business_type': businessType,
        'value': value,
        'currency': currency,
      };
}

// ==================== 会话管理 ====================

/// 会话信息
class AnalyticsSession {
  final String sessionId;
  final DateTime startTime;
  DateTime? endTime;
  int eventCount;
  int pageViewCount;
  String? entryPage;
  String? exitPage;
  final Map<String, int> pageViewCounts;

  AnalyticsSession({
    required this.sessionId,
    DateTime? startTime,
  })  : startTime = startTime ?? DateTime.now(),
        eventCount = 0,
        pageViewCount = 0,
        pageViewCounts = {};

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  void recordEvent() {
    eventCount++;
  }

  void recordPageView(String pageName) {
    pageViewCount++;
    pageViewCounts[pageName] = (pageViewCounts[pageName] ?? 0) + 1;
    entryPage ??= pageName;
    exitPage = pageName;
  }

  void end() {
    endTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'duration_ms': duration.inMilliseconds,
        'event_count': eventCount,
        'page_view_count': pageViewCount,
        'entry_page': entryPage,
        'exit_page': exitPage,
        'page_view_counts': pageViewCounts,
      };
}

// ==================== 事件处理器 ====================

/// 事件处理器接口
abstract class EventProcessor {
  Future<void> process(AnalyticsEvent event);
  Future<void> flush();
  void dispose();
}

/// 控制台日志处理器
class ConsoleEventProcessor implements EventProcessor {
  final bool enabled;
  final bool verbose;

  ConsoleEventProcessor({
    this.enabled = true,
    this.verbose = false,
  });

  @override
  Future<void> process(AnalyticsEvent event) async {
    if (!enabled) return;

    if (verbose) {
      print('[Analytics] ${jsonEncode(event.toJson())}');
    } else {
      print('[Analytics] ${event.type.name}: ${event.name}');
    }
  }

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

/// 批量上报处理器
class BatchEventProcessor implements EventProcessor {
  final int batchSize;
  final Duration flushInterval;
  final Future<void> Function(List<AnalyticsEvent> events) onFlush;

  final List<AnalyticsEvent> _buffer = [];
  Timer? _flushTimer;
  bool _disposed = false;

  BatchEventProcessor({
    this.batchSize = 20,
    this.flushInterval = const Duration(seconds: 30),
    required this.onFlush,
  }) {
    _startFlushTimer();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  @override
  Future<void> process(AnalyticsEvent event) async {
    if (_disposed) return;

    _buffer.add(event);

    if (_buffer.length >= batchSize) {
      await flush();
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _disposed) return;

    final events = List<AnalyticsEvent>.from(_buffer);
    _buffer.clear();

    try {
      await onFlush(events);
    } catch (e) {
      // 失败时重新加入缓冲区
      _buffer.insertAll(0, events);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _buffer.clear();
  }
}

/// 本地存储处理器
class LocalStorageEventProcessor implements EventProcessor {
  final int maxEvents;
  final List<AnalyticsEvent> _events = [];

  LocalStorageEventProcessor({this.maxEvents = 1000});

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> process(AnalyticsEvent event) async {
    _events.add(event);

    // 超过最大数量时移除旧事件
    while (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  @override
  Future<void> flush() async {
    // 本地存储不需要 flush
  }

  @override
  void dispose() {
    _events.clear();
  }

  /// 获取指定时间范围的事件
  List<AnalyticsEvent> getEventsByDateRange(DateTime start, DateTime end) {
    return _events.where((e) {
      return e.timestamp.isAfter(start) && e.timestamp.isBefore(end);
    }).toList();
  }

  /// 获取指定类型的事件
  List<AnalyticsEvent> getEventsByType(EventType type) {
    return _events.where((e) => e.type == type).toList();
  }

  /// 获取指定名称的事件
  List<AnalyticsEvent> getEventsByName(String name) {
    return _events.where((e) => e.name == name).toList();
  }

  /// 清除所有事件
  void clear() {
    _events.clear();
  }
}

// ==================== 用户行为分析服务 ====================

/// 用户行为分析服务
class UserBehaviorAnalyticsService {
  static final UserBehaviorAnalyticsService _instance =
      UserBehaviorAnalyticsService._internal();
  factory UserBehaviorAnalyticsService() => _instance;
  UserBehaviorAnalyticsService._internal();

  bool _initialized = false;
  String? _userId;
  String? _deviceId;
  AnalyticsSession? _currentSession;
  final List<EventProcessor> _processors = [];

  // 配置
  bool _enabled = true;
  bool _autoTrackPageView = true;
  bool _autoTrackAppLifecycle = true;
  final Set<String> _excludedEvents = {};

  /// 初始化服务
  Future<void> initialize({
    String? userId,
    String? deviceId,
    bool enabled = true,
    bool autoTrackPageView = true,
    bool autoTrackAppLifecycle = true,
    List<EventProcessor>? processors,
  }) async {
    if (_initialized) return;

    _userId = userId;
    _deviceId = deviceId ?? _generateDeviceId();
    _enabled = enabled;
    _autoTrackPageView = autoTrackPageView;
    _autoTrackAppLifecycle = autoTrackAppLifecycle;

    if (processors != null) {
      _processors.addAll(processors);
    }

    _startNewSession();
    _initialized = true;
  }

  String _generateDeviceId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 开始新会话
  void _startNewSession() {
    _currentSession?.end();
    _currentSession = AnalyticsSession(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// 设置用户ID
  void setUserId(String? userId) {
    _userId = userId;
    trackEvent(
      name: 'user_identify',
      type: EventType.custom,
      properties: {'user_id': userId},
    );
  }

  /// 设置用户属性
  void setUserProperties(Map<String, dynamic> properties) {
    trackEvent(
      name: 'user_properties_update',
      type: EventType.custom,
      properties: properties,
    );
  }

  /// 添加事件处理器
  void addProcessor(EventProcessor processor) {
    _processors.add(processor);
  }

  /// 移除事件处理器
  void removeProcessor(EventProcessor processor) {
    _processors.remove(processor);
    processor.dispose();
  }

  /// 排除事件
  void excludeEvent(String eventName) {
    _excludedEvents.add(eventName);
  }

  /// 取消排除事件
  void includeEvent(String eventName) {
    _excludedEvents.remove(eventName);
  }

  // ==================== 事件追踪 ====================

  /// 追踪通用事件
  void trackEvent({
    required String name,
    EventType type = EventType.custom,
    Map<String, dynamic> properties = const {},
    Map<String, dynamic>? context,
  }) {
    if (!_enabled || _excludedEvents.contains(name)) return;

    final event = AnalyticsEvent(
      eventId: _generateEventId(),
      type: type,
      name: name,
      properties: properties,
      sessionId: _currentSession?.sessionId,
      userId: _userId,
      deviceId: _deviceId,
      context: context,
    );

    _processEvent(event);
  }

  /// 追踪页面浏览
  void trackPageView({
    required PageType pageType,
    required String pageName,
    String? referrer,
    Duration? duration,
    Map<String, dynamic> properties = const {},
  }) {
    if (!_enabled) return;

    final event = PageViewEvent(
      eventId: _generateEventId(),
      pageType: pageType,
      pageName: pageName,
      referrer: referrer,
      duration: duration,
      properties: properties,
      sessionId: _currentSession?.sessionId,
      userId: _userId,
      deviceId: _deviceId,
    );

    _currentSession?.recordPageView(pageName);
    _processEvent(event);
  }

  /// 追踪用户操作
  void trackAction({
    required String name,
    required ActionType actionType,
    required String target,
    String? targetId,
    Map<String, dynamic> properties = const {},
  }) {
    if (!_enabled) return;

    final event = ActionEvent(
      eventId: _generateEventId(),
      name: name,
      actionType: actionType,
      target: target,
      targetId: targetId,
      properties: properties,
      sessionId: _currentSession?.sessionId,
      userId: _userId,
      deviceId: _deviceId,
    );

    _processEvent(event);
  }

  /// 追踪业务事件
  void trackBusinessEvent({
    required String name,
    required String businessType,
    double? value,
    String? currency,
    Map<String, dynamic> properties = const {},
  }) {
    if (!_enabled) return;

    final event = BusinessEvent(
      eventId: _generateEventId(),
      name: name,
      businessType: businessType,
      value: value,
      currency: currency,
      properties: properties,
      sessionId: _currentSession?.sessionId,
      userId: _userId,
      deviceId: _deviceId,
    );

    _processEvent(event);
  }

  // ==================== 预定义业务事件 ====================

  /// 记账事件
  void trackTransactionCreate({
    required String transactionType,
    required double amount,
    required String category,
    String? account,
    String? inputMethod,
  }) {
    trackBusinessEvent(
      name: 'transaction_create',
      businessType: 'transaction',
      value: amount,
      currency: 'CNY',
      properties: {
        'transaction_type': transactionType,
        'category': category,
        'account': account,
        'input_method': inputMethod,
      },
    );
  }

  /// 预算创建事件
  void trackBudgetCreate({
    required String category,
    required double amount,
    required String period,
  }) {
    trackBusinessEvent(
      name: 'budget_create',
      businessType: 'budget',
      value: amount,
      currency: 'CNY',
      properties: {
        'category': category,
        'period': period,
      },
    );
  }

  /// 预算调整事件
  void trackBudgetAdjust({
    required String budgetId,
    required double oldAmount,
    required double newAmount,
  }) {
    trackBusinessEvent(
      name: 'budget_adjust',
      businessType: 'budget',
      value: newAmount - oldAmount,
      currency: 'CNY',
      properties: {
        'budget_id': budgetId,
        'old_amount': oldAmount,
        'new_amount': newAmount,
      },
    );
  }

  /// 账户创建事件
  void trackAccountCreate({
    required String accountType,
    required String name,
    double? initialBalance,
  }) {
    trackBusinessEvent(
      name: 'account_create',
      businessType: 'account',
      value: initialBalance,
      currency: 'CNY',
      properties: {
        'account_type': accountType,
        'name': name,
      },
    );
  }

  /// AI 识别事件
  void trackAIRecognition({
    required String inputType, // text, voice, image
    required bool success,
    required double confidence,
    Duration? processingTime,
  }) {
    trackEvent(
      name: 'ai_recognition',
      type: EventType.business,
      properties: {
        'input_type': inputType,
        'success': success,
        'confidence': confidence,
        'processing_time_ms': processingTime?.inMilliseconds,
      },
    );
  }

  /// 资金年龄查看事件
  void trackMoneyAgeView({
    required double moneyAge,
    required String level,
  }) {
    trackEvent(
      name: 'money_age_view',
      type: EventType.business,
      properties: {
        'money_age': moneyAge,
        'level': level,
      },
    );
  }

  /// 搜索事件
  void trackSearch({
    required String query,
    required int resultCount,
    String? searchType,
  }) {
    trackEvent(
      name: 'search',
      type: EventType.action,
      properties: {
        'query': query,
        'result_count': resultCount,
        'search_type': searchType,
      },
    );
  }

  /// 分享事件
  void trackShare({
    required String contentType,
    required String shareMethod,
    String? contentId,
  }) {
    trackAction(
      name: 'share',
      actionType: ActionType.share,
      target: contentType,
      targetId: contentId,
      properties: {
        'share_method': shareMethod,
      },
    );
  }

  /// 功能使用事件
  void trackFeatureUsage({
    required String featureName,
    Map<String, dynamic> properties = const {},
  }) {
    trackEvent(
      name: 'feature_usage',
      type: EventType.business,
      properties: {
        'feature_name': featureName,
        ...properties,
      },
    );
  }

  // ==================== 性能事件 ====================

  /// 追踪性能事件
  void trackPerformance({
    required String name,
    required Duration duration,
    bool success = true,
    Map<String, dynamic> properties = const {},
  }) {
    if (!_enabled) return;

    trackEvent(
      name: name,
      type: EventType.performance,
      properties: {
        'duration_ms': duration.inMilliseconds,
        'success': success,
        ...properties,
      },
    );
  }

  /// 追踪页面加载时间
  void trackPageLoadTime({
    required String pageName,
    required Duration loadTime,
  }) {
    trackPerformance(
      name: 'page_load',
      duration: loadTime,
      properties: {'page_name': pageName},
    );
  }

  /// 追踪 API 调用时间
  void trackApiCallTime({
    required String endpoint,
    required Duration duration,
    required int statusCode,
  }) {
    trackPerformance(
      name: 'api_call',
      duration: duration,
      success: statusCode >= 200 && statusCode < 300,
      properties: {
        'endpoint': endpoint,
        'status_code': statusCode,
      },
    );
  }

  // ==================== 错误事件 ====================

  /// 追踪错误事件
  void trackError({
    required String errorType,
    required String message,
    String? stackTrace,
    Map<String, dynamic> properties = const {},
  }) {
    if (!_enabled) return;

    trackEvent(
      name: 'error',
      type: EventType.error,
      properties: {
        'error_type': errorType,
        'message': message,
        'stack_trace': stackTrace,
        ...properties,
      },
    );
  }

  // ==================== 内部方法 ====================

  String _generateEventId() {
    return 'evt_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _processEvent(AnalyticsEvent event) async {
    _currentSession?.recordEvent();

    for (final processor in _processors) {
      try {
        await processor.process(event);
      } catch (e) {
        // 忽略处理器错误
      }
    }
  }

  /// 刷新所有处理器
  Future<void> flush() async {
    for (final processor in _processors) {
      await processor.flush();
    }
  }

  /// 获取当前会话
  AnalyticsSession? get currentSession => _currentSession;

  /// 结束当前会话
  void endSession() {
    _currentSession?.end();
    flush();
  }

  /// 启用/禁用分析
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 是否启用
  bool get isEnabled => _enabled;

  /// 释放资源
  void dispose() {
    endSession();
    for (final processor in _processors) {
      processor.dispose();
    }
    _processors.clear();
    _initialized = false;
  }

  /// 重置（测试用）
  void reset() {
    dispose();
    _userId = null;
    _deviceId = null;
    _currentSession = null;
    _excludedEvents.clear();
  }
}

/// 全局分析服务实例
final analyticsService = UserBehaviorAnalyticsService();
