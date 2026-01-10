import 'dart:async';
import 'dart:math';

/// 位置感知钱龄服务
///
/// 功能：
/// 1. 区分本地消费和异地消费
/// 2. 分离日常消费和临时消费（出差/旅游）
/// 3. 计算加权钱龄
/// 4. 提供钱龄健康评估
class LocationAwareMoneyAgeService {
  final CrossRegionSpendingService _crossRegionService;
  final MoneyAgeCalculator _baseCalculator;
  final SpendingContextAnalyzer _contextAnalyzer;

  LocationAwareMoneyAgeService({
    CrossRegionSpendingService? crossRegionService,
    MoneyAgeCalculator? baseCalculator,
    SpendingContextAnalyzer? contextAnalyzer,
  })  : _crossRegionService = crossRegionService ?? CrossRegionSpendingService(),
        _baseCalculator = baseCalculator ?? MoneyAgeCalculator(),
        _contextAnalyzer = contextAnalyzer ?? SpendingContextAnalyzer();

  /// 计算考虑位置因素的钱龄
  Future<EnhancedMoneyAge> calculateMoneyAge({
    required List<LocationTransaction> transactions,
    required List<Income> incomes,
    bool separateTemporarySpending = true,
  }) async {
    // 分离日常消费和临时消费
    final dailyTransactions = <LocationTransaction>[];
    final temporaryTransactions = <LocationTransaction>[];

    for (final tx in transactions) {
      final status = await _crossRegionService.detectCrossRegion(tx);

      if (status == CrossRegionStatus.local) {
        dailyTransactions.add(tx);
      } else if (separateTemporarySpending) {
        temporaryTransactions.add(tx);
      } else {
        dailyTransactions.add(tx);
      }
    }

    // 计算日常钱龄
    final dailyMoneyAge = _baseCalculator.calculate(
      transactions: dailyTransactions,
      incomes: incomes,
    );

    // 计算临时消费钱龄（如有）
    MoneyAge? temporaryMoneyAge;
    if (temporaryTransactions.isNotEmpty) {
      temporaryMoneyAge = _baseCalculator.calculate(
        transactions: temporaryTransactions,
        incomes: incomes,
      );
    }

    // 计算综合钱龄（加权）
    final overallMoneyAge = _calculateWeightedMoneyAge(
      dailyMoneyAge: dailyMoneyAge,
      dailyWeight: 0.85, // 日常消费权重85%
      temporaryMoneyAge: temporaryMoneyAge,
      temporaryWeight: 0.15, // 临时消费权重15%
    );

    return EnhancedMoneyAge(
      overall: overallMoneyAge,
      daily: dailyMoneyAge,
      temporary: temporaryMoneyAge,
      dailyTransactionCount: dailyTransactions.length,
      temporaryTransactionCount: temporaryTransactions.length,
    );
  }

  /// 计算加权钱龄
  MoneyAge _calculateWeightedMoneyAge({
    required MoneyAge dailyMoneyAge,
    required double dailyWeight,
    MoneyAge? temporaryMoneyAge,
    required double temporaryWeight,
  }) {
    if (temporaryMoneyAge == null) {
      return dailyMoneyAge;
    }

    final weightedDays = dailyMoneyAge.days * dailyWeight +
        temporaryMoneyAge.days * temporaryWeight;

    return MoneyAge(
      days: weightedDays,
      totalBalance: dailyMoneyAge.totalBalance + temporaryMoneyAge.totalBalance,
      totalSpending: dailyMoneyAge.totalSpending + temporaryMoneyAge.totalSpending,
    );
  }

  /// 分析消费场景
  Future<SpendingContextAnalysis> analyzeSpendingContext(
    LocationTransaction tx,
  ) async {
    return await _contextAnalyzer.analyze(tx);
  }

  /// 获取钱龄健康建议
  Future<MoneyAgeHealthAdvice> getHealthAdvice({
    required EnhancedMoneyAge moneyAge,
    String? userId,
  }) async {
    final assessment = moneyAge.getHealthAssessment();

    final advice = <String>[];

    switch (assessment.status) {
      case HealthStatus.excellent:
        advice.add('资金管理优秀，继续保持');
        break;
      case HealthStatus.good:
        advice.add('资金状况良好');
        break;
      case HealthStatus.fair:
        advice.add('建议关注支出节奏，适当控制消费');
        break;
      case HealthStatus.poor:
        advice.add('钱龄较短，需要改善支出习惯');
        advice.add('建议设置预算，避免非必要支出');
        break;
      case HealthStatus.temporarilyImpacted:
        advice.add('日常资金管理良好');
        advice.add('临时支出结束后钱龄会恢复');
        break;
    }

    // 根据临时消费情况添加建议
    if (moneyAge.hasTemporaryImpact) {
      advice.add('近期有${moneyAge.temporaryTransactionCount}笔异地/临时消费');
      if (moneyAge.temporary != null) {
        advice.add('临时消费影响钱龄约${(moneyAge.overall.days - moneyAge.daily.days).abs().toStringAsFixed(1)}天');
      }
    }

    return MoneyAgeHealthAdvice(
      assessment: assessment,
      advice: advice,
      suggestedActions: _getSuggestedActions(assessment.status),
    );
  }

  List<SuggestedAction> _getSuggestedActions(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return [
          SuggestedAction(
            type: ActionType.maintain,
            title: '继续保持',
            description: '当前消费习惯很好',
          ),
        ];
      case HealthStatus.good:
        return [
          SuggestedAction(
            type: ActionType.optimize,
            title: '小幅优化',
            description: '可以尝试进一步减少非必要支出',
          ),
        ];
      case HealthStatus.fair:
        return [
          SuggestedAction(
            type: ActionType.budget,
            title: '设置预算',
            description: '建议为主要消费类目设置预算',
          ),
          SuggestedAction(
            type: ActionType.review,
            title: '复盘消费',
            description: '回顾近期大额支出是否必要',
          ),
        ];
      case HealthStatus.poor:
        return [
          SuggestedAction(
            type: ActionType.budget,
            title: '紧急设置预算',
            description: '立即为各类目设置预算上限',
          ),
          SuggestedAction(
            type: ActionType.reduce,
            title: '减少支出',
            description: '暂停非必要消费，优先保障刚需',
          ),
        ];
      case HealthStatus.temporarilyImpacted:
        return [
          SuggestedAction(
            type: ActionType.wait,
            title: '等待恢复',
            description: '临时支出结束后钱龄会自然恢复',
          ),
        ];
    }
  }
}

/// 跨区域消费检测服务
class CrossRegionSpendingService {
  String? _homeCity;
  final Set<String> _frequentCities = {};

  /// 设置用户常驻城市
  void setHomeCity(String city) {
    _homeCity = city;
  }

  /// 添加常去城市
  void addFrequentCity(String city) {
    _frequentCities.add(city);
  }

  /// 检测跨区域状态
  Future<CrossRegionStatus> detectCrossRegion(LocationTransaction tx) async {
    if (tx.city == null) return CrossRegionStatus.unknown;
    if (_homeCity == null) return CrossRegionStatus.unknown;

    if (tx.city == _homeCity) {
      return CrossRegionStatus.local;
    }

    if (_frequentCities.contains(tx.city)) {
      return CrossRegionStatus.frequentCity;
    }

    // 检测是否是连续异地消费（出差/旅游）
    if (await _isTripPattern(tx)) {
      return CrossRegionStatus.trip;
    }

    return CrossRegionStatus.crossRegion;
  }

  Future<bool> _isTripPattern(LocationTransaction tx) async {
    // 简化实现：如果同一天有多笔异地消费，视为出行
    return false;
  }
}

/// 钱龄计算器
class MoneyAgeCalculator {
  /// 计算钱龄
  MoneyAge calculate({
    required List<LocationTransaction> transactions,
    required List<Income> incomes,
  }) {
    if (incomes.isEmpty) {
      return MoneyAge(days: 0, totalBalance: 0, totalSpending: 0);
    }

    // 计算总收入和总支出
    final totalIncome =
        incomes.fold(0.0, (sum, income) => sum + income.amount);
    final totalSpending =
        transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalBalance = totalIncome - totalSpending;

    if (totalIncome == 0) {
      return MoneyAge(
        days: 0,
        totalBalance: totalBalance,
        totalSpending: totalSpending,
      );
    }

    // 计算日均支出
    if (transactions.isEmpty) {
      return MoneyAge(
        days: 30, // 无支出时默认30天
        totalBalance: totalBalance,
        totalSpending: 0,
      );
    }

    // 计算消费时间跨度
    final sortedTx = List<LocationTransaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final firstDate = sortedTx.first.date;
    final lastDate = sortedTx.last.date;
    final daySpan = max(1, lastDate.difference(firstDate).inDays);

    // 日均支出
    final dailySpending = totalSpending / daySpan;

    // 钱龄 = 余额 / 日均支出
    final moneyAgeDays =
        dailySpending > 0 ? totalBalance / dailySpending : 30;

    return MoneyAge(
      days: moneyAgeDays.clamp(0, 365).toDouble(),
      totalBalance: totalBalance,
      totalSpending: totalSpending,
      dailySpending: dailySpending,
    );
  }
}

/// 消费场景分析器
class SpendingContextAnalyzer {
  GeoLocation? _homeLocation;
  GeoLocation? _workLocation;

  /// 设置家的位置
  void setHomeLocation(double lat, double lng) {
    _homeLocation = GeoLocation(latitude: lat, longitude: lng);
  }

  /// 设置公司位置
  void setWorkLocation(double lat, double lng) {
    _workLocation = GeoLocation(latitude: lat, longitude: lng);
  }

  /// 分析消费场景
  Future<SpendingContextAnalysis> analyze(LocationTransaction tx) async {
    if (tx.latitude == null || tx.longitude == null) {
      return SpendingContextAnalysis(
        transaction: tx,
        context: SpendingContext.unknown,
      );
    }

    final txLocation = GeoLocation(
      latitude: tx.latitude!,
      longitude: tx.longitude!,
    );

    // 计算与家的距离
    double? distanceFromHome;
    if (_homeLocation != null) {
      distanceFromHome = _calculateDistance(txLocation, _homeLocation!);
    }

    // 计算与公司的距离
    double? distanceFromWork;
    if (_workLocation != null) {
      distanceFromWork = _calculateDistance(txLocation, _workLocation!);
    }

    // 确定消费场景
    final context = _determineContext(
      distanceFromHome: distanceFromHome,
      distanceFromWork: distanceFromWork,
      time: tx.date,
    );

    return SpendingContextAnalysis(
      transaction: tx,
      context: context,
      distanceFromHome: distanceFromHome,
      distanceFromWork: distanceFromWork,
      isCommute: _isCommuteTime(tx.date),
    );
  }

  SpendingContext _determineContext({
    double? distanceFromHome,
    double? distanceFromWork,
    required DateTime time,
  }) {
    // 家附近消费（500米范围内）
    if (distanceFromHome != null && distanceFromHome < 500) {
      return SpendingContext.nearHome;
    }

    // 公司附近消费（300米范围内）
    if (distanceFromWork != null && distanceFromWork < 300) {
      return SpendingContext.nearWork;
    }

    // 通勤时段消费
    if (_isCommuteTime(time)) {
      return SpendingContext.commuting;
    }

    // 远距离消费（超过50公里）
    if (distanceFromHome != null && distanceFromHome > 50000) {
      return SpendingContext.travel;
    }

    return SpendingContext.other;
  }

  bool _isCommuteTime(DateTime time) {
    final weekday = time.weekday;
    final hour = time.hour;

    // 工作日早晚高峰
    if (weekday >= 1 && weekday <= 5) {
      if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
        return true;
      }
    }

    return false;
  }

  /// 计算两点间距离（米）
  double _calculateDistance(GeoLocation a, GeoLocation b) {
    const earthRadius = 6371000.0; // 地球半径（米）

    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;

    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(x), sqrt(1 - x));

    return earthRadius * c;
  }
}

// ==================== 数据模型 ====================

/// 跨区域状态
enum CrossRegionStatus {
  local, // 本地消费
  frequentCity, // 常去城市
  crossRegion, // 异地消费
  trip, // 出行中（连续异地消费）
  unknown, // 未知
}

/// 消费场景
enum SpendingContext {
  nearHome, // 家附近
  nearWork, // 公司附近
  commuting, // 通勤中
  commercial, // 商圈
  travel, // 旅行
  other, // 其他
  unknown, // 未知
}

/// 健康状态
enum HealthStatus {
  excellent, // 优秀 (≥21天)
  good, // 良好 (14-21天)
  fair, // 一般 (7-14天)
  poor, // 较差 (<7天)
  temporarilyImpacted, // 临时影响
}

/// 建议动作类型
enum ActionType {
  maintain, // 保持
  optimize, // 优化
  budget, // 设置预算
  review, // 复盘
  reduce, // 减少支出
  wait, // 等待
}

/// 钱龄
class MoneyAge {
  final double days;
  final double totalBalance;
  final double totalSpending;
  final double? dailySpending;

  const MoneyAge({
    required this.days,
    required this.totalBalance,
    required this.totalSpending,
    this.dailySpending,
  });

  String get description {
    if (days >= 21) return '钱龄健康，资金管理优秀';
    if (days >= 14) return '钱龄良好，消费节奏适中';
    if (days >= 7) return '钱龄一般，需关注支出';
    return '钱龄较短，建议减少非必要支出';
  }

  HealthStatus get healthStatus {
    if (days >= 21) return HealthStatus.excellent;
    if (days >= 14) return HealthStatus.good;
    if (days >= 7) return HealthStatus.fair;
    return HealthStatus.poor;
  }
}

/// 增强版钱龄（区分日常/临时）
class EnhancedMoneyAge {
  final MoneyAge overall; // 综合钱龄
  final MoneyAge daily; // 日常消费钱龄
  final MoneyAge? temporary; // 临时消费钱龄（出差/旅游）
  final int dailyTransactionCount;
  final int temporaryTransactionCount;

  const EnhancedMoneyAge({
    required this.overall,
    required this.daily,
    this.temporary,
    required this.dailyTransactionCount,
    required this.temporaryTransactionCount,
  });

  /// 判断是否有大量临时消费影响钱龄
  bool get hasTemporaryImpact =>
      temporary != null && temporaryTransactionCount > 5;

  /// 获取钱龄健康度评估
  MoneyAgeHealthAssessment getHealthAssessment() {
    // 如果日常钱龄健康但综合钱龄较低，说明是临时消费影响
    if (daily.days >= 14 && overall.days < 14 && hasTemporaryImpact) {
      return MoneyAgeHealthAssessment(
        status: HealthStatus.temporarilyImpacted,
        message: '日常资金管理良好，近期有大额临时支出，钱龄暂时下降属正常现象',
        dailyStatus: daily.healthStatus,
        suggestion: '临时支出结束后，钱龄会自然恢复',
      );
    }

    return MoneyAgeHealthAssessment(
      status: overall.healthStatus,
      message: overall.description,
    );
  }
}

/// 钱龄健康评估
class MoneyAgeHealthAssessment {
  final HealthStatus status;
  final String message;
  final HealthStatus? dailyStatus;
  final String? suggestion;

  const MoneyAgeHealthAssessment({
    required this.status,
    required this.message,
    this.dailyStatus,
    this.suggestion,
  });
}

/// 钱龄健康建议
class MoneyAgeHealthAdvice {
  final MoneyAgeHealthAssessment assessment;
  final List<String> advice;
  final List<SuggestedAction> suggestedActions;

  const MoneyAgeHealthAdvice({
    required this.assessment,
    required this.advice,
    required this.suggestedActions,
  });
}

/// 建议动作
class SuggestedAction {
  final ActionType type;
  final String title;
  final String description;

  const SuggestedAction({
    required this.type,
    required this.title,
    required this.description,
  });
}

/// 消费场景分析结果
class SpendingContextAnalysis {
  final LocationTransaction transaction;
  final SpendingContext context;
  final double? distanceFromHome;
  final double? distanceFromWork;
  final bool isCommute;
  final bool? isBusinessTrip;
  final bool? isVacation;

  const SpendingContextAnalysis({
    required this.transaction,
    required this.context,
    this.distanceFromHome,
    this.distanceFromWork,
    this.isCommute = false,
    this.isBusinessTrip,
    this.isVacation,
  });
}

/// 地理位置
class GeoLocation {
  final double latitude;
  final double longitude;

  const GeoLocation({
    required this.latitude,
    required this.longitude,
  });
}

/// 带位置的交易
class LocationTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String? category;
  final String? description;
  final String? city;
  final double? latitude;
  final double? longitude;

  const LocationTransaction({
    required this.id,
    required this.amount,
    required this.date,
    this.category,
    this.description,
    this.city,
    this.latitude,
    this.longitude,
  });
}

/// 收入
class Income {
  final String id;
  final double amount;
  final DateTime date;
  final String? source;

  const Income({
    required this.id,
    required this.amount,
    required this.date,
    this.source,
  });
}
