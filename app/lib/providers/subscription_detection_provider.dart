import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_tracking_service.dart';
import '../services/database_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import 'transaction_provider.dart';

/// 自动检测的订阅模式 Provider
/// 监听交易数据变化，自动从历史交易中识别周期性订阅
final detectedSubscriptionsProvider = FutureProvider<List<SubscriptionPattern>>((ref) async {
  // 监听交易变化，交易更新时重新检测
  ref.watch(transactionProvider);

  final db = sl<IDatabaseService>() as DatabaseService;
  final service = SubscriptionTrackingService(db);
  return service.detectSubscriptions(months: 6);
});
