import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice_context_service.dart';

void main() {
  group('VoiceContextService Tests', () {
    late VoiceContextService service;

    setUp(() {
      service = VoiceContextService();
    });

    group('路由到上下文类型映射', () {
      test('应该正确识别首页路由', () {
        service.updateContextFromRoute('/');
        expect(service.currentContext?.type, equals(PageContextType.home));

        service.updateContextFromRoute('/home');
        expect(service.currentContext?.type, equals(PageContextType.home));
      });

      test('应该正确识别预算页路由', () {
        service.updateContextFromRoute('/budget');
        expect(service.currentContext?.type, equals(PageContextType.budget));

        service.updateContextFromRoute('/budgets');
        expect(service.currentContext?.type, equals(PageContextType.budget));
      });

      test('应该正确识别报表页路由', () {
        service.updateContextFromRoute('/reports');
        expect(service.currentContext?.type, equals(PageContextType.report));

        service.updateContextFromRoute('/monthly-report');
        expect(service.currentContext?.type, equals(PageContextType.report));
      });

      test('应该正确识别交易详情页路由', () {
        service.updateContextFromRoute('/transaction-detail');
        expect(service.currentContext?.type, equals(PageContextType.transactionDetail));
      });

      test('未知路由会匹配首页前缀', () {
        // 由于 '/' 在路由映射中，所有以 / 开头的路由都会通过前缀匹配到首页
        service.updateContextFromRoute('/unknown-page');
        expect(service.currentContext?.type, equals(PageContextType.home));

        // 路由名称仍然保持原值
        expect(service.currentContext?.routeName, equals('/unknown-page'));
      });
    });

    group('上下文更新', () {
      test('应该正确更新上下文', () {
        final context = PageContext(
          type: PageContextType.budget,
          routeName: '/budget',
          data: {'category': '餐饮', 'remaining': 500.0},
        );

        service.updateContext(context);

        expect(service.currentContext?.type, equals(PageContextType.budget));
        expect(service.currentContext?.data?['category'], equals('餐饮'));
        expect(service.currentContext?.data?['remaining'], equals(500.0));
      });

      test('应该正确更新上下文数据', () {
        service.updateContextFromRoute('/budget');
        service.updateContextData({'category': '交通', 'remaining': 300.0});

        expect(service.currentContext?.data?['category'], equals('交通'));
        expect(service.currentContext?.data?['remaining'], equals(300.0));
      });

      test('应该保留上下文历史', () {
        service.updateContextFromRoute('/');
        service.updateContextFromRoute('/budget');
        service.updateContextFromRoute('/reports');

        expect(service.contextHistory.length, equals(2));
        expect(service.contextHistory[0].type, equals(PageContextType.home));
        expect(service.contextHistory[1].type, equals(PageContextType.budget));
      });

      test('上下文历史应该有最大限制', () {
        // 添加超过最大限制的上下文（使用不同的有效路由）
        final routes = [
          '/', '/budget', '/reports', '/savings', '/settings',
          '/money-age', '/transactions', '/', '/budget', '/reports',
          '/savings', '/settings', '/money-age', '/transactions', '/',
        ];

        for (final route in routes) {
          service.updateContextFromRoute(route);
        }

        // 历史不应超过最大限制 (10)
        expect(service.contextHistory.length, lessThanOrEqualTo(10));
      });
    });

    group('悬浮球隐藏逻辑', () {
      test('在语音聊天页应该隐藏悬浮球', () {
        service.updateContextFromRoute('/voice-chat');
        expect(service.shouldHideFloatingBall, isTrue);
      });

      test('在语音助手页应该隐藏悬浮球', () {
        service.updateContextFromRoute('/voice-assistant');
        expect(service.shouldHideFloatingBall, isTrue);
      });

      test('在普通页面不应该隐藏悬浮球', () {
        service.updateContextFromRoute('/');
        expect(service.shouldHideFloatingBall, isFalse);

        service.updateContextFromRoute('/budget');
        expect(service.shouldHideFloatingBall, isFalse);
      });
    });

    group('上下文提示', () {
      test('首页应该返回记账相关提示', () {
        service.updateContextFromRoute('/');
        final hint = service.getContextHint();

        expect(hint, contains('首页'));
        expect(hint, contains('记账'));
      });

      test('预算页应该返回预算相关提示', () {
        service.updateContextFromRoute('/budget');
        final hint = service.getContextHint();

        expect(hint, contains('预算'));
      });

      test('交易详情页应该返回修改/删除提示', () {
        service.updateContextFromRoute('/transaction-detail');
        final hint = service.getContextHint();

        expect(hint, contains('交易详情'));
        expect(hint, anyOf(contains('修改'), contains('删除')));
      });

      test('无上下文应该返回空字符串', () {
        final hint = service.getContextHint();
        expect(hint, isEmpty);
      });
    });

    group('意图增强', () {
      test('在交易详情页应该自动关联交易ID', () {
        service.updateContext(PageContext(
          type: PageContextType.transactionDetail,
          routeName: '/transaction-detail',
          data: {'transactionId': 'tx-123'},
        ));

        final rawIntent = {'action': 'modify', 'newAmount': 50.0};
        final enhanced = service.enhanceIntent(rawIntent);

        expect(enhanced['transactionId'], equals('tx-123'));
        expect(enhanced['newAmount'], equals(50.0));
      });

      test('在预算页应该自动关联分类和余额', () {
        service.updateContext(PageContext(
          type: PageContextType.budget,
          routeName: '/budget',
          data: {'category': '餐饮', 'remaining': 500.0},
        ));

        final rawIntent = {'action': 'query_budget'};
        final enhanced = service.enhanceIntent(rawIntent);

        expect(enhanced['category'], equals('餐饮'));
        expect(enhanced['remaining'], equals(500.0));
      });

      test('在报表页应该自动使用时间范围', () {
        service.updateContext(PageContext(
          type: PageContextType.report,
          routeName: '/reports',
          data: {'dateRange': '本月'},
        ));

        final rawIntent = {'action': 'query'};
        final enhanced = service.enhanceIntent(rawIntent);

        expect(enhanced['dateRange'], equals('本月'));
      });

      test('无上下文时不应该修改意图', () {
        final rawIntent = {'action': 'add', 'amount': 35.0};
        final enhanced = service.enhanceIntent(rawIntent);

        expect(enhanced, equals(rawIntent));
      });
    });

    group('清除上下文', () {
      test('应该清除当前上下文和历史', () {
        service.updateContextFromRoute('/');
        service.updateContextFromRoute('/budget');
        service.clearContext();

        expect(service.currentContext, isNull);
        expect(service.contextHistory, isEmpty);
      });
    });
  });

  group('PageContext Tests', () {
    test('copyWith 应该正确复制并更新', () {
      final original = PageContext(
        type: PageContextType.budget,
        routeName: '/budget',
        data: {'category': '餐饮'},
      );

      final copied = original.copyWith(
        data: {'category': '交通', 'remaining': 300.0},
      );

      expect(copied.type, equals(PageContextType.budget));
      expect(copied.routeName, equals('/budget'));
      expect(copied.data?['category'], equals('交通'));
      expect(copied.data?['remaining'], equals(300.0));
    });

    test('toString 应该返回可读的字符串', () {
      final context = PageContext(
        type: PageContextType.budget,
        routeName: '/budget',
      );

      final str = context.toString();
      expect(str, contains('PageContext'));
      expect(str, contains('budget'));
    });
  });
}
