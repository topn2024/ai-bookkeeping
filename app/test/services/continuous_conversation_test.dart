import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/global_voice_assistant_manager.dart';

void main() {
  // 确保绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  group('连续对话模式测试', () {
    late GlobalVoiceAssistantManager manager;

    setUp(() {
      // 使用测试工厂方法创建实例
      manager = GlobalVoiceAssistantManager.forTest();
    });

    test('初始状态应该是非连续模式', () {
      expect(manager.isContinuousMode, false);
      expect(manager.ballState, FloatingBallState.idle);
    });

    test('setContinuousMode(true) 应该启用连续模式', () {
      manager.setContinuousMode(true);
      expect(manager.isContinuousMode, true);
    });

    test('setContinuousMode(false) 应该禁用连续模式', () {
      manager.setContinuousMode(true);
      expect(manager.isContinuousMode, true);

      manager.setContinuousMode(false);
      expect(manager.isContinuousMode, false);
    });

    test('stopContinuousMode 应该停止连续模式并重置状态', () {
      manager.setContinuousMode(true);
      expect(manager.isContinuousMode, true);

      manager.stopContinuousMode();
      expect(manager.isContinuousMode, false);
      expect(manager.ballState, FloatingBallState.idle);
    });

    test('连续模式状态变化应该通知监听器', () {
      var notified = false;
      manager.addListener(() {
        notified = true;
      });

      manager.setContinuousMode(true);
      expect(notified, true);
    });
  });

  group('FloatingBallState 状态测试', () {
    test('应该有所有必需的状态', () {
      expect(FloatingBallState.values, contains(FloatingBallState.idle));
      expect(FloatingBallState.values, contains(FloatingBallState.recording));
      expect(FloatingBallState.values, contains(FloatingBallState.processing));
      expect(FloatingBallState.values, contains(FloatingBallState.success));
      expect(FloatingBallState.values, contains(FloatingBallState.error));
      expect(FloatingBallState.values, contains(FloatingBallState.hidden));
    });
  });

  group('状态切换逻辑测试', () {
    late GlobalVoiceAssistantManager manager;

    setUp(() {
      manager = GlobalVoiceAssistantManager.forTest();
    });

    test('setBallState 应该正确更新状态', () {
      expect(manager.ballState, FloatingBallState.idle);

      manager.setBallState(FloatingBallState.recording);
      expect(manager.ballState, FloatingBallState.recording);

      manager.setBallState(FloatingBallState.processing);
      expect(manager.ballState, FloatingBallState.processing);

      manager.setBallState(FloatingBallState.success);
      expect(manager.ballState, FloatingBallState.success);
    });

    test('相同状态不应该触发通知', () {
      var notifyCount = 0;
      manager.addListener(() {
        notifyCount++;
      });

      manager.setBallState(FloatingBallState.idle); // 相同状态
      expect(notifyCount, 0);

      manager.setBallState(FloatingBallState.recording); // 不同状态
      expect(notifyCount, 1);

      manager.setBallState(FloatingBallState.recording); // 相同状态
      expect(notifyCount, 1);
    });
  });

  group('悬浮球位置测试', () {
    late GlobalVoiceAssistantManager manager;

    setUp(() {
      manager = GlobalVoiceAssistantManager.forTest();
    });

    test('setPosition 应该正确更新位置', () {
      final newPosition = const Offset(100, 200);
      manager.setPosition(newPosition);
      expect(manager.position, newPosition);
    });

    test('相同位置不应该触发通知', () {
      var notifyCount = 0;
      manager.addListener(() {
        notifyCount++;
      });

      final position = const Offset(100, 200);
      manager.setPosition(position);
      expect(notifyCount, 1);

      manager.setPosition(position); // 相同位置
      expect(notifyCount, 1);
    });
  });

  group('可见性测试', () {
    late GlobalVoiceAssistantManager manager;

    setUp(() {
      manager = GlobalVoiceAssistantManager.forTest();
    });

    test('初始状态应该是可见的', () {
      expect(manager.isVisible, true);
    });

    test('setVisible 应该正确更新可见性', () {
      manager.setVisible(false);
      expect(manager.isVisible, false);

      manager.setVisible(true);
      expect(manager.isVisible, true);
    });
  });

  group('即时反馈生成测试', () {
    test('确认类指令应该返回处理中反馈', () {
      final response = _getImmediateResponse('确认');
      expect(response, contains('处理'));
    });

    test('取消类指令应该返回取消反馈', () {
      final response = _getImmediateResponse('取消');
      expect(response, contains('取消'));
    });

    test('记账类指令应该返回记录反馈', () {
      final response = _getImmediateResponse('午餐35块');
      expect(response.contains('记') || response.contains('一下'), true);
    });

    test('查询类指令应该返回查询反馈', () {
      final response = _getImmediateResponse('今天花了多少');
      expect(response.contains('看') || response.contains('查'), true);
    });

    test('导航类指令应该返回导航反馈', () {
      final response = _getImmediateResponse('打开预算');
      expect(response, contains('马上'));
    });
  });
}

/// 模拟即时反馈生成逻辑（从 GlobalVoiceAssistantManager 提取）
String _getImmediateResponse(String text) {
  // 确认/取消指令 - 立即响应
  if (text.contains('确认') || text.contains('是的') || text.contains('好的')) {
    return '好的，正在处理~';
  }
  if (text.contains('取消') || text.contains('算了') || text.contains('不要')) {
    return '好的，已取消';
  }

  // 导航指令
  final navKeywords = ['打开', '进入', '查看', '看看', '去'];
  if (navKeywords.any((k) => text.contains(k))) {
    return '好的，马上~';
  }

  // 记账指令（包含金额）
  final hasAmount = RegExp(r'\d+|[一二三四五六七八九十百千万两]+').hasMatch(text);
  if (hasAmount) {
    return '好的，我来记一下~';
  }

  // 查询指令
  if (text.contains('多少') || text.contains('查') || text.contains('统计')) {
    return '好的，我帮你看看~';
  }

  // 默认
  return '好的，收到~';
}

