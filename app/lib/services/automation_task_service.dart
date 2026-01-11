import 'package:flutter/foundation.dart';

import 'screen_reader_service.dart';
import 'duplicate_detection_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../models/transaction.dart';

/// 自动化任务服务
///
/// 提供智能语音助手的自动化记账功能
/// 支持自动打开支付宝/微信，导航到账单页面，读取并记录交易
class AutomationTaskService {
  static final AutomationTaskService _instance = AutomationTaskService._internal();
  factory AutomationTaskService() => _instance;
  AutomationTaskService._internal();

  final ScreenReaderService _screenReader = ScreenReaderService();
  /// 通过服务定位器获取数据库服务
  IDatabaseService get _dbService => sl<IDatabaseService>();

  /// 当前任务状态
  AutomationTaskStatus _status = AutomationTaskStatus.idle;
  AutomationTaskStatus get status => _status;

  /// 当前任务进度信息
  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  /// 任务结果回调
  void Function(AutomationTaskResult)? onTaskComplete;
  void Function(String)? onProgressUpdate;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 执行支付宝账单同步
  Future<AutomationTaskResult> syncAlipayBills() async {
    return _executeBillSync(
      appName: '支付宝',
      packageName: ScreenReaderService.alipayPackage,
      navigateFunction: _screenReader.navigateToAlipayBills,
    );
  }

  /// 执行微信账单同步
  Future<AutomationTaskResult> syncWeChatBills() async {
    return _executeBillSync(
      appName: '微信',
      packageName: ScreenReaderService.wechatPackage,
      navigateFunction: _screenReader.navigateToWeChatBills,
    );
  }

  /// 通用账单同步流程
  Future<AutomationTaskResult> _executeBillSync({
    required String appName,
    required String packageName,
    required Future<bool> Function() navigateFunction,
  }) async {
    if (_status == AutomationTaskStatus.running) {
      return AutomationTaskResult.error('已有任务在运行中');
    }

    _status = AutomationTaskStatus.running;
    _updateProgress('正在准备...');

    try {
      // 检查无障碍服务
      final enabled = await _screenReader.checkAccessibilityEnabled();
      if (!enabled) {
        _status = AutomationTaskStatus.idle;
        return AutomationTaskResult.serviceNotEnabled();
      }

      // 导航到账单页面（带重试）
      _updateProgress('正在打开$appName...');
      bool navigated = false;
      for (int i = 0; i < maxRetries && !navigated; i++) {
        navigated = await navigateFunction();
        if (!navigated && i < maxRetries - 1) {
          _updateProgress('导航失败，正在重试 (${i + 2}/$maxRetries)...');
          await Future.delayed(const Duration(seconds: 2));
          // 返回桌面重试
          await _screenReader.performHome();
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!navigated) {
        _status = AutomationTaskStatus.idle;
        return AutomationTaskResult.navigationFailed(appName);
      }

      // 读取并收集账单
      _updateProgress('正在读取账单列表...');
      final allBills = await _collectBillsWithScroll(packageName);

      if (allBills.isEmpty) {
        _status = AutomationTaskStatus.idle;
        return AutomationTaskResult.noBillsFound();
      }

      _updateProgress('识别到 ${allBills.length} 笔交易，正在去重...');

      // 转换为Transaction并去重
      final transactions = _convertBillsToTransactions(allBills);
      final newTransactions = await _filterDuplicates(transactions);

      if (newTransactions.isEmpty) {
        _status = AutomationTaskStatus.idle;
        return AutomationTaskResult.success(
          totalFound: allBills.length,
          newRecorded: 0,
          message: '识别到 ${allBills.length} 笔交易，但都已存在',
        );
      }

      // 保存新交易
      _updateProgress('正在保存 ${newTransactions.length} 笔新交易...');
      int savedCount = 0;
      for (final transaction in newTransactions) {
        try {
          await _dbService.insertTransaction(transaction);
          savedCount++;
        } catch (e) {
          debugPrint('AutomationTaskService: 保存交易失败: $e');
        }
      }

      _status = AutomationTaskStatus.completed;
      final result = AutomationTaskResult.success(
        totalFound: allBills.length,
        newRecorded: savedCount,
        transactions: newTransactions,
      );

      onTaskComplete?.call(result);
      return result;
    } catch (e) {
      _status = AutomationTaskStatus.error;
      final result = AutomationTaskResult.error('执行出错: $e');
      onTaskComplete?.call(result);
      return result;
    } finally {
      // 返回我们的应用
      await _returnToOurApp();
    }
  }

  /// 滚动读取账单列表
  Future<List<BillInfo>> _collectBillsWithScroll(String packageName) async {
    final allBills = <BillInfo>[];
    final seenSignatures = <String>{};
    int noNewBillsCount = 0;
    const maxScrolls = 10; // 最多滚动10次

    for (int i = 0; i < maxScrolls; i++) {
      // 读取当前屏幕的账单
      final bills = await _screenReader.parseMultipleBills();

      // 过滤重复的账单
      int newCount = 0;
      for (final bill in bills) {
        final signature = _getBillSignature(bill);
        if (!seenSignatures.contains(signature)) {
          seenSignatures.add(signature);
          allBills.add(bill);
          newCount++;
        }
      }

      _updateProgress('已读取 ${allBills.length} 笔交易...');

      // 如果没有新账单，计数
      if (newCount == 0) {
        noNewBillsCount++;
        if (noNewBillsCount >= 2) {
          // 连续2次没有新数据，停止滚动
          break;
        }
      } else {
        noNewBillsCount = 0;
      }

      // 滚动到下一页
      final scrolled = await _screenReader.scrollDown();
      if (!scrolled) {
        break;
      }

      // 等待加载
      await Future.delayed(const Duration(milliseconds: 800));
    }

    return allBills;
  }

  /// 获取账单签名（用于去重）
  String _getBillSignature(BillInfo bill) {
    return '${bill.amount ?? 0}_${bill.merchant ?? ''}_${bill.time ?? ''}_${bill.type}';
  }

  /// 将BillInfo转换为Transaction
  List<Transaction> _convertBillsToTransactions(List<BillInfo> bills) {
    return bills.map((bill) {
      final isIncome = bill.type == 'income';
      final now = DateTime.now();
      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: bill.amount ?? 0,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        category: _guessCategory(bill),
        note: bill.merchant ?? bill.description,
        date: _parseDate(bill.time) ?? now,
        accountId: 'default',
        createdAt: now,
        updatedAt: now,
        source: _getSourceFromPackage(bill.packageName),
      );
    }).where((t) => t.amount > 0).toList();
  }

  /// 根据包名获取来源
  TransactionSource _getSourceFromPackage(String packageName) {
    switch (packageName) {
      case 'com.eg.android.AlipayGphone':
      case 'com.tencent.mm':
        return TransactionSource.import_;
      default:
        return TransactionSource.import_;
    }
  }

  /// 猜测分类
  String _guessCategory(BillInfo bill) {
    final description = (bill.merchant ?? '').toLowerCase();

    // 简单的分类映射
    if (description.contains('餐') ||
        description.contains('美团') ||
        description.contains('饿了么') ||
        description.contains('食')) {
      return '餐饮';
    }
    if (description.contains('滴滴') ||
        description.contains('打车') ||
        description.contains('公交') ||
        description.contains('地铁')) {
      return '交通';
    }
    if (description.contains('超市') ||
        description.contains('便利店') ||
        description.contains('商场')) {
      return '购物';
    }
    if (description.contains('转账') || description.contains('红包')) {
      return '转账';
    }

    return '其他'; // 默认分类
  }

  /// 解析日期时间
  DateTime? _parseDate(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    try {
      // 尝试多种格式
      final patterns = [
        RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})日?\s*(\d{1,2}):(\d{2})'),
        RegExp(r'(\d{1,2})[-/月](\d{1,2})日?\s*(\d{1,2}):(\d{2})'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(timeStr);
        if (match != null) {
          if (match.groupCount >= 5) {
            // 完整日期时间
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
              int.parse(match.group(4)!),
              int.parse(match.group(5)!),
            );
          } else if (match.groupCount >= 4) {
            // 月日时间（使用当前年份）
            final now = DateTime.now();
            return DateTime(
              now.year,
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
              int.parse(match.group(4)!),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('AutomationTaskService: 解析日期失败: $e');
    }

    return null;
  }

  /// 过滤已存在的交易
  Future<List<Transaction>> _filterDuplicates(List<Transaction> transactions) async {
    final newTransactions = <Transaction>[];

    for (final transaction in transactions) {
      // 查找可能的重复
      final potentialDuplicates = await _dbService.findPotentialDuplicates(
        date: transaction.date,
        amount: transaction.amount,
        type: transaction.type,
        dayRange: 1,
      );

      // 检查是否重复
      final checkResult = DuplicateDetectionService.checkDuplicate(
        transaction,
        potentialDuplicates,
      );

      if (!checkResult.hasPotentialDuplicate) {
        newTransactions.add(transaction);
      }
    }

    return newTransactions;
  }

  /// 更新进度
  void _updateProgress(String message) {
    _progressMessage = message;
    onProgressUpdate?.call(message);
    debugPrint('AutomationTaskService: $message');
  }

  /// 返回我们的应用
  Future<void> _returnToOurApp() async {
    // 多次返回以确保退出其他应用
    for (int i = 0; i < 3; i++) {
      await _screenReader.performBack();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // 回到桌面
    await _screenReader.performHome();
  }

  /// 取消当前任务
  void cancelTask() {
    if (_status == AutomationTaskStatus.running) {
      _status = AutomationTaskStatus.cancelled;
      _updateProgress('任务已取消');
    }
  }

  /// 重置状态
  void reset() {
    _status = AutomationTaskStatus.idle;
    _progressMessage = '';
  }
}

/// 自动化任务状态
enum AutomationTaskStatus {
  idle,       // 空闲
  running,    // 运行中
  completed,  // 完成
  error,      // 错误
  cancelled,  // 已取消
}

/// 自动化任务结果
class AutomationTaskResult {
  final AutomationTaskResultStatus status;
  final String message;
  final int totalFound;       // 识别到的总交易数
  final int newRecorded;      // 新记录的交易数
  final List<Transaction> transactions; // 新记录的交易

  AutomationTaskResult._({
    required this.status,
    required this.message,
    this.totalFound = 0,
    this.newRecorded = 0,
    this.transactions = const [],
  });

  factory AutomationTaskResult.success({
    required int totalFound,
    required int newRecorded,
    String? message,
    List<Transaction>? transactions,
  }) {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.success,
      message: message ?? '成功记录 $newRecorded 笔新交易',
      totalFound: totalFound,
      newRecorded: newRecorded,
      transactions: transactions ?? [],
    );
  }

  factory AutomationTaskResult.serviceNotEnabled() {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.serviceNotEnabled,
      message: '需要启用无障碍服务才能使用此功能',
    );
  }

  factory AutomationTaskResult.navigationFailed(String appName) {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.navigationFailed,
      message: '无法导航到$appName账单页面，请确保已安装该应用',
    );
  }

  factory AutomationTaskResult.noBillsFound() {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.noBillsFound,
      message: '当前页面未找到账单信息',
    );
  }

  factory AutomationTaskResult.error(String errorMessage) {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.error,
      message: errorMessage,
    );
  }

  factory AutomationTaskResult.cancelled() {
    return AutomationTaskResult._(
      status: AutomationTaskResultStatus.cancelled,
      message: '任务已取消',
    );
  }

  bool get isSuccess => status == AutomationTaskResultStatus.success;
  bool get needsServiceEnabled => status == AutomationTaskResultStatus.serviceNotEnabled;

  /// 获取语音反馈文本
  String getVoiceFeedback() {
    switch (status) {
      case AutomationTaskResultStatus.success:
        if (newRecorded == 0) {
          return '已识别到$totalFound笔交易，但都已经记录过了';
        }
        final total = transactions.fold<double>(
          0,
          (sum, t) => sum + t.amount,
        );
        return '成功记录$newRecorded笔新交易，总金额${total.toStringAsFixed(2)}元';

      case AutomationTaskResultStatus.serviceNotEnabled:
        return '需要启用无障碍服务才能自动读取账单。是否前往设置？';

      case AutomationTaskResultStatus.navigationFailed:
        return message;

      case AutomationTaskResultStatus.noBillsFound:
        return '没有找到账单信息，请确认已打开账单页面';

      case AutomationTaskResultStatus.error:
        return '执行出错了，$message';

      case AutomationTaskResultStatus.cancelled:
        return '任务已取消';
    }
  }
}

/// 任务结果状态
enum AutomationTaskResultStatus {
  success,           // 成功
  serviceNotEnabled, // 服务未启用
  navigationFailed,  // 导航失败
  noBillsFound,      // 未找到账单
  error,             // 错误
  cancelled,         // 已取消
}
