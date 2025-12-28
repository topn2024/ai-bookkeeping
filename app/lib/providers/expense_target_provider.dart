import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_target.dart';
import '../services/http_service.dart';
import 'ledger_provider.dart';

/// Expense Target Notifier - 管理月度开支目标
class ExpenseTargetNotifier extends Notifier<List<ExpenseTarget>> {
  final HttpService _http = HttpService();

  @override
  List<ExpenseTarget> build() {
    _loadTargets();
    return [];
  }

  /// 加载所有开支目标
  Future<void> _loadTargets() async {
    try {
      final response = await _http.get('/expense-targets');
      if (response.statusCode == 200) {
        final data = response.data;
        final items = (data['items'] as List)
            .map((item) => ExpenseTarget.fromMap(item))
            .toList();
        state = items;
      }
    } catch (e) {
      // 静默处理错误，保持空列表
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await _loadTargets();
  }

  /// 添加开支目标
  Future<ExpenseTarget?> addTarget({
    required String bookId,
    required String name,
    String? description,
    required double maxAmount,
    String? categoryId,
    required int year,
    required int month,
    int? iconCode,
    int? colorValue,
    int alertThreshold = 80,
    bool enableNotifications = true,
  }) async {
    try {
      final response = await _http.post('/expense-targets', data: {
        'book_id': bookId,
        'name': name,
        'description': description,
        'max_amount': maxAmount,
        'category_id': categoryId,
        'year': year,
        'month': month,
        'icon_code': iconCode,
        'color_value': colorValue,
        'alert_threshold': alertThreshold,
        'enable_notifications': enableNotifications,
      });

      if (response.statusCode == 201) {
        final target = ExpenseTarget.fromMap(response.data);
        state = [...state, target];
        return target;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// 更新开支目标
  Future<ExpenseTarget?> updateTarget(
    String id, {
    String? name,
    String? description,
    double? maxAmount,
    int? iconCode,
    int? colorValue,
    int? alertThreshold,
    bool? enableNotifications,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (maxAmount != null) data['max_amount'] = maxAmount;
      if (iconCode != null) data['icon_code'] = iconCode;
      if (colorValue != null) data['color_value'] = colorValue;
      if (alertThreshold != null) data['alert_threshold'] = alertThreshold;
      if (enableNotifications != null) data['enable_notifications'] = enableNotifications;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _http.patch('/expense-targets/$id', data: data);

      if (response.statusCode == 200) {
        final target = ExpenseTarget.fromMap(response.data);
        state = state.map((t) => t.id == id ? target : t).toList();
        return target;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// 删除开支目标
  Future<bool> deleteTarget(String id) async {
    try {
      final response = await _http.delete('/expense-targets/$id');
      if (response.statusCode == 204) {
        state = state.where((t) => t.id != id).toList();
        return true;
      }
    } catch (e) {
      rethrow;
    }
    return false;
  }

  /// 复制到下个月
  Future<ExpenseTarget?> copyToNextMonth(String id) async {
    try {
      final response = await _http.post('/expense-targets/$id/copy-to-next-month');
      if (response.statusCode == 200) {
        final target = ExpenseTarget.fromMap(response.data);
        state = [...state, target];
        return target;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// 根据 ID 获取开支目标
  ExpenseTarget? getTargetById(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定账本的开支目标
  List<ExpenseTarget> getTargetsForBook(String bookId) {
    return state.where((t) => t.bookId == bookId && t.isActive).toList();
  }

  /// 获取指定月份的开支目标
  List<ExpenseTarget> getTargetsForMonth(int year, int month) {
    return state.where((t) => t.year == year && t.month == month && t.isActive).toList();
  }

  /// 获取当月的开支目标
  List<ExpenseTarget> get currentMonthTargets {
    final now = DateTime.now();
    return getTargetsForMonth(now.year, now.month);
  }

  /// 获取已超支的目标
  List<ExpenseTarget> get exceededTargets {
    return state.where((t) => t.isExceeded && t.isActive).toList();
  }

  /// 获取接近上限的目标
  List<ExpenseTarget> get nearLimitTargets {
    return state.where((t) => t.isNearLimit && t.isActive).toList();
  }
}

/// Expense Target Provider
final expenseTargetProvider =
    NotifierProvider<ExpenseTargetNotifier, List<ExpenseTarget>>(
        ExpenseTargetNotifier.new);

/// 获取指定月份的开支目标 Provider
final monthlyExpenseTargetsProvider =
    Provider.family<List<ExpenseTarget>, ({int year, int month})>(
        (ref, params) {
  final targets = ref.watch(expenseTargetProvider);
  return targets
      .where((t) => t.year == params.year && t.month == params.month && t.isActive)
      .toList();
});

/// 当月开支目标 Provider
final currentMonthExpenseTargetsProvider = Provider<List<ExpenseTarget>>((ref) {
  final now = DateTime.now();
  return ref.watch(monthlyExpenseTargetsProvider((year: now.year, month: now.month)));
});

/// 开支目标汇总 Provider
final expenseTargetSummaryProvider =
    FutureProvider.family<ExpenseTargetSummary?, ({String? bookId, int? year, int? month})>(
        (ref, params) async {
  try {
    final http = HttpService();
    final queryParams = <String, dynamic>{};
    if (params.bookId != null) queryParams['book_id'] = params.bookId;
    if (params.year != null) queryParams['year'] = params.year;
    if (params.month != null) queryParams['month'] = params.month;

    final response = await http.get('/expense-targets/summary', queryParams: queryParams);
    if (response.statusCode == 200) {
      return ExpenseTargetSummary.fromMap(response.data);
    }
  } catch (e) {
    // 静默处理错误
  }
  return null;
});

/// 当月开支目标汇总
final currentMonthSummaryProvider = Provider<AsyncValue<ExpenseTargetSummary?>>((ref) {
  final now = DateTime.now();
  return ref.watch(expenseTargetSummaryProvider((
    bookId: null,
    year: now.year,
    month: now.month,
  )));
});
