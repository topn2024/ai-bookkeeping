import 'database_service.dart';
import 'actionable_insight_service.dart';

/// 可优化消费类型
enum OptimizationType {
  /// 订阅
  subscription,

  /// 周期性费用
  recurringFee,

  /// 有更优替代
  betterAlternative,

  /// 可规避费用
  avoidableFee,
}

extension OptimizationTypeExtension on OptimizationType {
  String get displayName {
    switch (this) {
      case OptimizationType.subscription:
        return '订阅';
      case OptimizationType.recurringFee:
        return '周期性费用';
      case OptimizationType.betterAlternative:
        return '更优替代';
      case OptimizationType.avoidableFee:
        return '可规避费用';
    }
  }
}

/// 可优化消费
class OptimizableExpense {
  final OptimizationType type;
  final String merchant;
  final double monthlyAmount;
  final String? frequency;
  final String? betterAlternative;
  final DateTime? lastTransactionDate;

  const OptimizableExpense({
    required this.type,
    required this.merchant,
    required this.monthlyAmount,
    this.frequency,
    this.betterAlternative,
    this.lastTransactionDate,
  });
}

/// 指南缓存条目
class CachedGuide {
  final String id;
  final GuideType type;
  final String target;
  final OperationGuide guide;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final DateTime? lastAccessedAt;
  final GuideSource source;

  const CachedGuide({
    required this.id,
    required this.type,
    required this.target,
    required this.guide,
    required this.cachedAt,
    required this.expiresAt,
    this.lastAccessedAt,
    required this.source,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingDays => expiresAt.difference(DateTime.now()).inDays;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.index,
    'target': target,
    'guide_json': guide.toMap().toString(),
    'cached_at': cachedAt.millisecondsSinceEpoch,
    'expires_at': expiresAt.millisecondsSinceEpoch,
    'last_accessed_at': lastAccessedAt?.millisecondsSinceEpoch,
    'source': source.index,
  };
}

/// 指南生命周期管理服务
///
/// 负责操作指南的全生命周期管理：
/// - 定期检视用户消费，识别可优化项
/// - 预准备相关操作指南
/// - 清理过期或不再需要的指南
/// - 维护常用服务的预置指南缓存
class GuideLifecycleManager {
  final DatabaseService _db;
  final ActionableInsightService _insightService;

  /// 指南缓存有效期（天）
  static const int guideCacheDays = 30;

  /// 未访问指南清理阈值（天）
  static const int unusedCleanupDays = 90;

  /// 常用订阅服务列表
  static const List<String> commonServices = [
    // 视频平台
    'Netflix', '爱奇艺', '腾讯视频', '优酷', 'B站大会员', '芒果TV',
    // 音乐平台
    'Spotify', 'Apple Music', 'QQ音乐', '网易云音乐', '酷狗音乐',
    // 云存储
    'iCloud', 'OneDrive', 'Dropbox', '百度网盘', '阿里云盘',
    // 办公软件
    'Adobe Creative Cloud', 'Microsoft 365', 'WPS会员',
    // 电商会员
    '京东Plus', '淘宝88VIP', '美团会员', '饿了么会员', '盒马会员',
    // 其他
    '知乎盐选', '微博会员', '喜马拉雅VIP', '得到', '樊登读书',
  ];

  GuideLifecycleManager(this._db, this._insightService);

  /// 定期检视用户开销，预准备相关指南
  Future<void> periodicGuidePreparation() async {
    // 获取用户最近90天的消费记录
    final recentExpenses = await _getRecentExpenses(days: 90);

    // 识别可能需要优化的消费
    final optimizableExpenses = _identifyOptimizableExpenses(recentExpenses);

    // 预先准备指南
    for (final expense in optimizableExpenses) {
      await _prepareGuidesForExpense(expense);
    }

    // 清理不再需要的指南
    await _cleanupUnusedGuides(recentExpenses);
  }

  /// 获取最近的消费记录
  Future<List<Map<String, dynamic>>> _getRecentExpenses({
    required int days,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      return await _db.rawQuery('''
        SELECT
          t.id,
          t.amount,
          t.description,
          t.merchant,
          t.transaction_date,
          c.name as category_name,
          c.id as category_id
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.type = 'expense'
          AND t.transaction_date >= ?
        ORDER BY t.transaction_date DESC
      ''', [startDate.millisecondsSinceEpoch]);
    } catch (e) {
      return [];
    }
  }

  /// 识别可优化的消费
  List<OptimizableExpense> _identifyOptimizableExpenses(
    List<Map<String, dynamic>> expenses,
  ) {
    final result = <OptimizableExpense>[];

    // 按商户分组
    final merchantExpenses = <String, List<Map<String, dynamic>>>{};
    for (final expense in expenses) {
      final merchant = expense['merchant'] as String? ?? expense['description'] as String? ?? '';
      if (merchant.isNotEmpty) {
        merchantExpenses.putIfAbsent(merchant, () => []).add(expense);
      }
    }

    // 识别订阅类消费（周期性、固定金额）
    for (final entry in merchantExpenses.entries) {
      final merchant = entry.key;
      final txs = entry.value;

      if (txs.length >= 2) {
        // 检查是否为周期性消费
        final subscription = _detectSubscription(merchant, txs);
        if (subscription != null) {
          result.add(subscription);
        }
      }
    }

    // 识别可能有更优方案的消费
    final alternatives = _identifyBetterAlternatives(expenses);
    result.addAll(alternatives);

    // 识别可规避的费用
    final fees = _identifyAvoidableFees(expenses);
    result.addAll(fees);

    return result;
  }

  /// 检测订阅类消费
  OptimizableExpense? _detectSubscription(
    String merchant,
    List<Map<String, dynamic>> transactions,
  ) {
    if (transactions.length < 2) return null;

    // 按日期排序
    transactions.sort((a, b) {
      final dateA = a['transaction_date'] as int;
      final dateB = b['transaction_date'] as int;
      return dateA.compareTo(dateB);
    });

    // 计算消费间隔
    final intervals = <int>[];
    for (var i = 1; i < transactions.length; i++) {
      final prevDate = transactions[i - 1]['transaction_date'] as int;
      final currDate = transactions[i]['transaction_date'] as int;
      final daysDiff = (currDate - prevDate) ~/ (24 * 60 * 60 * 1000);
      intervals.add(daysDiff);
    }

    if (intervals.isEmpty) return null;

    // 计算平均间隔和标准差
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

    // 检查是否为周期性（月度或年度）
    String? frequency;
    if (avgInterval >= 25 && avgInterval <= 35) {
      frequency = '月付';
    } else if (avgInterval >= 355 && avgInterval <= 375) {
      frequency = '年付';
    } else if (avgInterval >= 6 && avgInterval <= 8) {
      frequency = '周付';
    }

    if (frequency != null) {
      // 计算月均消费
      final totalAmount = transactions.fold(0.0,
          (sum, tx) => sum + (tx['amount'] as num).toDouble());
      final monthlyAmount = frequency == '年付'
          ? totalAmount / transactions.length / 12
          : totalAmount / transactions.length;

      final lastTx = transactions.last;
      return OptimizableExpense(
        type: OptimizationType.subscription,
        merchant: merchant,
        monthlyAmount: monthlyAmount,
        frequency: frequency,
        lastTransactionDate: DateTime.fromMillisecondsSinceEpoch(
          lastTx['transaction_date'] as int,
        ),
      );
    }

    return null;
  }

  /// 识别可能有更优替代的消费
  List<OptimizableExpense> _identifyBetterAlternatives(
    List<Map<String, dynamic>> expenses,
  ) {
    final result = <OptimizableExpense>[];

    // 高频外卖消费
    final foodDeliveryTxs = expenses.where((e) {
      final desc = (e['description'] as String? ?? '').toLowerCase();
      final merchant = (e['merchant'] as String? ?? '').toLowerCase();
      return desc.contains('外卖') ||
          desc.contains('美团') ||
          desc.contains('饿了么') ||
          merchant.contains('美团') ||
          merchant.contains('饿了么');
    }).toList();

    if (foodDeliveryTxs.length >= 20) {
      // 每月超过20次外卖
      final totalAmount = foodDeliveryTxs.fold(0.0,
          (sum, tx) => sum + (tx['amount'] as num).toDouble());
      result.add(OptimizableExpense(
        type: OptimizationType.betterAlternative,
        merchant: '外卖消费',
        monthlyAmount: totalAmount / 3, // 假设90天数据
        betterAlternative: '考虑自己做饭或选择更经济的就餐方式',
      ));
    }

    // 打车消费
    final taxiTxs = expenses.where((e) {
      final desc = (e['description'] as String? ?? '').toLowerCase();
      final merchant = (e['merchant'] as String? ?? '').toLowerCase();
      return desc.contains('滴滴') ||
          desc.contains('打车') ||
          desc.contains('出租') ||
          merchant.contains('滴滴') ||
          merchant.contains('曹操');
    }).toList();

    if (taxiTxs.length >= 15) {
      final totalAmount = taxiTxs.fold(0.0,
          (sum, tx) => sum + (tx['amount'] as num).toDouble());
      result.add(OptimizableExpense(
        type: OptimizationType.betterAlternative,
        merchant: '打车出行',
        monthlyAmount: totalAmount / 3,
        betterAlternative: '考虑公共交通或共享单车',
      ));
    }

    return result;
  }

  /// 识别可规避的费用
  List<OptimizableExpense> _identifyAvoidableFees(
    List<Map<String, dynamic>> expenses,
  ) {
    final result = <OptimizableExpense>[];

    // 手续费、服务费
    final feeTxs = expenses.where((e) {
      final desc = (e['description'] as String? ?? '').toLowerCase();
      return desc.contains('手续费') ||
          desc.contains('服务费') ||
          desc.contains('滞纳金') ||
          desc.contains('罚息') ||
          desc.contains('利息');
    }).toList();

    if (feeTxs.isNotEmpty) {
      final totalFees = feeTxs.fold(0.0,
          (sum, tx) => sum + (tx['amount'] as num).toDouble());
      result.add(OptimizableExpense(
        type: OptimizationType.avoidableFee,
        merchant: '各类手续费/服务费',
        monthlyAmount: totalFees / 3,
      ));
    }

    return result;
  }

  /// 预准备指南
  Future<void> _prepareGuidesForExpense(OptimizableExpense expense) async {
    final guideType = _mapToGuideType(expense.type);

    // 检查是否已有缓存
    final existingGuide = await _getCachedGuide(
      type: guideType,
      target: expense.merchant,
    );

    // 如果没有指南或已过期，预先获取
    if (existingGuide == null || existingGuide.isExpired) {
      final guide = await _fetchOrGenerateGuide(expense);
      if (guide != null) {
        await _cacheGuide(guide, guideType, expense.merchant);
      }
    }
  }

  /// 获取或生成指南
  Future<OperationGuide?> _fetchOrGenerateGuide(OptimizableExpense expense) async {
    // 尝试从 ActionableInsightService 获取预置指南
    final guides = await _insightService.getOperationGuides(
      SpendingInsight(
        id: 'temp_${expense.merchant}',
        type: InsightType.subscriptionOverload,
        title: '订阅优化',
        description: expense.merchant,
        priority: InsightPriority.medium,
        createdAt: DateTime.now(),
      ),
    );

    if (guides.isNotEmpty) {
      return guides.first;
    }

    // 生成通用指南
    return _generateGenericGuide(expense);
  }

  /// 生成通用指南
  OperationGuide _generateGenericGuide(OptimizableExpense expense) {
    final steps = <GuideStep>[];

    switch (expense.type) {
      case OptimizationType.subscription:
        steps.addAll([
          const GuideStep(order: 1, instruction: '打开相关App或网站'),
          const GuideStep(order: 2, instruction: '进入"我的"或"账户设置"'),
          const GuideStep(order: 3, instruction: '找到"会员"或"订阅管理"'),
          const GuideStep(order: 4, instruction: '点击"取消订阅"或"关闭自动续费"'),
          const GuideStep(order: 5, instruction: '确认取消并保存截图'),
        ]);
        break;
      case OptimizationType.recurringFee:
        steps.addAll([
          const GuideStep(order: 1, instruction: '查看费用来源'),
          const GuideStep(order: 2, instruction: '评估是否为必要支出'),
          const GuideStep(order: 3, instruction: '寻找替代方案'),
        ]);
        break;
      case OptimizationType.betterAlternative:
        steps.addAll([
          GuideStep(order: 1, instruction: '当前消费模式：${expense.merchant}'),
          GuideStep(order: 2, instruction: '建议替代方案：${expense.betterAlternative ?? "待评估"}'),
          const GuideStep(order: 3, instruction: '制定切换计划'),
        ]);
        break;
      case OptimizationType.avoidableFee:
        steps.addAll([
          const GuideStep(order: 1, instruction: '了解费用产生原因'),
          const GuideStep(order: 2, instruction: '设置提醒避免逾期'),
          const GuideStep(order: 3, instruction: '选择免手续费的支付方式'),
        ]);
        break;
    }

    return OperationGuide(
      id: 'gen_${expense.merchant.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
      type: _mapToGuideType(expense.type),
      target: expense.merchant,
      title: '${expense.merchant}优化指南',
      steps: steps,
      source: GuideSource.llmGenerated,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: guideCacheDays)),
      disclaimer: '本指南为系统自动生成，具体操作请以实际界面为准',
    );
  }

  /// 映射到指南类型
  GuideType _mapToGuideType(OptimizationType type) {
    switch (type) {
      case OptimizationType.subscription:
        return GuideType.subscriptionCancel;
      case OptimizationType.recurringFee:
        return GuideType.feeAvoidance;
      case OptimizationType.betterAlternative:
        return GuideType.alternativeSwitch;
      case OptimizationType.avoidableFee:
        return GuideType.feeAvoidance;
    }
  }

  /// 获取缓存的指南
  Future<CachedGuide?> _getCachedGuide({
    required GuideType type,
    required String target,
  }) async {
    try {
      final result = await _db.rawQuery('''
        SELECT * FROM operation_guide_cache
        WHERE type = ? AND target = ?
        LIMIT 1
      ''', [type.index, target]);

      if (result.isNotEmpty) {
        final row = result.first;
        return CachedGuide(
          id: row['id'] as String,
          type: GuideType.values[row['type'] as int],
          target: row['target'] as String,
          guide: _parseGuideFromJson(row['guide_json'] as String),
          cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
          lastAccessedAt: row['last_accessed_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(row['last_accessed_at'] as int)
              : null,
          source: GuideSource.values[row['source'] as int],
        );
      }
    } catch (e) {
      // 表可能不存在
    }
    return null;
  }

  /// 解析指南 JSON
  OperationGuide _parseGuideFromJson(String json) {
    // 简化实现，实际应使用 json decode
    return OperationGuide(
      id: 'parsed',
      type: GuideType.subscriptionCancel,
      target: '',
      title: '指南',
      steps: [],
      source: GuideSource.preCached,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// 缓存指南
  Future<void> _cacheGuide(
    OperationGuide guide,
    GuideType type,
    String target,
  ) async {
    try {
      await _db.rawInsert('''
        INSERT OR REPLACE INTO operation_guide_cache (
          id, type, target, guide_json, cached_at, expires_at, source
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        guide.id,
        type.index,
        target,
        guide.toMap().toString(),
        DateTime.now().millisecondsSinceEpoch,
        guide.expiresAt.millisecondsSinceEpoch,
        guide.source.index,
      ]);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 清理不再需要的指南
  Future<void> _cleanupUnusedGuides(
    List<Map<String, dynamic>> recentExpenses,
  ) async {
    final currentMerchants = recentExpenses
        .map((e) => e['merchant'] as String? ?? e['description'] as String? ?? '')
        .where((m) => m.isNotEmpty)
        .toSet();

    try {
      // 获取所有缓存的指南
      final cachedGuides = await _db.rawQuery('''
        SELECT id, target, expires_at, last_accessed_at
        FROM operation_guide_cache
      ''');

      for (final row in cachedGuides) {
        final target = row['target'] as String;
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int);
        final lastAccessedAt = row['last_accessed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['last_accessed_at'] as int)
            : null;

        bool shouldDelete = false;

        // 如果用户不再有对应的消费，且指南已过期，则清除
        if (!currentMerchants.contains(target) && DateTime.now().isAfter(expiresAt)) {
          shouldDelete = true;
        }

        // 即使用户还有消费，超过90天未使用也清理
        if (lastAccessedAt != null) {
          final daysSinceAccess = DateTime.now().difference(lastAccessedAt).inDays;
          if (daysSinceAccess > unusedCleanupDays) {
            shouldDelete = true;
          }
        }

        if (shouldDelete) {
          await _db.rawDelete(
            'DELETE FROM operation_guide_cache WHERE id = ?',
            [row['id']],
          );
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 更新常用服务的预置指南
  Future<void> updatePreCachedGuides() async {
    for (final service in commonServices) {
      final guide = await _getCachedGuide(
        type: GuideType.subscriptionCancel,
        target: service,
      );

      // 每30天更新一次预置指南
      if (guide == null || guide.remainingDays < 0) {
        final newGuide = await _fetchOrGenerateGuide(
          OptimizableExpense(
            type: OptimizationType.subscription,
            merchant: service,
            monthlyAmount: 0,
          ),
        );

        if (newGuide != null) {
          await _cacheGuide(
            OperationGuide(
              id: newGuide.id,
              type: newGuide.type,
              target: newGuide.target,
              title: newGuide.title,
              steps: newGuide.steps,
              source: GuideSource.preCached,
              fetchedAt: newGuide.fetchedAt,
              expiresAt: newGuide.expiresAt,
              disclaimer: newGuide.disclaimer,
              warnings: newGuide.warnings,
              alternatives: newGuide.alternatives,
            ),
            GuideType.subscriptionCancel,
            service,
          );
        }
      }
    }
  }

  /// 记录指南访问
  Future<void> recordGuideAccess(String guideId) async {
    try {
      await _db.rawUpdate('''
        UPDATE operation_guide_cache
        SET last_accessed_at = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, guideId]);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 获取用户相关的所有可用指南
  Future<List<CachedGuide>> getAvailableGuides() async {
    final results = <CachedGuide>[];

    try {
      final rows = await _db.rawQuery('''
        SELECT * FROM operation_guide_cache
        WHERE expires_at > ?
        ORDER BY cached_at DESC
      ''', [DateTime.now().millisecondsSinceEpoch]);

      for (final row in rows) {
        results.add(CachedGuide(
          id: row['id'] as String,
          type: GuideType.values[row['type'] as int],
          target: row['target'] as String,
          guide: _parseGuideFromJson(row['guide_json'] as String),
          cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
          lastAccessedAt: row['last_accessed_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(row['last_accessed_at'] as int)
              : null,
          source: GuideSource.values[row['source'] as int],
        ));
      }
    } catch (e) {
      // 忽略错误
    }

    return results;
  }
}
