import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resource_pool.dart';
import '../services/money_age_api_service.dart';

final moneyAgeApiServiceProvider = Provider<MoneyAgeApiService>((ref) {
  return MoneyAgeApiService();
});

final moneyAgeDashboardProvider = FutureProvider.family<MoneyAgeDashboard?, String>((ref, bookId) async {
  final service = ref.watch(moneyAgeApiServiceProvider);
  return await service.getDashboard(bookId: bookId);
});
