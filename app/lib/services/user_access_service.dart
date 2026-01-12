import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户类型
enum UserType {
  /// 访客 - 可使用所有非AI功能
  guest,

  /// 登录用户 - 可使用所有功能（包括AI大模型功能）
  loggedIn,
}

/// 功能分类
enum FeatureCategory {
  /// 基础功能 - 访客可用
  basic,

  /// AI功能 - 仅登录用户可用（需调用大模型）
  aiPowered,
}

/// 功能定义
class FeatureDefinition {
  /// 功能ID
  final String id;

  /// 功能名称
  final String name;

  /// 功能描述
  final String? description;

  /// 功能分类
  final FeatureCategory category;

  /// 最低用户类型要求
  final UserType requiredUserType;

  /// 是否需要调用大模型
  final bool requiresLLM;

  const FeatureDefinition({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.requiredUserType,
    this.requiresLLM = false,
  });

  /// 检查用户是否可访问此功能
  bool canAccess(UserType userType) {
    if (requiredUserType == UserType.guest) {
      return true; // 访客功能所有人可用
    }
    return userType == UserType.loggedIn;
  }
}

/// 用户会话信息
class UserSession {
  /// 用户ID（访客为null）
  final String? userId;

  /// 用户类型
  final UserType userType;

  /// 用户名
  final String? username;

  /// 邮箱
  final String? email;

  /// 登录时间
  final DateTime? loginTime;

  /// 会话过期时间
  final DateTime? expiresAt;

  const UserSession({
    this.userId,
    required this.userType,
    this.username,
    this.email,
    this.loginTime,
    this.expiresAt,
  });

  /// 访客会话
  factory UserSession.guest() {
    return const UserSession(userType: UserType.guest);
  }

  /// 登录用户会话
  factory UserSession.loggedIn({
    required String userId,
    String? username,
    String? email,
    DateTime? expiresAt,
  }) {
    return UserSession(
      userId: userId,
      userType: UserType.loggedIn,
      username: username,
      email: email,
      loginTime: DateTime.now(),
      expiresAt: expiresAt,
    );
  }

  bool get isGuest => userType == UserType.guest;
  bool get isLoggedIn => userType == UserType.loggedIn;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userType': userType.name,
      'username': username,
      'email': email,
      'loginTime': loginTime?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId'] as String?,
      userType: UserType.values.byName(json['userType'] as String),
      username: json['username'] as String?,
      email: json['email'] as String?,
      loginTime: json['loginTime'] != null
          ? DateTime.parse(json['loginTime'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// 功能访问检查结果
class FeatureAccessResult {
  /// 是否可访问
  final bool canAccess;

  /// 拒绝原因
  final String? deniedReason;

  /// 需要的用户类型
  final UserType? requiredUserType;

  /// 当前用户类型
  final UserType? currentUserType;

  const FeatureAccessResult({
    required this.canAccess,
    this.deniedReason,
    this.requiredUserType,
    this.currentUserType,
  });

  factory FeatureAccessResult.allowed() {
    return const FeatureAccessResult(canAccess: true);
  }

  factory FeatureAccessResult.denied({
    required String reason,
    required UserType required,
    required UserType current,
  }) {
    return FeatureAccessResult(
      canAccess: false,
      deniedReason: reason,
      requiredUserType: required,
      currentUserType: current,
    );
  }
}

/// 用户访问控制服务
///
/// 实现用户权限策略：
/// - 全免费版本
/// - 访客：首月可使用所有AI功能（试用期），之后仅可使用基础功能
/// - 登录用户：可使用所有功能（包括AI大模型功能）
///
/// 对应设计文档：第35章 用户体系与权限设计
class UserAccessService extends ChangeNotifier {
  static final UserAccessService _instance = UserAccessService._();
  factory UserAccessService() => _instance;
  UserAccessService._();

  UserSession _session = UserSession.guest();
  bool _initialized = false;

  // 功能注册表
  final Map<String, FeatureDefinition> _features = {};

  // 会话变更监听器
  final List<void Function(UserSession)> _sessionListeners = [];

  // 首次使用日期存储键
  static const String _firstUseDateKey = 'first_use_date';

  // 试用期天数
  static const int _trialPeriodDays = 30;

  // 首次使用日期
  DateTime? _firstUseDate;

  /// 初始化服务
  Future<void> initialize({UserSession? savedSession}) async {
    if (_initialized) return;

    // 注册所有功能定义
    _registerFeatures();

    // 加载或设置首次使用日期
    await _loadOrSetFirstUseDate();

    // 恢复保存的会话
    if (savedSession != null && !savedSession.isExpired) {
      _session = savedSession;
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint('UserAccessService initialized: ${_session.userType.name}');
      debugPrint('Trial period: ${isInTrialPeriod ? "有效" : "已过期"} (首次使用: $_firstUseDate)');
    }
  }

  /// 加载或设置首次使用日期
  Future<void> _loadOrSetFirstUseDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_firstUseDateKey);

      if (savedDate != null) {
        _firstUseDate = DateTime.parse(savedDate);
      } else {
        // 首次使用，记录当前日期
        _firstUseDate = DateTime.now();
        await prefs.setString(_firstUseDateKey, _firstUseDate!.toIso8601String());
        debugPrint('UserAccessService: 记录首次使用日期: $_firstUseDate');
      }
    } catch (e) {
      debugPrint('UserAccessService: 加载首次使用日期失败: $e');
      _firstUseDate = DateTime.now();
    }
  }

  /// 是否在试用期内（首次使用后30天内）
  bool get isInTrialPeriod {
    if (_firstUseDate == null) return true; // 未初始化时默认允许

    final now = DateTime.now();
    final trialEndDate = _firstUseDate!.add(const Duration(days: _trialPeriodDays));
    return now.isBefore(trialEndDate);
  }

  /// 获取试用期剩余天数
  int get trialDaysRemaining {
    if (_firstUseDate == null) return _trialPeriodDays;

    final now = DateTime.now();
    final trialEndDate = _firstUseDate!.add(const Duration(days: _trialPeriodDays));
    final remaining = trialEndDate.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// 获取首次使用日期
  DateTime? get firstUseDate => _firstUseDate;

  /// 当前会话
  UserSession get session => _session;

  /// 当前用户类型
  UserType get userType => _session.userType;

  /// 是否是访客
  bool get isGuest => _session.isGuest;

  /// 是否已登录
  bool get isLoggedIn => _session.isLoggedIn;

  /// 登录
  Future<void> login({
    required String userId,
    String? username,
    String? email,
    Duration sessionDuration = const Duration(days: 30),
  }) async {
    _session = UserSession.loggedIn(
      userId: userId,
      username: username,
      email: email,
      expiresAt: DateTime.now().add(sessionDuration),
    );

    _notifySessionChange();
    notifyListeners();

    if (kDebugMode) {
      debugPrint('User logged in: $userId');
    }
  }

  /// 登出（切换为访客）
  Future<void> logout() async {
    _session = UserSession.guest();
    _notifySessionChange();
    notifyListeners();

    if (kDebugMode) {
      debugPrint('User logged out, switched to guest');
    }
  }

  /// 检查功能是否可访问
  FeatureAccessResult checkFeatureAccess(String featureId) {
    final feature = _features[featureId];
    if (feature == null) {
      // 未注册的功能默认允许访问
      return FeatureAccessResult.allowed();
    }

    // 基础功能所有人可用
    if (feature.canAccess(_session.userType)) {
      return FeatureAccessResult.allowed();
    }

    // AI功能：登录用户或试用期内的访客可用
    if (feature.requiresLLM && (_session.isLoggedIn || isInTrialPeriod)) {
      return FeatureAccessResult.allowed();
    }

    return FeatureAccessResult.denied(
      reason: _getAccessDeniedMessage(feature),
      required: feature.requiredUserType,
      current: _session.userType,
    );
  }

  /// 检查功能是否可用（简化版）
  bool canAccessFeature(String featureId) {
    return checkFeatureAccess(featureId).canAccess;
  }

  /// 检查是否可以使用AI功能
  /// 登录用户或试用期内的访客都可以使用AI功能
  bool canUseAIFeatures() {
    return _session.isLoggedIn || isInTrialPeriod;
  }

  /// 获取功能的访问拒绝消息
  String _getAccessDeniedMessage(FeatureDefinition feature) {
    if (feature.requiresLLM) {
      if (isGuest && !isInTrialPeriod) {
        return '${feature.name}的试用期已结束，登录后可继续使用AI智能功能';
      }
      return '${feature.name}需要登录后才能使用，登录后可享受AI智能功能';
    }
    return '${feature.name}需要登录后才能使用';
  }

  /// 获取所有功能定义
  Map<String, FeatureDefinition> getAllFeatures() {
    return Map.unmodifiable(_features);
  }

  /// 获取访客可用的功能
  List<FeatureDefinition> getGuestFeatures() {
    return _features.values
        .where((f) => f.requiredUserType == UserType.guest)
        .toList();
  }

  /// 获取仅登录用户可用的功能（AI功能）
  List<FeatureDefinition> getLoginOnlyFeatures() {
    return _features.values
        .where((f) => f.requiredUserType == UserType.loggedIn)
        .toList();
  }

  /// 添加会话变更监听器
  void addSessionListener(void Function(UserSession) listener) {
    _sessionListeners.add(listener);
  }

  /// 移除会话变更监听器
  void removeSessionListener(void Function(UserSession) listener) {
    _sessionListeners.remove(listener);
  }

  void _notifySessionChange() {
    for (final listener in _sessionListeners) {
      listener(_session);
    }
  }

  /// 注册功能定义
  void _registerFeatures() {
    // ==================== 基础功能（访客可用）====================

    // 记账功能
    _registerFeature(const FeatureDefinition(
      id: 'manual_transaction',
      name: '手动记账',
      description: '手动输入收支记录',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'transaction_list',
      name: '交易列表',
      description: '查看和管理交易记录',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'transaction_search',
      name: '交易搜索',
      description: '搜索和筛选交易',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 账户管理
    _registerFeature(const FeatureDefinition(
      id: 'account_management',
      name: '账户管理',
      description: '管理银行卡、现金等账户',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 分类管理
    _registerFeature(const FeatureDefinition(
      id: 'category_management',
      name: '分类管理',
      description: '管理收支分类',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 预算功能（手动）
    _registerFeature(const FeatureDefinition(
      id: 'manual_budget',
      name: '手动预算',
      description: '手动设置和管理预算',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'budget_tracking',
      name: '预算追踪',
      description: '追踪预算执行情况',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 零基预算（本地计算）
    _registerFeature(const FeatureDefinition(
      id: 'zero_based_budget',
      name: '零基预算',
      description: '零基预算分配管理',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 小金库
    _registerFeature(const FeatureDefinition(
      id: 'budget_vault',
      name: '小金库',
      description: '专项资金池管理',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 钱龄系统（本地算法）
    _registerFeature(const FeatureDefinition(
      id: 'money_age',
      name: '钱龄分析',
      description: 'FIFO钱龄计算与分析',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'money_age_trend',
      name: '钱龄趋势',
      description: '钱龄历史趋势图表',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 统计报表（本地计算）
    _registerFeature(const FeatureDefinition(
      id: 'statistics_report',
      name: '统计报表',
      description: '收支统计和报表',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'charts_visualization',
      name: '图表可视化',
      description: '数据可视化图表',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 数据导入导出
    _registerFeature(const FeatureDefinition(
      id: 'data_import',
      name: '数据导入',
      description: '导入账单数据',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    _registerFeature(const FeatureDefinition(
      id: 'data_export',
      name: '数据导出',
      description: '导出账单数据',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 位置服务（GPS，非AI）
    _registerFeature(const FeatureDefinition(
      id: 'location_service',
      name: '位置服务',
      description: 'GPS定位和地理围栏',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 习惯追踪（本地统计）
    _registerFeature(const FeatureDefinition(
      id: 'habit_tracking',
      name: '习惯追踪',
      description: '消费习惯统计',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 打卡成就
    _registerFeature(const FeatureDefinition(
      id: 'achievements',
      name: '打卡成就',
      description: '成就系统和打卡',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 家庭账本（基础功能）
    _registerFeature(const FeatureDefinition(
      id: 'family_ledger',
      name: '家庭账本',
      description: '家庭共享账本',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 提醒通知
    _registerFeature(const FeatureDefinition(
      id: 'reminders',
      name: '提醒通知',
      description: '预算和账单提醒',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // 主题设置
    _registerFeature(const FeatureDefinition(
      id: 'theme_settings',
      name: '主题设置',
      description: '应用主题和外观',
      category: FeatureCategory.basic,
      requiredUserType: UserType.guest,
    ));

    // ==================== AI功能（仅登录用户）====================

    // 语音识别
    _registerFeature(const FeatureDefinition(
      id: 'voice_recognition',
      name: 'AI语音记账',
      description: '语音输入自动识别记账',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 图像识别
    _registerFeature(const FeatureDefinition(
      id: 'image_recognition',
      name: 'AI图像识别',
      description: '拍照识别票据和截图',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // OCR识别
    _registerFeature(const FeatureDefinition(
      id: 'ocr_recognition',
      name: 'OCR文字识别',
      description: '识别图片中的文字',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 自然语言理解
    _registerFeature(const FeatureDefinition(
      id: 'nlu_understanding',
      name: 'AI意图理解',
      description: '自然语言意图识别',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 智能分类
    _registerFeature(const FeatureDefinition(
      id: 'smart_category',
      name: 'AI智能分类',
      description: 'AI自动分类建议',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 智能预算建议
    _registerFeature(const FeatureDefinition(
      id: 'smart_budget_suggestion',
      name: 'AI预算建议',
      description: 'AI智能预算分配建议',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 对话式交互
    _registerFeature(const FeatureDefinition(
      id: 'conversational_interaction',
      name: 'AI对话交互',
      description: '多轮对话式记账和查询',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 异常消费检测
    _registerFeature(const FeatureDefinition(
      id: 'anomaly_detection',
      name: 'AI异常检测',
      description: 'AI检测异常消费模式',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 智能洞察
    _registerFeature(const FeatureDefinition(
      id: 'smart_insights',
      name: 'AI智能洞察',
      description: 'AI生成消费洞察和建议',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 趋势预测
    _registerFeature(const FeatureDefinition(
      id: 'trend_prediction',
      name: 'AI趋势预测',
      description: 'AI预测消费趋势',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 自学习系统
    _registerFeature(const FeatureDefinition(
      id: 'self_learning',
      name: 'AI自学习',
      description: '学习用户习惯提升识别准确率',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 智能TTS语音播报
    _registerFeature(const FeatureDefinition(
      id: 'smart_tts',
      name: 'AI语音播报',
      description: 'AI生成语音反馈',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 账单解析（AI增强）
    _registerFeature(const FeatureDefinition(
      id: 'smart_bill_parsing',
      name: 'AI账单解析',
      description: 'AI智能解析复杂账单',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 多笔交易智能拆分
    _registerFeature(const FeatureDefinition(
      id: 'smart_transaction_split',
      name: 'AI交易拆分',
      description: 'AI自动拆分多笔交易',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));

    // 协同学习（云端AI）
    _registerFeature(const FeatureDefinition(
      id: 'collaborative_learning',
      name: 'AI协同学习',
      description: '云端协同模型优化',
      category: FeatureCategory.aiPowered,
      requiredUserType: UserType.loggedIn,
      requiresLLM: true,
    ));
  }

  void _registerFeature(FeatureDefinition feature) {
    _features[feature.id] = feature;
  }

  /// 关闭服务
  Future<void> close() async {
    _sessionListeners.clear();
    _features.clear();
    _session = UserSession.guest();
    _initialized = false;
  }
}

/// 全局用户访问服务实例
final userAccess = UserAccessService();
