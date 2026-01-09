import 'package:flutter/foundation.dart';
import '../models/resource_pool.dart';
import 'http_service.dart';

/// Money Age API Service
/// Syncs local money age data with server
class MoneyAgeApiService {
  static final MoneyAgeApiService _instance = MoneyAgeApiService._internal();
  factory MoneyAgeApiService() => _instance;
  MoneyAgeApiService._internal();

  final HttpService _http = HttpService();

  /// Fetch resource pools from server
  Future<List<ResourcePool>> getResourcePools({
    required String bookId,
    bool? isFullyConsumed,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'book_id': bookId,
        'limit': limit,
        'offset': offset,
      };
      if (isFullyConsumed != null) {
        params['is_fully_consumed'] = isFullyConsumed;
      }

      final response = await _http.get('/money-age/resource-pools', queryParams: params);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ResourcePool.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to fetch resource pools: $e');
      return [];
    }
  }

  /// Get money age dashboard data
  Future<MoneyAgeDashboard?> getDashboard({required String bookId}) async {
    try {
      final response = await _http.get(
        '/money-age/dashboard',
        queryParams: {'book_id': bookId},
      );
      if (response.statusCode == 200) {
        return MoneyAgeDashboard.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to fetch dashboard: $e');
      return null;
    }
  }

  /// Get money age health status
  Future<MoneyAgeHealth?> getHealth({required String bookId}) async {
    try {
      final response = await _http.get(
        '/money-age/health',
        queryParams: {'book_id': bookId},
      );
      if (response.statusCode == 200) {
        return MoneyAgeHealth.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to fetch health: $e');
      return null;
    }
  }

  /// Calculate money age for a transaction
  Future<MoneyAgeCalculation?> calculate({
    required String bookId,
    required double amount,
    required DateTime date,
  }) async {
    try {
      final response = await _http.post('/money-age/calculate', data: {
        'book_id': bookId,
        'amount': amount,
        'date': date.toIso8601String(),
      });
      if (response.statusCode == 200) {
        return MoneyAgeCalculation.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to calculate: $e');
      return null;
    }
  }

  /// Get money age trend data
  Future<List<MoneyAgeTrendPoint>> getTrend({
    required String bookId,
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  }) async {
    try {
      final response = await _http.post('/money-age/trend', data: {
        'book_id': bookId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'granularity': granularity,
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['trend_points'] ?? [];
        return data.map((json) => MoneyAgeTrendPoint.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to fetch trend: $e');
      return [];
    }
  }

  /// Rebuild money age data
  Future<bool> rebuild({required String bookId}) async {
    try {
      final response = await _http.post('/money-age/rebuild', data: {
        'book_id': bookId,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('MoneyAgeApiService: Failed to rebuild: $e');
      return false;
    }
  }
}

/// Money Age Health data
class MoneyAgeHealth {
  final String level;
  final double score;
  final String description;

  MoneyAgeHealth({
    required this.level,
    required this.score,
    required this.description,
  });

  factory MoneyAgeHealth.fromJson(Map<String, dynamic> json) {
    return MoneyAgeHealth(
      level: json['level'] as String? ?? 'unknown',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Money Age Calculation result
class MoneyAgeCalculation {
  final double moneyAge;
  final List<PoolConsumption> consumptions;

  MoneyAgeCalculation({
    required this.moneyAge,
    required this.consumptions,
  });

  factory MoneyAgeCalculation.fromJson(Map<String, dynamic> json) {
    final consumptionsList = json['consumptions'] as List<dynamic>? ?? [];
    return MoneyAgeCalculation(
      moneyAge: (json['money_age'] as num?)?.toDouble() ?? 0,
      consumptions: consumptionsList
          .map((c) => PoolConsumption.fromJson(c))
          .toList(),
    );
  }
}

/// Pool consumption detail
class PoolConsumption {
  final String poolId;
  final double amount;
  final int ageDays;

  PoolConsumption({
    required this.poolId,
    required this.amount,
    required this.ageDays,
  });

  factory PoolConsumption.fromJson(Map<String, dynamic> json) {
    return PoolConsumption(
      poolId: json['pool_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      ageDays: json['age_days'] as int? ?? 0,
    );
  }
}

/// Money Age Trend point
class MoneyAgeTrendPoint {
  final DateTime date;
  final double averageAge;
  final double totalBalance;

  MoneyAgeTrendPoint({
    required this.date,
    required this.averageAge,
    required this.totalBalance,
  });

  factory MoneyAgeTrendPoint.fromJson(Map<String, dynamic> json) {
    return MoneyAgeTrendPoint(
      date: DateTime.parse(json['date'] as String),
      averageAge: (json['average_age'] as num?)?.toDouble() ?? 0,
      totalBalance: (json['total_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
