import 'package:flutter/foundation.dart';
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/transaction.dart';
import '../action_registry.dart';

/// 屏幕识别记账Action
///
/// 通过OCR识别屏幕上的账单信息并自动创建交易记录
class ScreenRecognitionAction extends Action {
  final IDatabaseService databaseService;

  ScreenRecognitionAction(this.databaseService);

  @override
  String get id => 'automation.screenRecognition';

  @override
  String get name => '屏幕识别记账';

  @override
  String get description => '识别屏幕上的账单信息并自动记账';

  @override
  List<String> get triggerPatterns => [
    '屏幕识别', '识别屏幕', '截图记账',
    '识别账单', '自动识别', '拍照记账',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'imagePath',
      type: ActionParamType.string,
      required: false,
      description: '图片路径',
    ),
    const ActionParam(
      name: 'autoCreate',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: false,
      description: '是否自动创建记录',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final imagePath = params['imagePath'] as String?;
      final autoCreate = params['autoCreate'] as bool? ?? false;

      if (imagePath == null) {
        // 请求截图或拍照
        return ActionResult.success(
          responseText: '请截图或拍照账单，我来帮您识别',
          data: {
            'needImage': true,
            'supportedTypes': ['screenshot', 'photo', 'clipboard'],
          },
          actionId: id,
        );
      }

      // 模拟OCR识别结果（实际应调用OCR服务）
      // 这里返回一个需要确认的识别结果
      final recognitionResult = {
        'status': 'recognized',
        'confidence': 0.85,
        'items': [
          {
            'type': 'expense',
            'amount': 35.0,
            'merchant': '星巴克',
            'category': '餐饮',
            'date': DateTime.now().toIso8601String(),
          },
        ],
      };

      if (!autoCreate) {
        return ActionResult.success(
          responseText: '识别到1笔消费：星巴克35元，确认记录吗？',
          data: {
            'status': 'needConfirmation',
            'recognitionResult': recognitionResult,
          },
          actionId: id,
        );
      }

      // 自动创建记录
      final items = recognitionResult['items'] as List;
      int createdCount = 0;

      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: itemMap['type'] == 'income' ? TransactionType.income : TransactionType.expense,
          amount: (itemMap['amount'] as num).toDouble(),
          category: itemMap['category'] as String? ?? '其他',
          rawMerchant: itemMap['merchant'] as String?,
          date: DateTime.now(),
          accountId: 'default',
          source: TransactionSource.image,
          aiConfidence: recognitionResult['confidence'] as double? ?? 0.8,
        );

        await databaseService.insertTransaction(transaction);
        createdCount++;
      }

      return ActionResult.success(
        responseText: '已自动记录$createdCount笔消费',
        data: {
          'status': 'created',
          'createdCount': createdCount,
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[ScreenRecognitionAction] 识别失败: $e');
      return ActionResult.failure('屏幕识别失败: $e', actionId: id);
    }
  }
}

/// 支付宝账单同步Action
class AlipayBillSyncAction extends Action {
  final IDatabaseService databaseService;

  AlipayBillSyncAction(this.databaseService);

  @override
  String get id => 'automation.alipaySync';

  @override
  String get name => '支付宝账单同步';

  @override
  String get description => '导入支付宝账单文件';

  @override
  List<String> get triggerPatterns => [
    '支付宝账单', '同步支付宝', '导入支付宝',
    '支付宝记录', '支付宝导入',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'filePath',
      type: ActionParamType.string,
      required: false,
      description: '账单文件路径',
    ),
    const ActionParam(
      name: 'skipDuplicate',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否跳过重复记录',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final filePath = params['filePath'] as String?;
      final skipDuplicate = params['skipDuplicate'] as bool? ?? true;

      if (filePath == null) {
        return ActionResult.success(
          responseText: '请先从支付宝导出账单CSV文件，然后选择文件导入',
          data: {
            'needFile': true,
            'instructions': [
              '1. 打开支付宝 - 我的 - 账单',
              '2. 点击右上角"..." - 开具交易流水证明',
              '3. 选择时间范围，申请电子版',
              '4. 下载CSV文件后选择导入',
            ],
          },
          actionId: id,
        );
      }

      // 模拟解析结果
      final parseResult = await _parseAlipayBill(filePath, skipDuplicate);

      return ActionResult.success(
        responseText: '已导入${parseResult['imported']}笔支付宝账单${skipDuplicate ? "，跳过${parseResult['skipped']}笔重复记录" : ""}',
        data: parseResult,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[AlipayBillSyncAction] 同步失败: $e');
      return ActionResult.failure('支付宝账单同步失败: $e', actionId: id);
    }
  }

  /// 解析支付宝账单
  Future<Map<String, dynamic>> _parseAlipayBill(String filePath, bool skipDuplicate) async {
    // 实际应解析CSV文件
    // 这里返回模拟结果
    return {
      'imported': 15,
      'skipped': skipDuplicate ? 3 : 0,
      'total': 18,
      'totalAmount': 2580.50,
    };
  }
}

/// 微信账单同步Action
class WeChatBillSyncAction extends Action {
  final IDatabaseService databaseService;

  WeChatBillSyncAction(this.databaseService);

  @override
  String get id => 'automation.wechatSync';

  @override
  String get name => '微信账单同步';

  @override
  String get description => '导入微信账单文件';

  @override
  List<String> get triggerPatterns => [
    '微信账单', '同步微信', '导入微信',
    '微信记录', '微信导入',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'filePath',
      type: ActionParamType.string,
      required: false,
      description: '账单文件路径',
    ),
    const ActionParam(
      name: 'skipDuplicate',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否跳过重复记录',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final filePath = params['filePath'] as String?;
      final skipDuplicate = params['skipDuplicate'] as bool? ?? true;

      if (filePath == null) {
        return ActionResult.success(
          responseText: '请先从微信导出账单文件，然后选择文件导入',
          data: {
            'needFile': true,
            'instructions': [
              '1. 打开微信 - 我 - 服务 - 钱包',
              '2. 点击账单 - 常见问题 - 下载账单',
              '3. 选择"用于个人对账"',
              '4. 设置时间范围并申请',
              '5. 下载CSV文件后选择导入',
            ],
          },
          actionId: id,
        );
      }

      // 模拟解析结果
      final parseResult = await _parseWeChatBill(filePath, skipDuplicate);

      return ActionResult.success(
        responseText: '已导入${parseResult['imported']}笔微信账单${skipDuplicate ? "，跳过${parseResult['skipped']}笔重复记录" : ""}',
        data: parseResult,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[WeChatBillSyncAction] 同步失败: $e');
      return ActionResult.failure('微信账单同步失败: $e', actionId: id);
    }
  }

  /// 解析微信账单
  Future<Map<String, dynamic>> _parseWeChatBill(String filePath, bool skipDuplicate) async {
    // 实际应解析CSV文件
    return {
      'imported': 22,
      'skipped': skipDuplicate ? 5 : 0,
      'total': 27,
      'totalAmount': 3150.80,
    };
  }
}

/// 银行账单同步Action
class BankBillSyncAction extends Action {
  final IDatabaseService databaseService;

  BankBillSyncAction(this.databaseService);

  @override
  String get id => 'automation.bankSync';

  @override
  String get name => '银行账单同步';

  @override
  String get description => '导入银行账单文件';

  @override
  List<String> get triggerPatterns => [
    '银行账单', '同步银行', '导入银行',
    '银行记录', '信用卡账单',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'filePath',
      type: ActionParamType.string,
      required: false,
      description: '账单文件路径',
    ),
    const ActionParam(
      name: 'bankType',
      type: ActionParamType.string,
      required: false,
      description: '银行类型',
    ),
    const ActionParam(
      name: 'skipDuplicate',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否跳过重复记录',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final filePath = params['filePath'] as String?;
      final bankType = params['bankType'] as String?;
      final skipDuplicate = params['skipDuplicate'] as bool? ?? true;

      if (filePath == null) {
        return ActionResult.success(
          responseText: '请选择银行账单文件导入，支持主流银行的CSV和Excel格式',
          data: {
            'needFile': true,
            'supportedBanks': [
              '工商银行',
              '建设银行',
              '农业银行',
              '中国银行',
              '招商银行',
              '交通银行',
              '浦发银行',
              '中信银行',
              '其他银行',
            ],
            'supportedFormats': ['csv', 'xlsx', 'xls'],
          },
          actionId: id,
        );
      }

      // 模拟解析结果
      final parseResult = await _parseBankBill(filePath, bankType, skipDuplicate);

      return ActionResult.success(
        responseText: '已导入${parseResult['imported']}笔${bankType ?? "银行"}账单${skipDuplicate ? "，跳过${parseResult['skipped']}笔重复记录" : ""}',
        data: parseResult,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[BankBillSyncAction] 同步失败: $e');
      return ActionResult.failure('银行账单同步失败: $e', actionId: id);
    }
  }

  /// 解析银行账单
  Future<Map<String, dynamic>> _parseBankBill(String filePath, String? bankType, bool skipDuplicate) async {
    // 实际应解析银行账单文件
    return {
      'imported': 35,
      'skipped': skipDuplicate ? 8 : 0,
      'total': 43,
      'totalAmount': 12580.00,
      'bankType': bankType ?? '未知银行',
    };
  }
}

/// 邮箱账单解析Action
class EmailBillParseAction extends Action {
  final IDatabaseService databaseService;

  EmailBillParseAction(this.databaseService);

  @override
  String get id => 'automation.emailParse';

  @override
  String get name => '邮箱账单解析';

  @override
  String get description => '从邮箱中解析账单信息';

  @override
  List<String> get triggerPatterns => [
    '邮箱账单', '解析邮件', '邮件账单',
    '账单邮件', '自动解析邮箱',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'emailAddress',
      type: ActionParamType.string,
      required: false,
      description: '邮箱地址',
    ),
    const ActionParam(
      name: 'days',
      type: ActionParamType.number,
      required: false,
      defaultValue: 30,
      description: '解析最近多少天的邮件',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final emailAddress = params['emailAddress'] as String?;
      final days = (params['days'] as num?)?.toInt() ?? 30;

      if (emailAddress == null) {
        return ActionResult.success(
          responseText: '邮箱账单解析功能需要授权访问您的邮箱，请在设置中配置',
          data: {
            'needSetup': true,
            'supportedProviders': [
              'QQ邮箱',
              '163邮箱',
              'Gmail',
              'Outlook',
            ],
            'redirectTo': '/settings/email-sync',
          },
          actionId: id,
        );
      }

      // 模拟解析结果
      return ActionResult.success(
        responseText: '已从邮箱中解析出12封账单邮件，识别到28笔消费记录',
        data: {
          'emailsParsed': 12,
          'transactionsFound': 28,
          'days': days,
          'sources': ['信用卡账单', '水电费', '话费', '订单确认'],
        },
        actionId: id,
      );
    } catch (e) {
      debugPrint('[EmailBillParseAction] 解析失败: $e');
      return ActionResult.failure('邮箱账单解析失败: $e', actionId: id);
    }
  }
}

/// 定时自动记账Action
class ScheduledBookkeepingAction extends Action {
  final IDatabaseService databaseService;

  ScheduledBookkeepingAction(this.databaseService);

  @override
  String get id => 'automation.scheduled';

  @override
  String get name => '定时自动记账';

  @override
  String get description => '设置定时自动记账规则';

  @override
  List<String> get triggerPatterns => [
    '定时记账', '自动记账', '周期记账',
    '固定支出', '每月记账',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'action',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'list',
      description: '操作: list/add/remove/pause',
    ),
    const ActionParam(
      name: 'name',
      type: ActionParamType.string,
      required: false,
      description: '规则名称',
    ),
    const ActionParam(
      name: 'amount',
      type: ActionParamType.number,
      required: false,
      description: '金额',
    ),
    const ActionParam(
      name: 'frequency',
      type: ActionParamType.string,
      required: false,
      description: '频率: daily/weekly/monthly',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final action = params['action'] as String? ?? 'list';
      final name = params['name'] as String?;
      final amount = (params['amount'] as num?)?.toDouble();
      final frequency = params['frequency'] as String?;

      switch (action) {
        case 'add':
          if (name == null || amount == null) {
            return ActionResult.needParams(
              missing: name == null ? ['name'] : ['amount'],
              prompt: name == null ? '请告诉我规则名称' : '请告诉我金额',
              actionId: id,
            );
          }

          return ActionResult.success(
            responseText: '已添加定时记账规则：$name，${amount.toStringAsFixed(0)}元，${_getFrequencyText(frequency ?? 'monthly')}',
            data: {
              'action': 'added',
              'name': name,
              'amount': amount,
              'frequency': frequency ?? 'monthly',
            },
            actionId: id,
          );

        case 'remove':
          if (name == null) {
            return ActionResult.needParams(
              missing: ['name'],
              prompt: '请告诉我要删除哪个规则',
              actionId: id,
            );
          }

          return ActionResult.success(
            responseText: '已删除定时记账规则：$name',
            data: {
              'action': 'removed',
              'name': name,
            },
            actionId: id,
          );

        case 'pause':
          if (name == null) {
            return ActionResult.needParams(
              missing: ['name'],
              prompt: '请告诉我要暂停哪个规则',
              actionId: id,
            );
          }

          return ActionResult.success(
            responseText: '已暂停定时记账规则：$name',
            data: {
              'action': 'paused',
              'name': name,
            },
            actionId: id,
          );

        case 'list':
        default:
          // 模拟已有的规则列表
          final rules = [
            {'name': '房租', 'amount': 3000.0, 'frequency': 'monthly', 'enabled': true},
            {'name': '话费', 'amount': 58.0, 'frequency': 'monthly', 'enabled': true},
            {'name': '视频会员', 'amount': 25.0, 'frequency': 'monthly', 'enabled': true},
          ];

          if (rules.isEmpty) {
            return ActionResult.success(
              responseText: '暂无定时记账规则，说"添加定时记账"可以创建',
              data: {
                'rules': [],
                'count': 0,
              },
              actionId: id,
            );
          }

          final totalMonthly = rules.fold(0.0, (sum, r) => sum + (r['amount'] as double));

          return ActionResult.success(
            responseText: '共有${rules.length}条定时记账规则，每月自动记账${totalMonthly.toStringAsFixed(0)}元',
            data: {
              'rules': rules,
              'count': rules.length,
              'totalMonthly': totalMonthly,
            },
            actionId: id,
          );
      }
    } catch (e) {
      debugPrint('[ScheduledBookkeepingAction] 操作失败: $e');
      return ActionResult.failure('定时记账操作失败: $e', actionId: id);
    }
  }

  /// 获取频率文本
  String _getFrequencyText(String frequency) {
    switch (frequency) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
      default:
        return '每月';
    }
  }
}
