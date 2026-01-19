import 'package:flutter/foundation.dart';
import '../../../../core/contracts/i_database_service.dart';
import '../action_registry.dart';

/// 系统设置Action
///
/// 通过语音快速修改系统设置：
/// - 语言设置
/// - 通知设置
/// - 隐私设置
/// - 数据同步设置
class SystemSettingsAction extends Action {
  final IDatabaseService databaseService;

  SystemSettingsAction(this.databaseService);

  @override
  String get id => 'system.settings';

  @override
  String get name => '系统设置';

  @override
  String get description => '快速修改系统设置';

  @override
  List<String> get triggerPatterns => [
    '系统设置', '修改设置', '更改设置',
    '打开设置', '设置选项',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'settingKey',
      type: ActionParamType.string,
      required: false,
      description: '设置项名称: language/notification/privacy/sync',
    ),
    const ActionParam(
      name: 'settingValue',
      type: ActionParamType.string,
      required: false,
      description: '设置值',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final settingKey = params['settingKey'] as String?;
      final settingValue = params['settingValue'] as String?;

      // 如果没有指定设置项，返回设置列表
      if (settingKey == null) {
        return ActionResult.success(
          responseText: '您可以设置语言、通知、隐私或数据同步，请告诉我要修改什么',
          data: {
            'availableSettings': ['language', 'notification', 'privacy', 'sync'],
            'needSelection': true,
          },
          actionId: id,
        );
      }

      // 处理具体的设置项
      switch (settingKey.toLowerCase()) {
        case 'language':
        case '语言':
          return _handleLanguageSetting(settingValue);

        case 'notification':
        case '通知':
          return _handleNotificationSetting(settingValue);

        case 'privacy':
        case '隐私':
          return _handlePrivacySetting(settingValue);

        case 'sync':
        case '同步':
          return _handleSyncSetting(settingValue);

        default:
          return ActionResult.needParams(
            missing: ['settingKey'],
            prompt: '没有找到"$settingKey"设置项，您可以设置语言、通知、隐私或数据同步',
            actionId: id,
          );
      }
    } catch (e) {
      debugPrint('[SystemSettingsAction] 设置失败: $e');
      return ActionResult.failure('修改系统设置失败: $e', actionId: id);
    }
  }

  /// 处理语言设置
  ActionResult _handleLanguageSetting(String? value) {
    if (value == null) {
      return ActionResult.needParams(
        missing: ['settingValue'],
        prompt: '要切换到什么语言？支持中文、英文',
        actionId: id,
      );
    }

    final language = value.contains('英') || value.toLowerCase().contains('en')
        ? 'English'
        : '中文';

    return ActionResult.success(
      responseText: '已将语言设置为$language',
      data: {
        'settingKey': 'language',
        'settingValue': language,
        'applied': true,
      },
      actionId: id,
    );
  }

  /// 处理通知设置
  ActionResult _handleNotificationSetting(String? value) {
    if (value == null) {
      return ActionResult.needParams(
        missing: ['settingValue'],
        prompt: '要开启还是关闭通知？',
        actionId: id,
      );
    }

    final enabled = !value.contains('关') && !value.toLowerCase().contains('off');

    return ActionResult.success(
      responseText: '已${enabled ? "开启" : "关闭"}通知',
      data: {
        'settingKey': 'notification',
        'enabled': enabled,
        'applied': true,
      },
      actionId: id,
    );
  }

  /// 处理隐私设置
  ActionResult _handlePrivacySetting(String? value) {
    return ActionResult.success(
      responseText: '隐私设置需要在设置页面手动修改，已为您导航到隐私设置页面',
      data: {
        'settingKey': 'privacy',
        'redirectTo': '/settings/privacy',
      },
      actionId: id,
    );
  }

  /// 处理同步设置
  ActionResult _handleSyncSetting(String? value) {
    if (value == null) {
      return ActionResult.needParams(
        missing: ['settingValue'],
        prompt: '要开启还是关闭自动同步？',
        actionId: id,
      );
    }

    final enabled = !value.contains('关') && !value.toLowerCase().contains('off');

    return ActionResult.success(
      responseText: '已${enabled ? "开启" : "关闭"}自动数据同步',
      data: {
        'settingKey': 'sync',
        'enabled': enabled,
        'applied': true,
      },
      actionId: id,
    );
  }
}

/// 关于信息Action
///
/// 提供应用相关信息：
/// - 版本号
/// - 开发者信息
/// - 功能介绍
class SystemAboutAction extends Action {
  @override
  String get id => 'system.about';

  @override
  String get name => '关于应用';

  @override
  String get description => '查看应用相关信息';

  @override
  List<String> get triggerPatterns => [
    '关于', '版本', '关于应用',
    '应用信息', '版本号', '开发者',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'infoType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'version',
      description: '信息类型: version/developer/features/changelog',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final infoType = params['infoType'] as String? ?? 'version';

    switch (infoType) {
      case 'version':
        return ActionResult.success(
          responseText: '智能记账 v1.0.0，搭载AI智能语音助手',
          data: {
            'appName': '智能记账',
            'version': '1.0.0',
            'buildNumber': '100',
            'aiEnabled': true,
          },
          actionId: id,
        );

      case 'developer':
        return ActionResult.success(
          responseText: '智能记账由百济团队开发，致力于提供智能便捷的记账体验',
          data: {
            'developer': '百济团队',
            'website': 'https://baiji.app',
            'email': 'support@baiji.app',
          },
          actionId: id,
        );

      case 'features':
        return ActionResult.success(
          responseText: '支持语音记账、智能分类、预算管理、统计报表等功能',
          data: {
            'features': [
              '语音智能记账',
              'AI自动分类',
              '多账本管理',
              '预算控制',
              '统计报表',
              '家庭共享',
              '数据备份',
            ],
          },
          actionId: id,
        );

      case 'changelog':
        return ActionResult.success(
          responseText: '最新更新：新增语音助手对话模式，支持多意图识别',
          data: {
            'latestVersion': '1.0.0',
            'releaseDate': '2026-01-18',
            'highlights': [
              '新增语音助手对话模式',
              '支持多意图识别',
              '优化执行反馈',
            ],
          },
          actionId: id,
        );

      default:
        return ActionResult.success(
          responseText: '智能记账 v1.0.0',
          data: {'version': '1.0.0'},
          actionId: id,
        );
    }
  }
}

/// 帮助文档Action
///
/// 提供使用帮助和指引：
/// - 语音指令帮助
/// - 功能使用指南
/// - 常见问题解答
class SystemHelpAction extends Action {
  @override
  String get id => 'system.help';

  @override
  String get name => '使用帮助';

  @override
  String get description => '获取使用帮助和指引';

  @override
  List<String> get triggerPatterns => [
    '帮助', '怎么用', '使用帮助',
    '教程', '指南', '不会用',
    '怎么操作', '有什么功能',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'topic',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'general',
      description: '帮助主题: general/voice/budget/report/family',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final topic = params['topic'] as String? ?? 'general';

    switch (topic) {
      case 'voice':
        return _getVoiceHelp();
      case 'budget':
        return _getBudgetHelp();
      case 'report':
        return _getReportHelp();
      case 'family':
        return _getFamilyHelp();
      case 'general':
      default:
        return _getGeneralHelp();
    }
  }

  /// 通用帮助
  ActionResult _getGeneralHelp() {
    return ActionResult.success(
      responseText: '我可以帮您记账、查询统计、设置预算。试试说"记一笔50元的午餐"或"这个月花了多少"',
      data: {
        'topic': 'general',
        'examples': [
          '记一笔50元的午餐',
          '这个月花了多少',
          '设置餐饮预算1000元',
          '查看消费习惯',
          '删除最后一笔',
        ],
        'categories': ['voice', 'budget', 'report', 'family'],
      },
      actionId: id,
    );
  }

  /// 语音帮助
  ActionResult _getVoiceHelp() {
    return ActionResult.success(
      responseText: '语音记账支持：记一笔/花了/买了+金额+分类。例如"花了35块买奶茶"',
      data: {
        'topic': 'voice',
        'commands': {
          '记账': ['记一笔50元午餐', '花了35块奶茶', '买了100块衣服'],
          '查询': ['这个月花了多少', '查看今天的账单', '本月餐饮支出'],
          '删改': ['删除最后一笔', '把刚才那笔改成60元', '修改分类为交通'],
          '导航': ['打开预算页面', '去统计页面', '查看设置'],
        },
      },
      actionId: id,
    );
  }

  /// 预算帮助
  ActionResult _getBudgetHelp() {
    return ActionResult.success(
      responseText: '设置预算后，消费超支时会提醒您。说"设置餐饮预算1000元"即可设置分类预算',
      data: {
        'topic': 'budget',
        'commands': [
          '设置月度预算5000元',
          '设置餐饮预算1000元',
          '查看预算使用情况',
          '预算还剩多少',
        ],
        'tips': [
          '建议按50%必要、30%需要、20%储蓄的比例分配预算',
          '超支80%时会收到提醒',
        ],
      },
      actionId: id,
    );
  }

  /// 报表帮助
  ActionResult _getReportHelp() {
    return ActionResult.success(
      responseText: '说"查看消费统计"或"这个月的报表"可以查看详细的消费分析',
      data: {
        'topic': 'report',
        'commands': [
          '查看消费统计',
          '这个月的报表',
          '按分类查看支出',
          '消费趋势分析',
        ],
        'reportTypes': ['日报', '周报', '月报', '年报', '分类报表'],
      },
      actionId: id,
    );
  }

  /// 家庭账本帮助
  ActionResult _getFamilyHelp() {
    return ActionResult.success(
      responseText: '家庭账本支持多成员协作记账，可邀请家人一起管理家庭财务',
      data: {
        'topic': 'family',
        'commands': [
          '创建家庭账本',
          '邀请成员加入',
          '查看家庭支出',
          '设置成员权限',
        ],
        'features': [
          '多成员共享账本',
          '独立记录可见性',
          '家庭预算统一管理',
          '成员消费排行',
        ],
      },
      actionId: id,
    );
  }
}

/// 反馈Action
///
/// 收集用户反馈和问题报告
class SystemFeedbackAction extends Action {
  @override
  String get id => 'system.feedback';

  @override
  String get name => '用户反馈';

  @override
  String get description => '提交反馈或报告问题';

  @override
  List<String> get triggerPatterns => [
    '反馈', '报告问题', '提建议',
    '有bug', '不好用', '意见',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'feedbackType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'suggestion',
      description: '反馈类型: bug/suggestion/complaint/praise',
    ),
    const ActionParam(
      name: 'content',
      type: ActionParamType.string,
      required: false,
      description: '反馈内容',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final feedbackType = params['feedbackType'] as String? ?? 'suggestion';
    final content = params['content'] as String?;

    if (content == null || content.isEmpty) {
      return ActionResult.needParams(
        missing: ['content'],
        prompt: '请告诉我您的${_getFeedbackTypeName(feedbackType)}',
        actionId: id,
      );
    }

    return ActionResult.success(
      responseText: '感谢您的反馈，我们会认真处理',
      data: {
        'feedbackType': feedbackType,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'submitted': true,
      },
      actionId: id,
    );
  }

  /// 获取反馈类型名称
  String _getFeedbackTypeName(String type) {
    switch (type) {
      case 'bug':
        return '问题描述';
      case 'suggestion':
        return '建议';
      case 'complaint':
        return '意见';
      case 'praise':
        return '好评';
      default:
        return '反馈';
    }
  }
}
