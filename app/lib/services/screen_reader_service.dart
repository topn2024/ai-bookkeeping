import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 屏幕阅读服务
///
/// 通过 Android 无障碍服务读取其他应用的屏幕内容
/// 用于读取微信、支付宝等应用的账单信息
///
/// 注意：
/// - 仅支持 Android 平台
/// - 需要用户在系统设置中手动启用无障碍服务
/// - iOS 不支持此功能（系统限制）
class ScreenReaderService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_bookkeeping/screen_reader');

  /// 单例实例
  static final ScreenReaderService _instance = ScreenReaderService._internal();
  factory ScreenReaderService() => _instance;
  ScreenReaderService._internal();

  /// 无障碍服务是否启用
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  /// 是否为 Android 平台
  bool get isSupported => Platform.isAndroid;

  /// 检查无障碍服务是否启用
  Future<bool> checkAccessibilityEnabled() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      _isEnabled = result ?? false;
      notifyListeners();
      return _isEnabled;
    } catch (e) {
      debugPrint('ScreenReaderService: 检查无障碍服务状态失败: $e');
      return false;
    }
  }

  /// 打开无障碍设置页面
  Future<void> openAccessibilitySettings() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('ScreenReaderService: 打开无障碍设置失败: $e');
    }
  }

  /// 读取当前屏幕内容
  ///
  /// 返回屏幕上的所有文本信息
  /// 如果无障碍服务未启用，返回 null
  Future<ScreenContent?> readScreen() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('readScreen');
      if (result == null) return null;

      return ScreenContent(
        packageName: result['packageName'] as String? ?? '',
        texts: (result['texts'] as List?)?.cast<String>() ?? [],
        timestamp: result['timestamp'] as int? ?? 0,
      );
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 读取屏幕失败: ${e.message}');
      if (e.code == 'SERVICE_NOT_ENABLED') {
        _isEnabled = false;
        notifyListeners();
      }
      return null;
    } catch (e) {
      debugPrint('ScreenReaderService: 读取屏幕失败: $e');
      return null;
    }
  }

  /// 解析账单信息
  ///
  /// 读取当前屏幕并尝试解析出账单信息
  /// 支持微信、支付宝等应用的账单页面
  Future<BillInfo?> parseBillInfo() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('parseBillInfo');
      if (result == null) return null;

      return BillInfo(
        amount: (result['amount'] as num?)?.toDouble(),
        merchant: result['merchant'] as String?,
        time: result['time'] as String?,
        type: result['type'] as String? ?? 'expense',
        rawTexts: (result['rawTexts'] as List?)?.cast<String>() ?? [],
        packageName: result['packageName'] as String? ?? '',
        confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 解析账单失败: ${e.message}');
      if (e.code == 'SERVICE_NOT_ENABLED') {
        _isEnabled = false;
        notifyListeners();
      }
      return null;
    } catch (e) {
      debugPrint('ScreenReaderService: 解析账单失败: $e');
      return null;
    }
  }

  /// 解析多笔账单信息
  ///
  /// 从当前屏幕解析出多笔交易记录
  /// 支持长截图、账单列表等包含多笔交易的页面
  Future<List<BillInfo>> parseMultipleBills() async {
    if (!isSupported) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('parseMultipleBills');
      if (result == null || result.isEmpty) return [];

      return result.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return BillInfo(
          amount: (map['amount'] as num?)?.toDouble(),
          merchant: map['merchant'] as String?,
          time: map['time'] as String?,
          type: map['type'] as String? ?? 'expense',
          rawTexts: (map['rawTexts'] as List?)?.cast<String>() ?? [],
          packageName: map['packageName'] as String? ?? '',
          confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 解析多笔账单失败: ${e.message}');
      if (e.code == 'SERVICE_NOT_ENABLED') {
        _isEnabled = false;
        notifyListeners();
      }
      return [];
    } catch (e) {
      debugPrint('ScreenReaderService: 解析多笔账单失败: $e');
      return [];
    }
  }

  /// 截取当前屏幕
  ///
  /// 需要 Android 11+ 和无障碍服务启用
  /// 返回截图文件路径
  Future<String?> takeScreenshot() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<String>('takeScreenshot');
      return result;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 截屏失败: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ScreenReaderService: 截屏失败: $e');
      return null;
    }
  }

  /// 语音触发的屏幕识别记账
  ///
  /// 完整流程：
  /// 1. 检查无障碍服务是否启用
  /// 2. 读取当前屏幕内容
  /// 3. 解析账单信息（支持多笔）
  /// 4. 返回可用于记账的数据
  Future<VoiceScreenRecognitionResult> recognizeFromScreen() async {
    // 检查平台支持
    if (!isSupported) {
      return VoiceScreenRecognitionResult.notSupported();
    }

    // 检查服务状态
    final enabled = await checkAccessibilityEnabled();
    if (!enabled) {
      return VoiceScreenRecognitionResult.serviceNotEnabled();
    }

    // 尝试解析多笔账单
    final bills = await parseMultipleBills();

    if (bills.isEmpty) {
      return VoiceScreenRecognitionResult.noBillFound();
    }

    // 过滤低置信度的账单
    final validBills = bills.where((b) => b.confidence >= 0.3).toList();
    final lowConfidenceBills = bills.where((b) => b.confidence < 0.3).toList();

    if (validBills.isEmpty && lowConfidenceBills.isNotEmpty) {
      // 只有低置信度的账单
      return VoiceScreenRecognitionResult.lowConfidence(
        lowConfidenceBills.first,
        allBills: lowConfidenceBills,
      );
    }

    if (validBills.isEmpty) {
      return VoiceScreenRecognitionResult.noBillFound();
    }

    // 返回成功结果（可能包含多笔）
    return VoiceScreenRecognitionResult.success(
      validBills.first,
      allBills: validBills,
    );
  }

  // ==================== 自动化功能 ====================

  /// 支付宝包名
  static const String alipayPackage = 'com.eg.android.AlipayGphone';

  /// 微信包名
  static const String wechatPackage = 'com.tencent.mm';

  /// 启动应用
  ///
  /// [packageName] 应用包名
  /// 返回是否成功启动
  Future<bool> launchApp(String packageName) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'launchApp',
        {'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 启动应用失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 启动应用失败: $e');
      return false;
    }
  }

  /// 获取当前前台应用包名
  Future<String?> getCurrentPackageName() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<String>('getCurrentPackageName');
      return result;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 获取当前包名失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return null;
    } catch (e) {
      debugPrint('ScreenReaderService: 获取当前包名失败: $e');
      return null;
    }
  }

  /// 通过文本点击元素
  ///
  /// [text] 要查找的文本
  /// 返回是否成功点击
  Future<bool> clickElement(String text) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'clickElement',
        {'text': text},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 点击元素失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 点击元素失败: $e');
      return false;
    }
  }

  /// 通过视图ID点击元素
  Future<bool> clickElementById(String viewId) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'clickElementById',
        {'viewId': viewId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 通过ID点击元素失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 通过ID点击元素失败: $e');
      return false;
    }
  }

  /// 在指定坐标执行点击
  Future<bool> performClick(double x, double y) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'performClick',
        {'x': x, 'y': y},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 坐标点击失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 坐标点击失败: $e');
      return false;
    }
  }

  /// 执行滑动手势
  ///
  /// [startX], [startY] 起始坐标
  /// [endX], [endY] 结束坐标
  /// [duration] 持续时间（毫秒）
  Future<bool> performSwipe(
    double startX,
    double startY,
    double endX,
    double endY, {
    int duration = 300,
  }) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'performSwipe',
        {
          'startX': startX,
          'startY': startY,
          'endX': endX,
          'endY': endY,
          'duration': duration,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 滑动失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 滑动失败: $e');
      return false;
    }
  }

  /// 向下滚动（滑动列表）
  Future<bool> scrollDown({int screenHeight = 2000}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'scrollDown',
        {'screenHeight': screenHeight},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 向下滚动失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 向下滚动失败: $e');
      return false;
    }
  }

  /// 向上滚动
  Future<bool> scrollUp({int screenHeight = 2000}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'scrollUp',
        {'screenHeight': screenHeight},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 向上滚动失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 向上滚动失败: $e');
      return false;
    }
  }

  /// 等待元素出现
  ///
  /// [text] 要等待的文本
  /// [timeout] 超时时间（毫秒）
  /// 返回是否找到元素
  Future<bool> waitForElement(String text, {int timeout = 5000}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'waitForElement',
        {'text': text, 'timeout': timeout},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 等待元素失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 等待元素失败: $e');
      return false;
    }
  }

  /// 等待特定应用出现在前台
  ///
  /// [packageName] 包名
  /// [timeout] 超时时间（毫秒）
  Future<bool> waitForApp(String packageName, {int timeout = 5000}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'waitForApp',
        {'packageName': packageName, 'timeout': timeout},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 等待应用失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 等待应用失败: $e');
      return false;
    }
  }

  /// 检查元素是否存在
  Future<bool> elementExists(String text) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'elementExists',
        {'text': text},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 检查元素存在失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 检查元素存在失败: $e');
      return false;
    }
  }

  /// 执行返回操作
  Future<bool> performBack() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('performBack');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 返回操作失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 返回操作失败: $e');
      return false;
    }
  }

  /// 回到桌面
  Future<bool> performHome() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('performHome');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenReaderService: 回到桌面失败: ${e.message}');
      _handleServiceNotEnabled(e);
      return false;
    } catch (e) {
      debugPrint('ScreenReaderService: 回到桌面失败: $e');
      return false;
    }
  }

  /// 处理服务未启用的异常
  void _handleServiceNotEnabled(PlatformException e) {
    if (e.code == 'SERVICE_NOT_ENABLED') {
      _isEnabled = false;
      notifyListeners();
    }
  }

  // ==================== 高级导航方法 ====================

  /// 导航到支付宝账单页面
  ///
  /// 流程: 启动支付宝 -> 点击"我的" -> 点击"账单"
  /// 返回是否成功导航
  Future<bool> navigateToAlipayBills() async {
    // 启动支付宝
    if (!await launchApp(alipayPackage)) {
      return false;
    }

    // 等待支付宝启动
    if (!await waitForApp(alipayPackage, timeout: 8000)) {
      return false;
    }

    // 等待首页加载
    await Future.delayed(const Duration(milliseconds: 1500));

    // 点击"我的"
    if (!await clickElement('我的')) {
      return false;
    }

    // 等待"我的"页面加载
    await Future.delayed(const Duration(milliseconds: 1000));

    // 点击"账单"
    if (!await clickElement('账单')) {
      // 尝试其他可能的文案
      if (!await clickElement('全部账单')) {
        return false;
      }
    }

    // 等待账单页面加载
    await Future.delayed(const Duration(milliseconds: 1500));

    return true;
  }

  /// 导航到微信账单页面
  ///
  /// 流程: 启动微信 -> 点击"我" -> 点击"服务"/"支付" -> 点击"钱包" -> 点击"账单"
  /// 返回是否成功导航
  Future<bool> navigateToWeChatBills() async {
    // 启动微信
    if (!await launchApp(wechatPackage)) {
      return false;
    }

    // 等待微信启动
    if (!await waitForApp(wechatPackage, timeout: 8000)) {
      return false;
    }

    // 等待首页加载
    await Future.delayed(const Duration(milliseconds: 1500));

    // 点击"我"
    if (!await clickElement('我')) {
      return false;
    }

    // 等待"我"页面加载
    await Future.delayed(const Duration(milliseconds: 1000));

    // 点击"服务"或"支付"（不同版本微信文案不同）
    if (!await clickElement('服务')) {
      if (!await clickElement('支付')) {
        return false;
      }
    }

    // 等待支付页面加载
    await Future.delayed(const Duration(milliseconds: 1000));

    // 点击"钱包"
    if (!await clickElement('钱包')) {
      return false;
    }

    // 等待钱包页面加载
    await Future.delayed(const Duration(milliseconds: 1000));

    // 点击"账单"
    if (!await clickElement('账单')) {
      return false;
    }

    // 等待账单页面加载
    await Future.delayed(const Duration(milliseconds: 1500));

    return true;
  }
}

/// 屏幕内容
class ScreenContent {
  /// 当前应用包名
  final String packageName;

  /// 屏幕上的文本列表
  final List<String> texts;

  /// 时间戳
  final int timestamp;

  ScreenContent({
    required this.packageName,
    required this.texts,
    required this.timestamp,
  });

  /// 是否为空
  bool get isEmpty => texts.isEmpty;

  /// 获取应用名称
  String get appName {
    switch (packageName) {
      case 'com.tencent.mm':
        return '微信';
      case 'com.eg.android.AlipayGphone':
        return '支付宝';
      case 'com.unionpay':
        return '云闪付';
      default:
        return packageName;
    }
  }
}

/// 账单信息
class BillInfo {
  /// 金额
  final double? amount;

  /// 商户名称
  final String? merchant;

  /// 交易时间
  final String? time;

  /// 交易类型：expense, income, transfer
  final String type;

  /// 原始文本列表
  final List<String> rawTexts;

  /// 来源应用包名
  final String packageName;

  /// 识别置信度 (0.0 - 1.0)
  final double confidence;

  BillInfo({
    this.amount,
    this.merchant,
    this.time,
    required this.type,
    required this.rawTexts,
    required this.packageName,
    required this.confidence,
  });

  /// 是否有有效金额
  bool get hasValidAmount => amount != null && amount! > 0;

  /// 获取应用名称
  String get appName {
    switch (packageName) {
      case 'com.tencent.mm':
        return '微信';
      case 'com.eg.android.AlipayGphone':
        return '支付宝';
      case 'com.unionpay':
        return '云闪付';
      default:
        return '其他应用';
    }
  }

  /// 获取交易类型显示名称
  String get typeDisplayName {
    switch (type) {
      case 'income':
        return '收入';
      case 'transfer':
        return '转账';
      case 'expense':
      default:
        return '支出';
    }
  }

  /// 生成描述文本
  String get description {
    final parts = <String>[];
    if (merchant != null) parts.add(merchant!);
    if (time != null) parts.add(time!);
    return parts.join(' ');
  }

  @override
  String toString() {
    return 'BillInfo(amount: $amount, merchant: $merchant, type: $type, confidence: $confidence)';
  }
}

/// 语音屏幕识别结果
class VoiceScreenRecognitionResult {
  /// 结果状态
  final VoiceScreenRecognitionStatus status;

  /// 账单信息（成功时有值，兼容单笔场景）
  final BillInfo? billInfo;

  /// 所有识别到的账单（支持多笔）
  final List<BillInfo> allBills;

  /// 错误消息
  final String? errorMessage;

  VoiceScreenRecognitionResult._({
    required this.status,
    this.billInfo,
    this.allBills = const [],
    this.errorMessage,
  });

  /// 成功
  factory VoiceScreenRecognitionResult.success(
    BillInfo billInfo, {
    List<BillInfo>? allBills,
  }) {
    return VoiceScreenRecognitionResult._(
      status: VoiceScreenRecognitionStatus.success,
      billInfo: billInfo,
      allBills: allBills ?? [billInfo],
    );
  }

  /// 平台不支持
  factory VoiceScreenRecognitionResult.notSupported() {
    return VoiceScreenRecognitionResult._(
      status: VoiceScreenRecognitionStatus.notSupported,
      errorMessage: '此功能仅支持 Android 平台',
    );
  }

  /// 服务未启用
  factory VoiceScreenRecognitionResult.serviceNotEnabled() {
    return VoiceScreenRecognitionResult._(
      status: VoiceScreenRecognitionStatus.serviceNotEnabled,
      errorMessage: '请先在系统设置中启用无障碍服务',
    );
  }

  /// 未找到账单信息
  factory VoiceScreenRecognitionResult.noBillFound() {
    return VoiceScreenRecognitionResult._(
      status: VoiceScreenRecognitionStatus.noBillFound,
      errorMessage: '当前页面未找到账单信息',
    );
  }

  /// 低置信度
  factory VoiceScreenRecognitionResult.lowConfidence(
    BillInfo billInfo, {
    List<BillInfo>? allBills,
  }) {
    return VoiceScreenRecognitionResult._(
      status: VoiceScreenRecognitionStatus.lowConfidence,
      billInfo: billInfo,
      allBills: allBills ?? [billInfo],
      errorMessage: '识别结果不确定，请确认',
    );
  }

  /// 是否成功
  bool get isSuccess => status == VoiceScreenRecognitionStatus.success;

  /// 是否需要启用服务
  bool get needsServiceEnabled => status == VoiceScreenRecognitionStatus.serviceNotEnabled;

  /// 是否包含多笔账单
  bool get hasMultipleBills => allBills.length > 1;

  /// 账单数量
  int get billCount => allBills.length;

  /// 总金额
  double get totalAmount {
    return allBills.fold(0.0, (sum, bill) => sum + (bill.amount ?? 0));
  }

  /// 获取语音反馈文本
  String getVoiceFeedback() {
    switch (status) {
      case VoiceScreenRecognitionStatus.success:
        if (hasMultipleBills) {
          // 多笔账单反馈
          final totalText = totalAmount.toStringAsFixed(2);
          return '识别到${billCount}笔交易，总金额$totalText元。是否全部记录？';
        } else {
          // 单笔账单反馈
          final bill = billInfo!;
          final amountText = bill.amount != null ? '${bill.amount!.toStringAsFixed(2)}元' : '金额未知';
          final merchantText = bill.merchant ?? '未知商户';
          return '识别到${bill.appName}${bill.typeDisplayName}：$merchantText，$amountText。是否记录？';
        }

      case VoiceScreenRecognitionStatus.lowConfidence:
        if (hasMultipleBills) {
          return '可能识别到${billCount}笔交易，但不太确定。请确认是否正确？';
        } else {
          final bill = billInfo!;
          final amountText = bill.amount != null ? '${bill.amount!.toStringAsFixed(2)}元' : '金额未知';
          return '可能识别到${bill.typeDisplayName}$amountText，但不太确定。请确认是否正确？';
        }

      case VoiceScreenRecognitionStatus.notSupported:
        return '抱歉，此功能仅支持安卓手机';

      case VoiceScreenRecognitionStatus.serviceNotEnabled:
        return '需要启用无障碍服务才能读取屏幕内容。是否前往设置？';

      case VoiceScreenRecognitionStatus.noBillFound:
        return '当前页面没有找到账单信息。请打开账单详情页面后重试。';
    }
  }

  /// 获取详细的多笔账单语音反馈
  String getDetailedVoiceFeedback() {
    if (!isSuccess || !hasMultipleBills) {
      return getVoiceFeedback();
    }

    final buffer = StringBuffer();
    buffer.write('识别到${billCount}笔交易：');

    for (var i = 0; i < allBills.length && i < 5; i++) {
      final bill = allBills[i];
      final amountText = bill.amount?.toStringAsFixed(2) ?? '未知';
      final merchantText = bill.merchant ?? '未知商户';
      buffer.write('第${i + 1}笔，$merchantText，$amountText元；');
    }

    if (allBills.length > 5) {
      buffer.write('还有${allBills.length - 5}笔。');
    }

    buffer.write('总金额${totalAmount.toStringAsFixed(2)}元。是否全部记录？');
    return buffer.toString();
  }
}

/// 语音屏幕识别状态
enum VoiceScreenRecognitionStatus {
  /// 成功识别
  success,

  /// 平台不支持
  notSupported,

  /// 服务未启用
  serviceNotEnabled,

  /// 未找到账单
  noBillFound,

  /// 低置信度
  lowConfidence,
}
