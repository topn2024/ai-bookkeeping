import '../action_registry.dart';
import '../../knowledge_base_service.dart';

/// 会话确认操作
///
/// 用于确认待执行的操作
class ConversationConfirmAction extends Action {
  /// 确认回调
  final void Function(Map<String, dynamic> pendingAction)? onConfirm;

  ConversationConfirmAction({this.onConfirm});

  @override
  String get id => 'conversation.confirm';

  @override
  String get name => '确认操作';

  @override
  String get description => '确认待执行的操作';

  @override
  List<String> get triggerPatterns => [
    '确认', '确定', '好的', '是的', '对', '可以',
    '没问题', '行', '嗯', '好', '是',
    'yes', 'ok', 'confirm',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'pendingActionId',
      type: ActionParamType.string,
      required: false,
      description: '待确认的操作ID',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final pendingActionId = params['pendingActionId'] as String?;
    final pendingAction = params['pendingAction'] as Map<String, dynamic>?;

    if (pendingAction != null) {
      onConfirm?.call(pendingAction);
    }

    return ActionResult.success(
      responseText: '好的，已确认',
      data: {
        'confirmed': true,
        'pendingActionId': pendingActionId,
      },
      actionId: id,
    );
  }
}

/// 会话取消操作
///
/// 用于取消待执行的操作
class ConversationCancelAction extends Action {
  /// 取消回调
  final void Function()? onCancel;

  ConversationCancelAction({this.onCancel});

  @override
  String get id => 'conversation.cancel';

  @override
  String get name => '取消操作';

  @override
  String get description => '取消待执行的操作';

  @override
  List<String> get triggerPatterns => [
    '取消', '算了', '不要', '不用', '停止',
    '不', '别', '放弃', '作罢',
    'cancel', 'no', 'stop',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    onCancel?.call();

    return ActionResult.success(
      responseText: '好的，已取消',
      data: {'cancelled': true},
      actionId: id,
    );
  }
}

/// 会话澄清操作
///
/// 用于用户选择或澄清歧义
class ConversationClarifyAction extends Action {
  @override
  String get id => 'conversation.clarify';

  @override
  String get name => '澄清选择';

  @override
  String get description => '澄清歧义或做出选择';

  @override
  List<String> get triggerPatterns => [
    '第一个', '第二个', '第三个',
    '选择', '选', '就是',
    '这个', '那个', '上面的', '下面的',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'selection',
      type: ActionParamType.string,
      required: false,
      description: '用户选择',
    ),
    const ActionParam(
      name: 'selectionIndex',
      type: ActionParamType.number,
      required: false,
      description: '选择索引(0-based)',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final selection = params['selection'] as String?;
    final selectionIndex = params['selectionIndex'] as int?;

    return ActionResult.success(
      responseText: '好的，已选择',
      data: {
        'clarified': true,
        'selection': selection,
        'selectionIndex': selectionIndex,
      },
      actionId: id,
    );
  }
}

/// 问候操作
///
/// 响应用户问候
class ConversationGreetingAction extends Action {
  @override
  String get id => 'conversation.greeting';

  @override
  String get name => '问候';

  @override
  String get description => '响应用户问候';

  @override
  List<String> get triggerPatterns => [
    '你好', '您好', '嗨', 'hi', 'hello',
    '早上好', '上午好', '中午好', '下午好', '晚上好',
    '早安', '午安', '晚安',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final now = DateTime.now();
    String greeting;

    if (now.hour < 6) {
      greeting = '夜深了，还没休息吗？有什么需要帮忙的？';
    } else if (now.hour < 9) {
      greeting = '早上好！新的一天开始了，有什么需要记录的吗？';
    } else if (now.hour < 12) {
      greeting = '上午好！有什么可以帮您的？';
    } else if (now.hour < 14) {
      greeting = '中午好！吃饭了吗？要记录午餐消费吗？';
    } else if (now.hour < 18) {
      greeting = '下午好！有什么需要帮忙的？';
    } else if (now.hour < 22) {
      greeting = '晚上好！今天的消费都记录了吗？';
    } else {
      greeting = '夜深了，有什么需要快速记一下的吗？';
    }

    return ActionResult.success(
      responseText: greeting,
      data: {'greeting': greeting},
      actionId: id,
    );
  }
}

/// 帮助操作
///
/// 提供使用帮助，集成知识库进行智能问答
class ConversationHelpAction extends Action {
  /// 知识库服务
  final KnowledgeBaseService? _knowledgeBase;

  ConversationHelpAction({KnowledgeBaseService? knowledgeBase})
      : _knowledgeBase = knowledgeBase;

  @override
  String get id => 'conversation.help';

  @override
  String get name => '帮助';

  @override
  String get description => '提供使用帮助和功能说明';

  @override
  List<String> get triggerPatterns => [
    '帮助', '怎么用', '如何使用', '使用说明',
    '功能', '能做什么', '有什么功能',
    'help', '教我', '指导',
    // 系统相关问题触发词
    '什么是', '怎么', '如何', '为什么',
    '是什么', '干什么', '做什么',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'topic',
      type: ActionParamType.string,
      required: false,
      description: '帮助主题',
    ),
    const ActionParam(
      name: 'rawInput',
      type: ActionParamType.string,
      required: false,
      description: '用户原始输入',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final topic = params['topic'] as String?;
    final rawInput = params['rawInput'] as String?;

    String helpText;
    Map<String, dynamic> helpData;

    // 优先从知识库查找答案
    final knowledgeBase = _knowledgeBase;
    if (knowledgeBase != null) {
      final query = rawInput ?? topic;
      if (query != null && query.isNotEmpty) {
        final kbAnswer = knowledgeBase.getVoiceAnswer(query);
        // 如果知识库有答案且不是默认的"抱歉"回复
        if (!kbAnswer.startsWith('抱歉')) {
          return ActionResult.success(
            responseText: kbAnswer,
            data: {
              'source': 'knowledge_base',
              'query': query,
              'answer': kbAnswer,
            },
            actionId: id,
          );
        }
      }
    }

    // 知识库没有答案，使用内置帮助
    if (topic != null) {
      // 特定主题帮助
      helpText = _getTopicHelp(topic);
      helpData = {'topic': topic, 'help': helpText, 'source': 'builtin'};
    } else {
      // 通用帮助
      helpText = '我可以帮您：记账（如"午餐30"）、查询（如"今天花了多少"）、'
          '设置预算、导出数据等。直接说出您想做的事情即可。';
      helpData = {
        'source': 'builtin',
        'categories': [
          {'name': '记账', 'examples': ['午餐30', '打车15', '工资5000']},
          {'name': '查询', 'examples': ['今天花了多少', '本月支出', '餐饮消费']},
          {'name': '配置', 'examples': ['设置预算', '添加分类', '切换账本']},
          {'name': '数据', 'examples': ['导出数据', '生成报告', '数据统计']},
        ],
      };
    }

    return ActionResult.success(
      responseText: helpText,
      data: helpData,
      actionId: id,
    );
  }

  String _getTopicHelp(String topic) {
    // 先尝试从知识库获取
    final knowledgeBase = _knowledgeBase;
    if (knowledgeBase != null) {
      final kbAnswer = knowledgeBase.getVoiceAnswer(topic);
      if (!kbAnswer.startsWith('抱歉')) {
        return kbAnswer;
      }
    }

    // 内置帮助作为备选
    switch (topic.toLowerCase()) {
      case '记账':
      case 'transaction':
        return '记账示例：直接说"午餐30"、"打车去公司15元"、"收到工资5000"等，我会自动识别金额和分类。';
      case '查询':
      case 'query':
        return '查询示例：可以问"今天花了多少"、"本月餐饮支出"、"上周消费统计"等。';
      case '预算':
      case 'budget':
        return '预算设置：说"设置餐饮预算2000"或"查看预算使用情况"来管理预算。';
      case '导出':
      case 'export':
        return '数据导出：说"导出本月数据"或"导出CSV"来导出交易记录。';
      case '小金库':
      case 'vault':
        return '小金库是一个储蓄目标管理功能，帮您为旅游、购物等目标存钱。说"打开小金库"可以查看。';
      case '钱龄':
      case 'money_age':
        return '钱龄是衡量您资金流动健康度的指标。钱龄越长说明财务越稳健。说"查看钱龄"可以查看详情。';
      default:
        return '我可以帮您记账、查询、设置预算、导出数据等。请说出具体需求。';
    }
  }
}

/// 未知意图操作
///
/// 处理无法识别的意图，提供友好的引导
class UnknownIntentAction extends Action {
  @override
  String get id => 'unknown';

  @override
  String get name => '未知意图';

  @override
  String get description => '处理无法识别的用户意图';

  @override
  List<String> get triggerPatterns => [];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'rawInput',
      type: ActionParamType.string,
      required: false,
      description: '原始用户输入',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final rawInput = params['rawInput'] as String?;

    // 根据输入内容提供不同的引导
    String response;
    if (rawInput == null || rawInput.isEmpty) {
      response = '请告诉我您想做什么，比如记账、查询或设置预算。';
    } else if (_containsNumber(rawInput)) {
      // 包含数字，可能是想记账但格式不对
      response = '看起来您想记账？请说清楚一点，比如"午餐30"或"打车15元"。';
    } else if (_containsQueryKeyword(rawInput)) {
      // 可能是想查询
      response = '您想查询什么？可以问"今天花了多少"或"本月支出"。';
    } else {
      response = '抱歉，我没有理解您的意思。我可以帮您记账、查询消费、设置预算等。';
    }

    return ActionResult.success(
      responseText: response,
      data: {
        'understood': false,
        'rawInput': rawInput,
        'suggestion': response,
      },
      actionId: id,
    );
  }

  bool _containsNumber(String input) {
    return RegExp(r'\d').hasMatch(input);
  }

  bool _containsQueryKeyword(String input) {
    final queryKeywords = ['多少', '查询', '查看', '统计', '花了', '支出', '收入'];
    return queryKeywords.any((keyword) => input.contains(keyword));
  }
}
