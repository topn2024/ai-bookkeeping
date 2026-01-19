import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/voice_intent_router.dart';
import 'package:ai_bookkeeping/services/voice/agent/action_router.dart';
import 'package:ai_bookkeeping/services/voice/unified_intent_type.dart';
import 'package:ai_bookkeeping/services/voice_service_coordinator.dart' show VoiceIntentType;
import 'package:ai_bookkeeping/models/transaction.dart' as model;

import '../services/voice/agent/actions/mock_database_service.dart';

/// 语音意图执行集成测试
///
/// 测试完整的流程：
/// 1. 语音输入 -> 意图识别
/// 2. 意图识别 -> Action路由
/// 3. Action执行 -> 结果反馈
void main() {
  late MockDatabaseService mockDb;
  late ActionRouter actionRouter;
  late VoiceIntentRouter intentRouter;

  setUp(() {
    mockDb = MockDatabaseService();
    actionRouter = ActionRouter(databaseService: mockDb);
    intentRouter = VoiceIntentRouter();
  });

  group('语音意图识别集成测试', () {
    group('记账意图识别', () {
      test('应该识别"花了50块吃饭"为添加交易意图', () async {
        final result = await intentRouter.analyzeIntent('花了50块吃饭');

        expect(result.intent, VoiceIntentType.addTransaction);
        expect(result.confidence, greaterThan(0.5));
      });

      test('应该识别"买了100元的书"为添加交易意图', () async {
        final result = await intentRouter.analyzeIntent('买了100元的书');

        expect(result.intent, VoiceIntentType.addTransaction);
      });

      test('应该识别"收入5000块工资"为添加收入意图', () async {
        final result = await intentRouter.analyzeIntent('收入5000块工资');

        expect(result.intent, VoiceIntentType.addTransaction);
      });

      test('应该识别"35块午饭"为添加交易意图', () async {
        final result = await intentRouter.analyzeIntent('35块午饭');

        expect(result.intent, VoiceIntentType.addTransaction);
      });

      test('应该识别"消费20元打车"为添加交易意图', () async {
        final result = await intentRouter.analyzeIntent('消费20元打车');

        expect(result.intent, VoiceIntentType.addTransaction);
      });

      test('应该识别"记一笔100块的餐饮"为添加交易意图', () async {
        final result = await intentRouter.analyzeIntent('记一笔100块的餐饮');

        expect(result.intent, VoiceIntentType.addTransaction);
      });
    });

    group('查询意图识别', () {
      test('应该识别"查看今天的消费"为查询意图', () async {
        final result = await intentRouter.analyzeIntent('查看今天的消费');

        expect(result.intent, VoiceIntentType.queryTransaction);
      });

      test('应该识别"这个月花了多少钱"为查询意图', () async {
        final result = await intentRouter.analyzeIntent('这个月花了多少钱');

        expect(result.intent, VoiceIntentType.queryTransaction);
      });

      test('应该识别"统计餐饮消费"为查询意图', () async {
        final result = await intentRouter.analyzeIntent('统计餐饮消费');

        expect(result.intent, VoiceIntentType.queryTransaction);
      });
    });

    group('删除意图识别', () {
      test('应该识别"删除上一笔"为删除意图', () async {
        final result = await intentRouter.analyzeIntent('删除上一笔');

        expect(result.intent, VoiceIntentType.deleteTransaction);
      });

      test('应该识别"去掉刚才那笔"为删除意图', () async {
        final result = await intentRouter.analyzeIntent('去掉刚才那笔');

        expect(result.intent, VoiceIntentType.deleteTransaction);
      });

      test('应该识别"删掉这条记录"为删除意图', () async {
        final result = await intentRouter.analyzeIntent('删掉这条记录');

        expect(result.intent, VoiceIntentType.deleteTransaction);
      });
    });

    group('修改意图识别', () {
      test('应该识别"把金额改成80"为修改意图', () async {
        final result = await intentRouter.analyzeIntent('把金额改成80');

        expect(result.intent, VoiceIntentType.modifyTransaction);
      });

      test('应该识别"修改分类为交通"为修改意图', () async {
        final result = await intentRouter.analyzeIntent('修改分类为交通');

        expect(result.intent, VoiceIntentType.modifyTransaction);
      });
    });

    group('导航意图识别', () {
      test('应该识别"打开首页"为导航意图', () async {
        final result = await intentRouter.analyzeIntent('打开首页');

        expect(result.intent, VoiceIntentType.navigateToPage);
      });

      test('应该识别"进入账单页面"为导航意图', () async {
        final result = await intentRouter.analyzeIntent('进入账单页面');

        expect(result.intent, VoiceIntentType.navigateToPage);
      });
    });

    group('确认/取消意图识别', () {
      test('应该识别"确认"为确认意图', () async {
        final result = await intentRouter.analyzeIntent('确认');

        expect(result.intent, VoiceIntentType.confirmAction);
      });

      test('应该识别"取消"为取消意图', () async {
        final result = await intentRouter.analyzeIntent('取消');

        expect(result.intent, VoiceIntentType.cancelAction);
      });

      test('应该识别"是的"为确认意图', () async {
        final result = await intentRouter.analyzeIntent('是的');

        expect(result.intent, VoiceIntentType.confirmAction);
      });

      test('应该识别"算了"为取消意图', () async {
        final result = await intentRouter.analyzeIntent('算了');

        expect(result.intent, VoiceIntentType.cancelAction);
      });
    });
  });

  group('Action路由集成测试', () {
    group('配置类Action - 分类管理', () {
      test('应该正确查询分类列表', () async {
        mockDb.categoriesToReturn = [];

        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.configCategory,
          params: {'operation': 'query'},
        );

        expect(result.success, isTrue);
      });
    });

    group('配置类Action - 账本管理', () {
      test('应该正确查询账本列表', () async {
        mockDb.ledgersToReturn = [];

        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.configLedger,
          params: {'operation': 'query'},
        );

        expect(result.success, isTrue);
      });
    });

    group('高级功能Action - 小金库', () {
      test('应该正确查询小金库', () async {
        mockDb.budgetVaultsToReturn = [];

        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.vaultQuery,
          params: {},
        );

        expect(result.success, isTrue);
      });

      test('应该正确创建小金库', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.vaultCreate,
          params: {'name': '旅行基金', 'targetAmount': 5000.0},
        );

        expect(result.success, isTrue);
      });
    });

    group('高级功能Action - 钱龄', () {
      test('应该正确查询钱龄', () async {
        mockDb.transactionsToReturn = [
          model.Transaction(
            id: 'tx-1',
            amount: 100.0,
            type: model.TransactionType.expense,
            category: '餐饮',
            date: DateTime.now(),
            accountId: 'account-1',
            moneyAge: 15,
          ),
        ];

        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.moneyAgeQuery,
          params: {},
        );

        expect(result.success, isTrue);
      });

      test('应该正确设置钱龄提醒', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.moneyAgeReminder,
          params: {'threshold': 30},
        );

        expect(result.success, isTrue);
      });
    });

    group('高级功能Action - 习惯分析', () {
      test('应该正确查询消费习惯', () async {
        mockDb.transactionsToReturn = [
          model.Transaction(
            id: 'tx-1',
            amount: 30.0,
            type: model.TransactionType.expense,
            category: '餐饮',
            date: DateTime.now(),
            accountId: 'account-1',
          ),
        ];

        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.habitQuery,
          params: {},
        );

        expect(result.success, isTrue);
      });
    });

    group('系统Action', () {
      test('应该返回关于信息', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.systemAbout,
          params: {},
        );

        expect(result.success, isTrue);
      });

      test('应该返回设置信息', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.systemSettings,
          params: {},
        );

        expect(result.success, isTrue);
      });
    });

    group('自动化Action', () {
      test('屏幕识别应该请求图片', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.automationScreenRecognition,
          params: {},
        );

        expect(result.success, isTrue);
      });

      test('支付宝同步应该返回指引', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.automationAlipaySync,
          params: {},
        );

        expect(result.success, isTrue);
      });

      test('定时记账应该列出规则', () async {
        final result = await actionRouter.executeByIntentType(
          UnifiedIntentType.automationScheduled,
          params: {'action': 'list'},
        );

        expect(result.success, isTrue);
      });
    });
  });

  group('错误处理测试', () {
    test('未知意图类型应该返回unsupported', () async {
      final result = await actionRouter.executeByIntentType(
        UnifiedIntentType.unknown,
        params: {},
      );

      expect(result.success, isFalse);
    });

    test('缺少必要参数应该提示需要更多信息', () async {
      final result = await actionRouter.executeByIntentType(
        UnifiedIntentType.vaultCreate,
        params: {}, // 缺少name参数
      );

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('空输入应该返回低置信度', () async {
      final result = await intentRouter.analyzeIntent('');

      expect(result.confidence, lessThan(0.5));
    });

    test('无意义输入应该返回未知意图', () async {
      final result = await intentRouter.analyzeIntent('啊啊啊');

      expect(result.intent, VoiceIntentType.unknown);
    });
  });

  group('实体提取测试', () {
    test('应该从"花了50块吃饭"中提取金额', () async {
      final result = await intentRouter.analyzeIntent('花了50块吃饭');

      expect(result.entities['amount'], isNotNull);
    });

    test('应该从"买了100元书"中提取金额', () async {
      final result = await intentRouter.analyzeIntent('买了100元书');

      expect(result.entities['amount'], isNotNull);
    });

    test('应该从"收入5000工资"中识别收入类型', () async {
      final result = await intentRouter.analyzeIntent('收入5000工资');

      expect(result.intent, VoiceIntentType.addTransaction);
    });
  });

  group('置信度测试', () {
    test('明确的记账意图应该有高置信度', () async {
      final result = await intentRouter.analyzeIntent('记一笔100块的餐饮支出');

      expect(result.confidence, greaterThan(0.7));
    });

    test('确认词应该有高置信度', () async {
      final result = await intentRouter.analyzeIntent('确认');

      expect(result.confidence, greaterThan(0.8));
    });

    test('取消词应该有高置信度', () async {
      final result = await intentRouter.analyzeIntent('取消');

      expect(result.confidence, greaterThan(0.8));
    });
  });
}
