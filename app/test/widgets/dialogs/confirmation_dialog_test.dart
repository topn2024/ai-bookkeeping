import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/widgets/dialogs/confirmation_dialog.dart';

void main() {
  group('ConfirmationDialogConfig', () {
    group('默认构造函数', () {
      test('应使用默认值创建配置', () {
        const config = ConfirmationDialogConfig(
          title: '测试标题',
          message: '测试消息',
        );

        expect(config.title, '测试标题');
        expect(config.message, '测试消息');
        expect(config.confirmText, '确认');
        expect(config.cancelText, '取消');
        expect(config.isDangerous, isFalse);
        expect(config.icon, isNull);
        expect(config.confirmColor, isNull);
        expect(config.showCancel, isTrue);
        expect(config.barrierDismissible, isTrue);
      });

      test('应允许自定义所有参数', () {
        const config = ConfirmationDialogConfig(
          title: '标题',
          message: '消息',
          confirmText: '好的',
          cancelText: '算了',
          isDangerous: true,
          icon: Icons.check,
          confirmColor: Colors.green,
          showCancel: false,
          barrierDismissible: false,
        );

        expect(config.confirmText, '好的');
        expect(config.cancelText, '算了');
        expect(config.isDangerous, isTrue);
        expect(config.icon, Icons.check);
        expect(config.confirmColor, Colors.green);
        expect(config.showCancel, isFalse);
        expect(config.barrierDismissible, isFalse);
      });
    });

    group('dangerous 工厂方法', () {
      test('应创建危险操作配置', () {
        final config = ConfirmationDialogConfig.dangerous(
          title: '删除',
          message: '确定删除？',
        );

        expect(config.isDangerous, isTrue);
        expect(config.icon, Icons.warning_amber_rounded);
        expect(config.confirmText, '删除');
        expect(config.showCancel, isTrue);
      });

      test('应允许自定义危险操作配置', () {
        final config = ConfirmationDialogConfig.dangerous(
          title: '删除',
          message: '确定删除？',
          confirmText: '立即删除',
          cancelText: '我再想想',
          icon: Icons.delete_forever,
        );

        expect(config.confirmText, '立即删除');
        expect(config.cancelText, '我再想想');
        expect(config.icon, Icons.delete_forever);
      });
    });

    group('info 工厂方法', () {
      test('应创建信息提示配置', () {
        final config = ConfirmationDialogConfig.info(
          title: '提示',
          message: '操作成功',
        );

        expect(config.isDangerous, isFalse);
        expect(config.icon, Icons.info_outline);
        expect(config.confirmText, '知道了');
        expect(config.showCancel, isFalse);
      });

      test('应允许自定义信息提示配置', () {
        final config = ConfirmationDialogConfig.info(
          title: '成功',
          message: '保存成功',
          confirmText: '好的',
          icon: Icons.check_circle_outline,
        );

        expect(config.confirmText, '好的');
        expect(config.icon, Icons.check_circle_outline);
      });
    });
  });

  group('ConfirmationDialog Widget', () {
    Widget createTestApp({required Widget child}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => child,
          ),
        ),
      );
    }

    testWidgets('应正确渲染基础确认对话框', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmationDialog.show(
              context,
              title: '确认操作',
              message: '您确定要执行此操作吗？',
            ),
            child: const Text('打开对话框'),
          ),
        ),
      ));

      // 点击按钮打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证对话框内容
      expect(find.text('确认操作'), findsOneWidget);
      expect(find.text('您确定要执行此操作吗？'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('点击确认应返回 true', (tester) async {
      bool? result;

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context,
                title: '确认操作',
                message: '确定？',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      // 点击确认按钮（使用 FilledButton 中的文字）
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('点击取消应返回 false', (tester) async {
      bool? result;

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context,
                title: '确认',
                message: '确定？',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('应正确渲染危险操作对话框', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmationDialog.showDangerous(
              context,
              title: '删除记录',
              message: '此操作不可恢复',
            ),
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('删除记录'), findsOneWidget);
      expect(find.text('此操作不可恢复'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('应正确渲染带图标的对话框', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmationDialog.show(
              context,
              title: '提示',
              message: '这是一个提示',
              icon: Icons.info,
            ),
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('应支持自定义按钮文本', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmationDialog.show(
              context,
              title: '确认',
              message: '确定？',
              confirmText: '是的',
              cancelText: '不要',
            ),
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('是的'), findsOneWidget);
      expect(find.text('不要'), findsOneWidget);
    });

    testWidgets('showWithContent 应正确渲染自定义内容', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConfirmationDialog.showWithContent<String>(
              context,
              title: '选择选项',
              content: const Text('自定义内容区域'),
              onConfirm: () => '已选择',
            ),
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('选择选项'), findsOneWidget);
      expect(find.text('自定义内容区域'), findsOneWidget);
    });

    testWidgets('showWithContent 确认应返回 onConfirm 结果', (tester) async {
      String? result;

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.showWithContent<String>(
                context,
                title: '选择',
                content: const Text('内容'),
                onConfirm: () => '确认结果',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(result, '确认结果');
    });

    testWidgets('showWithContent 取消应返回 null', (tester) async {
      String? result = '初始值';

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmationDialog.showWithContent<String>(
                context,
                title: '选择',
                content: const Text('内容'),
                onConfirm: () => '确认结果',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('信息对话框应只显示一个按钮', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => ConfirmationDialog(
                config: ConfirmationDialogConfig.info(
                  title: '提示',
                  message: '这是一个提示信息',
                ),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('知道了'), findsOneWidget);
      // 取消按钮不应存在
      expect(find.text('取消'), findsNothing);
    });
  });

  group('ConfirmationDialog 构造', () {
    test('应正确创建带配置的对话框', () {
      const config = ConfirmationDialogConfig(
        title: '标题',
        message: '消息',
      );

      const dialog = ConfirmationDialog(config: config);

      expect(dialog.config, config);
      expect(dialog.content, isNull);
    });

    test('应正确创建带自定义内容的对话框', () {
      const config = ConfirmationDialogConfig(
        title: '标题',
        message: '消息',
      );

      const customContent = Text('自定义');
      const dialog = ConfirmationDialog(
        config: config,
        content: customContent,
      );

      expect(dialog.content, customContent);
    });
  });

  group('主题适配', () {
    testWidgets('应在亮色主题下正确渲染', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConfirmationDialog.show(
                context,
                title: '测试',
                message: '消息',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      // 对话框应该渲染
      expect(find.text('测试'), findsOneWidget);
    });

    testWidgets('应在暗色主题下正确渲染', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConfirmationDialog.show(
                context,
                title: '测试',
                message: '消息',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('测试'), findsOneWidget);
    });
  });
}
