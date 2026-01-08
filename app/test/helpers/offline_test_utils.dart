import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/offline_capability_service.dart';

/// 网络状态模拟测试工具
///
/// 用于测试离线场景下的应用行为
class NetworkSimulator {
  static final NetworkSimulator _instance = NetworkSimulator._internal();
  factory NetworkSimulator() => _instance;
  NetworkSimulator._internal();

  bool _isSimulating = false;
  NetworkStatus _simulatedStatus = NetworkStatus.online;
  final _statusController = StreamController<NetworkStatusInfo>.broadcast();

  /// 是否正在模拟
  bool get isSimulating => _isSimulating;

  /// 模拟状态流
  Stream<NetworkStatusInfo> get statusStream => _statusController.stream;

  /// 当前模拟状态
  NetworkStatus get simulatedStatus => _simulatedStatus;

  /// 开始模拟
  void startSimulation() {
    _isSimulating = true;
    debugPrint('Network simulation started');
  }

  /// 停止模拟
  void stopSimulation() {
    _isSimulating = false;
    debugPrint('Network simulation stopped');
  }

  /// 模拟离线状态
  void simulateOffline() {
    if (!_isSimulating) {
      debugPrint('Warning: Simulation not started');
      return;
    }

    _simulatedStatus = NetworkStatus.offline;
    _statusController.add(NetworkStatusInfo(
      status: NetworkStatus.offline,
      timestamp: DateTime.now(),
    ));
    debugPrint('Simulated: OFFLINE');
  }

  /// 模拟在线状态
  void simulateOnline() {
    if (!_isSimulating) {
      debugPrint('Warning: Simulation not started');
      return;
    }

    _simulatedStatus = NetworkStatus.online;
    _statusController.add(NetworkStatusInfo(
      status: NetworkStatus.online,
      timestamp: DateTime.now(),
    ));
    debugPrint('Simulated: ONLINE');
  }

  /// 模拟弱网状态
  void simulateWeakNetwork({Duration latency = const Duration(seconds: 2)}) {
    if (!_isSimulating) {
      debugPrint('Warning: Simulation not started');
      return;
    }

    _simulatedStatus = NetworkStatus.weak;
    _statusController.add(NetworkStatusInfo(
      status: NetworkStatus.weak,
      timestamp: DateTime.now(),
      latency: latency,
    ));
    debugPrint('Simulated: WEAK NETWORK (latency: ${latency.inMilliseconds}ms)');
  }

  /// 模拟网络断开再恢复
  Future<void> simulateNetworkFlap({
    Duration offlineDuration = const Duration(seconds: 5),
  }) async {
    simulateOffline();
    await Future.delayed(offlineDuration);
    simulateOnline();
    debugPrint('Simulated: Network flap (offline for ${offlineDuration.inSeconds}s)');
  }

  /// 模拟间歇性网络
  Future<void> simulateIntermittentNetwork({
    int cycles = 3,
    Duration onlineDuration = const Duration(seconds: 2),
    Duration offlineDuration = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < cycles; i++) {
      simulateOnline();
      await Future.delayed(onlineDuration);
      simulateOffline();
      await Future.delayed(offlineDuration);
    }
    simulateOnline();
    debugPrint('Simulated: Intermittent network ($cycles cycles)');
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
  }
}

/// 离线能力测试套件
class OfflineCapabilityTestSuite {
  final OfflineCapabilityService _offlineService;
  final NetworkSimulator _networkSimulator;

  OfflineCapabilityTestSuite({
    OfflineCapabilityService? offlineService,
    NetworkSimulator? networkSimulator,
  })  : _offlineService = offlineService ?? OfflineCapabilityService(),
        _networkSimulator = networkSimulator ?? NetworkSimulator();

  /// 运行所有测试
  Future<TestSuiteResult> runAllTests() async {
    final results = <TestResult>[];

    // L0 测试
    results.addAll(await _runL0Tests());

    // L1 测试
    results.addAll(await _runL1Tests());

    // L2 测试
    results.addAll(await _runL2Tests());

    // L3 测试
    results.addAll(await _runL3Tests());

    // 网络恢复测试
    results.addAll(await _runRecoveryTests());

    return TestSuiteResult(
      totalTests: results.length,
      passed: results.where((r) => r.passed).length,
      failed: results.where((r) => !r.passed).length,
      results: results,
    );
  }

  /// L0 完全离线测试
  Future<List<TestResult>> _runL0Tests() async {
    final results = <TestResult>[];

    // 测试1: 手动记账离线可用
    results.add(await _testL0ManualTransaction());

    // 测试2: 历史记录离线查看
    results.add(await _testL0TransactionList());

    // 测试3: 预算本地计算
    results.add(await _testL0BudgetCalculation());

    // 测试4: 钱龄本地计算
    results.add(await _testL0MoneyAgeCalculation());

    // 测试5: 基础报表离线生成
    results.add(await _testL0BasicReport());

    // 测试6: 本地数据导出
    results.add(await _testL0DataExport());

    return results;
  }

  /// 测试: 手动记账离线可用
  Future<TestResult> _testL0ManualTransaction() async {
    final testName = 'L0: 手动记账离线可用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      // 验证功能可用
      final isAvailable = _offlineService.isFeatureAvailable('manual_transaction');
      final isDegraded = _offlineService.isFeatureDegraded('manual_transaction');

      _networkSimulator.stopSimulation();

      if (isAvailable && !isDegraded) {
        return TestResult(
          name: testName,
          passed: true,
          message: '手动记账功能在离线状态下完全可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '手动记账功能在离线状态下不可用或被降级',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 历史记录离线查看
  Future<TestResult> _testL0TransactionList() async {
    final testName = 'L0: 历史记录离线秒开';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('transaction_list');
      final capability = _offlineService.getFeatureCapability('transaction_list');

      _networkSimulator.stopSimulation();

      if (isAvailable && capability?.offlineLevel == OfflineLevel.fullOffline) {
        return TestResult(
          name: testName,
          passed: true,
          message: '历史记录在离线状态下可秒开查看',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '历史记录功能配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 预算本地计算
  Future<TestResult> _testL0BudgetCalculation() async {
    final testName = 'L0: 预算本地计算正确';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final settingAvailable = _offlineService.isFeatureAvailable('budget_setting');
      final executionAvailable = _offlineService.isFeatureAvailable('budget_execution');

      _networkSimulator.stopSimulation();

      if (settingAvailable && executionAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: '预算设置和执行在离线状态下均可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '预算功能在离线状态下不完全可用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 钱龄本地计算
  Future<TestResult> _testL0MoneyAgeCalculation() async {
    final testName = 'L0: 钱龄本地计算正确';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final calculateAvailable = _offlineService.isFeatureAvailable('money_age_calculate');
      final displayAvailable = _offlineService.isFeatureAvailable('money_age_display');
      final trendAvailable = _offlineService.isFeatureAvailable('money_age_trend');

      _networkSimulator.stopSimulation();

      if (calculateAvailable && displayAvailable && trendAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: '钱龄计算、展示、趋势功能在离线状态下均可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '钱龄功能在离线状态下不完全可用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 基础报表离线生成
  Future<TestResult> _testL0BasicReport() async {
    final testName = 'L0: 基础报表离线数据完整';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final basicAvailable = _offlineService.isFeatureAvailable('basic_report');
      final trendAvailable = _offlineService.isFeatureAvailable('trend_analysis');
      final categoryAvailable = _offlineService.isFeatureAvailable('category_stats');

      _networkSimulator.stopSimulation();

      if (basicAvailable && trendAvailable && categoryAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: '基础报表功能在离线状态下完全可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '报表功能在离线状态下不完全可用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 本地数据导出
  Future<TestResult> _testL0DataExport() async {
    final testName = 'L0: 本地数据导出无需网络';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('data_export');
      final capability = _offlineService.getFeatureCapability('data_export');

      _networkSimulator.stopSimulation();

      if (isAvailable && capability?.offlineLevel == OfflineLevel.fullOffline) {
        return TestResult(
          name: testName,
          passed: true,
          message: '本地数据导出在离线状态下完全可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '数据导出功能在离线状态下不可用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// L1 增强离线测试
  Future<List<TestResult>> _runL1Tests() async {
    final results = <TestResult>[];

    // 测试: 语音识别降级
    results.add(await _testL1VoiceRecognition());

    // 测试: OCR识别降级
    results.add(await _testL1OcrRecognition());

    // 测试: 智能分类降级
    results.add(await _testL1SmartCategory());

    return results;
  }

  /// 测试: 语音识别降级
  Future<TestResult> _testL1VoiceRecognition() async {
    final testName = 'L1: 本地语音识别降级可用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('voice_input');
      final isDegraded = _offlineService.isFeatureDegraded('voice_input');
      final capability = _offlineService.getFeatureCapability('voice_input');

      _networkSimulator.stopSimulation();

      if (isAvailable && isDegraded &&
          capability?.offlineLevel == OfflineLevel.enhancedOffline) {
        return TestResult(
          name: testName,
          passed: true,
          message: '语音识别在离线状态下降级可用（本地ASR）',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '语音识别降级配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: OCR识别降级
  Future<TestResult> _testL1OcrRecognition() async {
    final testName = 'L1: 本地OCR识别降级可用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('image_ocr');
      final isDegraded = _offlineService.isFeatureDegraded('image_ocr');

      _networkSimulator.stopSimulation();

      if (isAvailable && isDegraded) {
        return TestResult(
          name: testName,
          passed: true,
          message: 'OCR识别在离线状态下降级可用（本地ML模型）',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: 'OCR识别降级配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 智能分类降级
  Future<TestResult> _testL1SmartCategory() async {
    final testName = 'L1: 规则引擎智能分类降级可用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('smart_category');
      final isDegraded = _offlineService.isFeatureDegraded('smart_category');
      final hint = _offlineService.getFeatureDegradationHint('smart_category');

      _networkSimulator.stopSimulation();

      if (isAvailable && isDegraded && hint != null) {
        return TestResult(
          name: testName,
          passed: true,
          message: '智能分类在离线状态下降级可用：$hint',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '智能分类降级配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// L2 在线优先测试
  Future<List<TestResult>> _runL2Tests() async {
    final results = <TestResult>[];

    // 测试: AI洞察缓存显示
    results.add(await _testL2AiInsight());

    // 测试: 家庭成员同步队列
    results.add(await _testL2FamilySync());

    return results;
  }

  /// 测试: AI洞察缓存显示
  Future<TestResult> _testL2AiInsight() async {
    final testName = 'L2: AI洞察离线显示缓存内容';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('ai_insight');
      final capability = _offlineService.getFeatureCapability('ai_insight');

      _networkSimulator.stopSimulation();

      // L2功能离线时仍可用（显示缓存）
      if (isAvailable && capability?.offlineLevel == OfflineLevel.onlinePreferred) {
        return TestResult(
          name: testName,
          passed: true,
          message: 'AI洞察在离线状态下显示缓存内容',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: 'AI洞察降级配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 家庭成员同步队列
  Future<TestResult> _testL2FamilySync() async {
    final testName = 'L2: 家庭账本离线队列暂存';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('family_member_sync');
      final capability = _offlineService.getFeatureCapability('family_member_sync');

      _networkSimulator.stopSimulation();

      if (isAvailable && capability?.degradationHint == '待同步标记') {
        return TestResult(
          name: testName,
          passed: true,
          message: '家庭账本同步在离线状态下使用队列缓存',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '家庭账本同步降级配置不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// L3 仅在线测试
  Future<List<TestResult>> _runL3Tests() async {
    final results = <TestResult>[];

    // 测试: 数据同步离线禁用
    results.add(await _testL3DataSync());

    // 测试: 云端备份离线禁用
    results.add(await _testL3CloudBackup());

    return results;
  }

  /// 测试: 数据同步离线禁用
  Future<TestResult> _testL3DataSync() async {
    final testName = 'L3: 数据同步离线时禁用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('data_sync');

      _networkSimulator.stopSimulation();

      if (!isAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: '数据同步在离线状态下正确禁用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '数据同步应在离线状态下禁用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 测试: 云端备份离线禁用
  Future<TestResult> _testL3CloudBackup() async {
    final testName = 'L3: 云端备份离线时禁用';

    try {
      _networkSimulator.startSimulation();
      _networkSimulator.simulateOffline();

      final isAvailable = _offlineService.isFeatureAvailable('cloud_backup');

      _networkSimulator.stopSimulation();

      if (!isAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: '云端备份在离线状态下正确禁用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '云端备份应在离线状态下禁用',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }

  /// 网络恢复测试
  Future<List<TestResult>> _runRecoveryTests() async {
    final results = <TestResult>[];

    // 测试: 网络恢复后L3功能恢复
    results.add(await _testNetworkRecovery());

    return results;
  }

  /// 测试: 网络恢复后功能恢复
  Future<TestResult> _testNetworkRecovery() async {
    final testName = '网络恢复: L3功能恢复可用';

    try {
      _networkSimulator.startSimulation();

      // 先模拟离线
      _networkSimulator.simulateOffline();
      final offlineAvailable = _offlineService.isFeatureAvailable('data_sync');

      // 然后恢复在线
      _networkSimulator.simulateOnline();
      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 100));
      final onlineAvailable = _offlineService.isFeatureAvailable('data_sync');

      _networkSimulator.stopSimulation();

      if (!offlineAvailable && onlineAvailable) {
        return TestResult(
          name: testName,
          passed: true,
          message: 'L3功能在网络恢复后正确恢复可用',
        );
      } else {
        return TestResult(
          name: testName,
          passed: false,
          message: '网络恢复后功能状态不正确',
        );
      }
    } catch (e) {
      return TestResult(
        name: testName,
        passed: false,
        message: '测试异常: $e',
      );
    }
  }
}

/// 测试结果
class TestResult {
  final String name;
  final bool passed;
  final String message;
  final Duration? duration;

  const TestResult({
    required this.name,
    required this.passed,
    required this.message,
    this.duration,
  });

  @override
  String toString() {
    final status = passed ? '✓ PASS' : '✗ FAIL';
    return '$status: $name\n  $message';
  }
}

/// 测试套件结果
class TestSuiteResult {
  final int totalTests;
  final int passed;
  final int failed;
  final List<TestResult> results;

  const TestSuiteResult({
    required this.totalTests,
    required this.passed,
    required this.failed,
    required this.results,
  });

  double get passRate => totalTests > 0 ? passed / totalTests * 100 : 0;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('离线能力测试报告');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('总测试数: $totalTests');
    buffer.writeln('通过: $passed');
    buffer.writeln('失败: $failed');
    buffer.writeln('通过率: ${passRate.toStringAsFixed(1)}%');
    buffer.writeln('-'.padRight(60, '-'));
    buffer.writeln('详细结果:');
    for (final result in results) {
      buffer.writeln(result.toString());
    }
    buffer.writeln('='.padRight(60, '='));
    return buffer.toString();
  }
}

/// 运行离线能力测试的便捷函数
Future<void> runOfflineCapabilityTests() async {
  final testSuite = OfflineCapabilityTestSuite();
  final result = await testSuite.runAllTests();
  debugPrint(result.toString());
}
