// 统一意图类型系统
//
// 整合了 VoiceIntentType 和 OperationType，提供统一的意图分类体系
//
// 设计原则：
// 1. 分层设计：主类别 + 子类别
// 2. 向后兼容：提供与旧类型的转换方法
// 3. 可扩展性：便于添加新的意图类型

/// 意图主类别
enum IntentCategory {
  /// 交易操作
  transaction,

  /// 导航操作
  navigation,

  /// 配置操作
  configuration,

  /// 数据操作
  data,

  /// 高级功能
  advanced,

  /// 自动化操作
  automation,

  /// 会话控制
  conversation,

  /// 系统操作
  system,

  /// 未知/其他
  unknown,
}

/// 统一意图类型
///
/// 采用 category.action 的命名规范，便于分组和路由
enum UnifiedIntentType {
  // ==================== 交易操作 ====================
  /// 添加交易（支出/收入/转账）
  transactionAdd('transaction.add', IntentCategory.transaction, '添加交易'),

  /// 查询交易
  transactionQuery('transaction.query', IntentCategory.transaction, '查询交易'),

  /// 修改交易
  transactionModify('transaction.modify', IntentCategory.transaction, '修改交易'),

  /// 删除交易
  transactionDelete('transaction.delete', IntentCategory.transaction, '删除交易'),

  // ==================== 导航操作 ====================
  /// 页面导航
  navigationPage('navigation.page', IntentCategory.navigation, '页面导航'),

  /// 返回上一页
  navigationBack('navigation.back', IntentCategory.navigation, '返回'),

  /// 返回首页
  navigationHome('navigation.home', IntentCategory.navigation, '返回首页'),

  // ==================== 配置操作 ====================
  /// 分类管理
  configCategory('config.category', IntentCategory.configuration, '分类管理'),

  /// 标签管理
  configTag('config.tag', IntentCategory.configuration, '标签管理'),

  /// 账本管理
  configLedger('config.ledger', IntentCategory.configuration, '账本管理'),

  /// 成员管理
  configMember('config.member', IntentCategory.configuration, '成员管理'),

  /// 信用卡管理
  configCreditCard('config.creditCard', IntentCategory.configuration, '信用卡管理'),

  /// 储蓄目标管理
  configSavingsGoal('config.savingsGoal', IntentCategory.configuration, '储蓄目标'),

  /// 定期交易管理
  configRecurring('config.recurring', IntentCategory.configuration, '定期交易'),

  /// 预算设置
  configBudget('config.budget', IntentCategory.configuration, '预算设置'),

  // ==================== 数据操作 ====================
  /// 数据导出
  dataExport('data.export', IntentCategory.data, '数据导出'),

  /// 数据备份
  dataBackup('data.backup', IntentCategory.data, '数据备份'),

  /// 数据统计
  dataStatistics('data.statistics', IntentCategory.data, '数据统计'),

  /// 生成报告
  dataReport('data.report', IntentCategory.data, '生成报告'),

  // ==================== 高级功能 ====================
  /// 小金库创建
  vaultCreate('vault.create', IntentCategory.advanced, '创建小金库'),

  /// 小金库查询
  vaultQuery('vault.query', IntentCategory.advanced, '查询小金库'),

  /// 小金库转账
  vaultTransfer('vault.transfer', IntentCategory.advanced, '小金库转账'),

  /// 小金库预算
  vaultBudget('vault.budget', IntentCategory.advanced, '小金库预算'),

  /// 钱龄查询
  moneyAgeQuery('moneyAge.query', IntentCategory.advanced, '钱龄查询'),

  /// 钱龄提醒
  moneyAgeReminder('moneyAge.reminder', IntentCategory.advanced, '钱龄提醒'),

  /// 钱龄报告
  moneyAgeReport('moneyAge.report', IntentCategory.advanced, '钱龄报告'),

  /// 习惯查询
  habitQuery('habit.query', IntentCategory.advanced, '习惯查询'),

  /// 习惯分析
  habitAnalysis('habit.analysis', IntentCategory.advanced, '习惯分析'),

  /// 习惯提醒
  habitReminder('habit.reminder', IntentCategory.advanced, '习惯提醒'),

  // ==================== 分享操作 ====================
  /// 分享交易
  shareTransaction('share.transaction', IntentCategory.advanced, '分享交易'),

  /// 分享报告
  shareReport('share.report', IntentCategory.advanced, '分享报告'),

  /// 分享预算
  shareBudget('share.budget', IntentCategory.advanced, '分享预算'),

  // ==================== 自动化操作 ====================
  /// 屏幕识别记账
  automationScreenRecognition('automation.screenRecognition', IntentCategory.automation, '屏幕识别'),

  /// 支付宝账单同步
  automationAlipaySync('automation.alipaySync', IntentCategory.automation, '支付宝同步'),

  /// 微信账单同步
  automationWechatSync('automation.wechatSync', IntentCategory.automation, '微信同步'),

  /// 银行账单同步
  automationBankSync('automation.bankSync', IntentCategory.automation, '银行同步'),

  /// 邮箱账单解析
  automationEmailParse('automation.emailParse', IntentCategory.automation, '邮箱账单'),

  /// 定时记账
  automationScheduled('automation.scheduled', IntentCategory.automation, '定时记账'),

  // ==================== 会话控制 ====================
  /// 确认操作
  conversationConfirm('conversation.confirm', IntentCategory.conversation, '确认'),

  /// 取消操作
  conversationCancel('conversation.cancel', IntentCategory.conversation, '取消'),

  /// 澄清选择
  conversationClarify('conversation.clarify', IntentCategory.conversation, '澄清'),

  /// 问候
  conversationGreeting('conversation.greeting', IntentCategory.conversation, '问候'),

  /// 帮助
  conversationHelp('conversation.help', IntentCategory.conversation, '帮助'),

  // ==================== 系统操作 ====================
  /// 系统设置
  systemSettings('system.settings', IntentCategory.system, '系统设置'),

  /// 关于信息
  systemAbout('system.about', IntentCategory.system, '关于'),

  /// 用户反馈
  systemFeedback('system.feedback', IntentCategory.system, '反馈'),

  // ==================== 未知 ====================
  /// 未知意图
  unknown('unknown', IntentCategory.unknown, '未知');

  /// 意图ID（用于路由匹配）
  final String id;

  /// 所属类别
  final IntentCategory category;

  /// 显示名称
  final String displayName;

  const UnifiedIntentType(this.id, this.category, this.displayName);

  /// 根据ID查找意图类型
  static UnifiedIntentType? fromId(String id) {
    for (final type in UnifiedIntentType.values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// 获取某个类别下的所有意图类型
  static List<UnifiedIntentType> byCategory(IntentCategory category) {
    return UnifiedIntentType.values
        .where((type) => type.category == category)
        .toList();
  }

  /// 是否为交易相关操作
  bool get isTransactionOperation => category == IntentCategory.transaction;

  /// 是否为需要确认的危险操作
  bool get requiresConfirmation {
    return this == transactionDelete ||
           this == transactionModify ||
           id.startsWith('config.') ||
           id.startsWith('data.');
  }

  /// 获取操作优先级
  OperationPriority get priority {
    switch (category) {
      case IntentCategory.navigation:
        return OperationPriority.immediate;
      case IntentCategory.conversation:
        return OperationPriority.immediate;
      case IntentCategory.transaction:
        if (this == transactionQuery) return OperationPriority.normal;
        return OperationPriority.deferred;
      case IntentCategory.data:
      case IntentCategory.automation:
        return OperationPriority.background;
      default:
        return OperationPriority.normal;
    }
  }
}

/// 操作优先级
enum OperationPriority {
  /// 立即执行（导航、会话控制）
  immediate,

  /// 正常执行（查询）
  normal,

  /// 延迟执行（记账，可聚合）
  deferred,

  /// 后台执行（批量操作、数据处理）
  background,
}

// ==================== 兼容层：与旧类型的转换 ====================

/// VoiceIntentType 到 UnifiedIntentType 的映射
/// 用于向后兼容 voice_service_coordinator.dart 中的 VoiceIntentType
extension VoiceIntentTypeMapping on UnifiedIntentType {
  /// 从旧的 VoiceIntentType 名称转换
  static UnifiedIntentType fromLegacyVoiceIntent(String legacyName) {
    switch (legacyName) {
      case 'unknown':
        return UnifiedIntentType.unknown;
      case 'deleteTransaction':
        return UnifiedIntentType.transactionDelete;
      case 'modifyTransaction':
        return UnifiedIntentType.transactionModify;
      case 'addTransaction':
        return UnifiedIntentType.transactionAdd;
      case 'queryTransaction':
        return UnifiedIntentType.transactionQuery;
      case 'navigateToPage':
        return UnifiedIntentType.navigationPage;
      case 'confirmAction':
        return UnifiedIntentType.conversationConfirm;
      case 'cancelAction':
        return UnifiedIntentType.conversationCancel;
      case 'clarifySelection':
        return UnifiedIntentType.conversationClarify;
      case 'screenRecognition':
        return UnifiedIntentType.automationScreenRecognition;
      case 'automateAlipaySync':
        return UnifiedIntentType.automationAlipaySync;
      case 'automateWeChatSync':
        return UnifiedIntentType.automationWechatSync;
      case 'configOperation':
        return UnifiedIntentType.configCategory; // 默认映射到分类管理
      case 'moneyAgeOperation':
        return UnifiedIntentType.moneyAgeQuery;
      case 'habitOperation':
        return UnifiedIntentType.habitQuery;
      case 'vaultOperation':
        return UnifiedIntentType.vaultQuery;
      case 'dataOperation':
        return UnifiedIntentType.dataStatistics;
      case 'shareOperation':
        return UnifiedIntentType.shareTransaction;
      case 'systemOperation':
        return UnifiedIntentType.systemSettings;
      default:
        return UnifiedIntentType.unknown;
    }
  }

  /// 转换为旧的 VoiceIntentType 名称（用于兼容）
  String toLegacyVoiceIntentName() {
    switch (this) {
      case UnifiedIntentType.unknown:
        return 'unknown';
      case UnifiedIntentType.transactionDelete:
        return 'deleteTransaction';
      case UnifiedIntentType.transactionModify:
        return 'modifyTransaction';
      case UnifiedIntentType.transactionAdd:
        return 'addTransaction';
      case UnifiedIntentType.transactionQuery:
        return 'queryTransaction';
      case UnifiedIntentType.navigationPage:
      case UnifiedIntentType.navigationBack:
      case UnifiedIntentType.navigationHome:
        return 'navigateToPage';
      case UnifiedIntentType.conversationConfirm:
        return 'confirmAction';
      case UnifiedIntentType.conversationCancel:
        return 'cancelAction';
      case UnifiedIntentType.conversationClarify:
        return 'clarifySelection';
      case UnifiedIntentType.automationScreenRecognition:
        return 'screenRecognition';
      case UnifiedIntentType.automationAlipaySync:
        return 'automateAlipaySync';
      case UnifiedIntentType.automationWechatSync:
        return 'automateWeChatSync';
      case UnifiedIntentType.configCategory:
      case UnifiedIntentType.configTag:
      case UnifiedIntentType.configLedger:
      case UnifiedIntentType.configMember:
      case UnifiedIntentType.configCreditCard:
      case UnifiedIntentType.configSavingsGoal:
      case UnifiedIntentType.configRecurring:
      case UnifiedIntentType.configBudget:
        return 'configOperation';
      case UnifiedIntentType.moneyAgeQuery:
      case UnifiedIntentType.moneyAgeReminder:
      case UnifiedIntentType.moneyAgeReport:
        return 'moneyAgeOperation';
      case UnifiedIntentType.habitQuery:
      case UnifiedIntentType.habitAnalysis:
      case UnifiedIntentType.habitReminder:
        return 'habitOperation';
      case UnifiedIntentType.vaultCreate:
      case UnifiedIntentType.vaultQuery:
      case UnifiedIntentType.vaultTransfer:
      case UnifiedIntentType.vaultBudget:
        return 'vaultOperation';
      case UnifiedIntentType.dataExport:
      case UnifiedIntentType.dataBackup:
      case UnifiedIntentType.dataStatistics:
      case UnifiedIntentType.dataReport:
        return 'dataOperation';
      case UnifiedIntentType.shareTransaction:
      case UnifiedIntentType.shareReport:
      case UnifiedIntentType.shareBudget:
        return 'shareOperation';
      case UnifiedIntentType.systemSettings:
      case UnifiedIntentType.systemAbout:
      case UnifiedIntentType.systemFeedback:
      case UnifiedIntentType.conversationHelp:
        return 'systemOperation';
      default:
        return 'unknown';
    }
  }
}

/// OperationType 到 UnifiedIntentType 的映射
/// 用于向后兼容 smart_intent_recognizer.dart 中的 OperationType
extension OperationTypeMapping on UnifiedIntentType {
  /// 从旧的 OperationType 名称转换
  static UnifiedIntentType fromLegacyOperationType(String legacyName) {
    switch (legacyName) {
      case 'addTransaction':
        return UnifiedIntentType.transactionAdd;
      case 'navigate':
        return UnifiedIntentType.navigationPage;
      case 'query':
        return UnifiedIntentType.transactionQuery;
      case 'modify':
        return UnifiedIntentType.transactionModify;
      case 'delete':
        return UnifiedIntentType.transactionDelete;
      case 'unknown':
      default:
        return UnifiedIntentType.unknown;
    }
  }

  /// 转换为旧的 OperationType 名称（用于兼容）
  String toLegacyOperationTypeName() {
    switch (this) {
      case UnifiedIntentType.transactionAdd:
        return 'addTransaction';
      case UnifiedIntentType.navigationPage:
      case UnifiedIntentType.navigationBack:
      case UnifiedIntentType.navigationHome:
        return 'navigate';
      case UnifiedIntentType.transactionQuery:
        return 'query';
      case UnifiedIntentType.transactionModify:
        return 'modify';
      case UnifiedIntentType.transactionDelete:
        return 'delete';
      default:
        return 'unknown';
    }
  }
}

/// 意图识别结果（使用统一意图类型）
class UnifiedIntentResult {
  /// 识别到的意图类型
  final UnifiedIntentType intentType;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 提取的参数槽位
  final Map<String, dynamic> slots;

  /// 原始输入文本
  final String? rawInput;

  /// 识别来源
  final String? source;

  const UnifiedIntentResult({
    required this.intentType,
    required this.confidence,
    this.slots = const {},
    this.rawInput,
    this.source,
  });

  /// 是否为高置信度结果
  bool get isHighConfidence => confidence >= 0.8;

  /// 是否需要额外确认
  bool get needsConfirmation =>
      intentType.requiresConfirmation && confidence < 0.9;

  @override
  String toString() {
    return 'UnifiedIntentResult(type: ${intentType.id}, '
           'confidence: ${confidence.toStringAsFixed(2)}, '
           'slots: $slots)';
  }
}
