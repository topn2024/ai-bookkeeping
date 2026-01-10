import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import 'database_service.dart';
import 'gamification_service.dart';

/// 增强版导出服务
/// 设计文档第11.5节：数据导出功能矩阵（2.0增强版）
/// 支持习惯数据导出、位置热力图导出、导出水印等高级功能
class EnhancedExportService {
  final DatabaseService _db;
  final GamificationService _gamification;

  EnhancedExportService({
    DatabaseService? databaseService,
    GamificationService? gamificationService,
  })  : _db = databaseService ?? DatabaseService(),
        _gamification = gamificationService ??
            GamificationService(databaseService ?? DatabaseService());

  // ========== 习惯数据导出 ==========

  /// 导出习惯数据（成就、连续记账、积分等）
  Future<ExportResult> exportHabitData({
    ExportFormat format = ExportFormat.csv,
    bool includeAchievements = true,
    bool includeStreakHistory = true,
    bool includePointsHistory = true,
    bool includeMilestones = true,
    WatermarkConfig? watermark,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.write('\uFEFF'); // BOM for Excel

      // 标题
      buffer.writeln('习惯数据导出报告');
      buffer.writeln('导出时间,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('');

      // 获取连续记账统计
      final streakStats = await _gamification.getStreakStats();
      buffer.writeln('连续记账统计');
      buffer.writeln('当前连续天数,${streakStats.currentStreak}');
      buffer.writeln('历史最长连续,${streakStats.longestStreak}');
      buffer.writeln('累计记账天数,${streakStats.totalDaysRecorded}');
      buffer.writeln('今日是否记账,${streakStats.isActiveToday ? "是" : "否"}');
      buffer.writeln('');

      // 用户等级
      final level = await _gamification.getUserLevel();
      buffer.writeln('用户等级信息');
      buffer.writeln('当前等级,${level.level}');
      buffer.writeln('等级称号,${level.title}');
      buffer.writeln('当前积分,${level.currentPoints}');
      buffer.writeln('下级所需积分,${level.pointsForNextLevel}');
      buffer.writeln('');

      // 成就列表
      if (includeAchievements) {
        buffer.writeln('已解锁成就');
        buffer.writeln('成就名称,描述,解锁时间,积分');
        final achievements = await _gamification.getUnlockedAchievements();
        final allAchievements = _gamification.getAllAchievements();

        for (final ua in achievements) {
          final achievement = allAchievements.firstWhere(
            (a) => a.id == ua.achievementId,
            orElse: () => Achievement(
              id: ua.achievementId,
              name: ua.achievementId,
              description: '',
              type: AchievementType.special,
            ),
          );
          buffer.writeln(
            '${achievement.name},${achievement.description},${DateFormat('yyyy-MM-dd').format(ua.unlockedAt)},${achievement.actualPoints}',
          );
        }
        buffer.writeln('');

        // 未解锁成就
        buffer.writeln('未解锁成就');
        buffer.writeln('成就名称,描述,稀有度,积分');
        final unlockedIds = achievements.map((a) => a.achievementId).toSet();
        for (final a in allAchievements) {
          if (!unlockedIds.contains(a.id)) {
            buffer.writeln(
              '${a.name},${a.description},${a.rarity.displayName},${a.actualPoints}',
            );
          }
        }
        buffer.writeln('');
      }

      // 积分历史
      if (includePointsHistory) {
        buffer.writeln('积分获取记录');
        buffer.writeln('获取时间,积分,原因');
        final pointsHistory = await _gamification.getPointsHistory(limit: 100);
        for (final p in pointsHistory) {
          final earnedAt = DateTime.fromMillisecondsSinceEpoch(
            p['earnedAt'] as int,
          );
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd HH:mm').format(earnedAt)},${p['points']},${p['reason'] ?? ""}',
          );
        }
        buffer.writeln('');
      }

      // 连续记账日历
      if (includeStreakHistory) {
        buffer.writeln('记账日历（最近90天）');
        buffer.writeln('日期,是否记账');
        final activities = await _db.rawQuery('''
          SELECT date FROM daily_activity
          WHERE date >= ?
          ORDER BY date DESC
        ''', [
          DateTime.now()
              .subtract(const Duration(days: 90))
              .millisecondsSinceEpoch
        ]);

        final activityDates = activities
            .map((a) =>
                DateTime.fromMillisecondsSinceEpoch(a['date'] as int))
            .map((d) => DateFormat('yyyy-MM-dd').format(d))
            .toSet();

        for (int i = 0; i < 90; i++) {
          final date = DateTime.now().subtract(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          buffer.writeln('$dateStr,${activityDates.contains(dateStr) ? "是" : "否"}');
        }
        buffer.writeln('');
      }

      // 里程碑统计
      if (includeMilestones) {
        buffer.writeln('里程碑达成');
        final totalTransactions = await _db.getTransactionCount();
        final firstTransaction = await _db.getFirstTransaction();

        buffer.writeln('总记账笔数,$totalTransactions');
        if (firstTransaction != null) {
          buffer.writeln(
            '首笔记账日期,${DateFormat('yyyy-MM-dd').format(firstTransaction.date)}',
          );
          final daysSinceFirst =
              DateTime.now().difference(firstTransaction.date).inDays;
          buffer.writeln('使用天数,$daysSinceFirst');
        }
      }

      // 添加水印
      String content = buffer.toString();
      if (watermark != null) {
        content = _addTextWatermark(content, watermark);
      }

      // 保存文件
      final filePath = await _saveFile(
        content,
        'habit_data',
        format,
      );

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: 1,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ========== 位置热力图数据导出 ==========

  /// 导出位置消费数据（用于热力图展示）
  Future<ExportResult> exportLocationHeatmapData({
    DateTime? startDate,
    DateTime? endDate,
    ExportFormat format = ExportFormat.csv,
    bool includeRawData = true,
    bool includeAggregated = true,
    WatermarkConfig? watermark,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.write('\uFEFF');

      buffer.writeln('位置消费热力图数据');
      buffer.writeln('导出时间,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      if (startDate != null) {
        buffer.writeln('开始日期,${DateFormat('yyyy-MM-dd').format(startDate)}');
      }
      if (endDate != null) {
        buffer.writeln('结束日期,${DateFormat('yyyy-MM-dd').format(endDate)}');
      }
      buffer.writeln('');

      // 获取位置数据
      var locationRecords = await _db.getLocationRecords();
      // 本地过滤日期
      if (startDate != null) {
        locationRecords = locationRecords.where((r) {
          final date = r['createdAt'] != null ? DateTime.tryParse(r['createdAt'] as String) : null;
          return date == null || date.isAfter(startDate);
        }).toList();
      }
      if (endDate != null) {
        locationRecords = locationRecords.where((r) {
          final date = r['createdAt'] != null ? DateTime.tryParse(r['createdAt'] as String) : null;
          return date == null || date.isBefore(endDate);
        }).toList();
      }

      if (includeAggregated) {
        // 按位置聚合
        buffer.writeln('位置消费汇总');
        buffer.writeln('位置名称,纬度,经度,消费次数,消费总额,平均消费');

        final locationStats = <String, LocationStat>{};

        for (final record in locationRecords) {
          final key = '${record['latitude']}_${record['longitude']}';
          if (!locationStats.containsKey(key)) {
            locationStats[key] = LocationStat(
              name: record['locationName'] as String? ?? '未知位置',
              latitude: record['latitude'] as double,
              longitude: record['longitude'] as double,
            );
          }
          locationStats[key]!.addTransaction(
            record['amount'] as double,
          );
        }

        // 按消费总额排序
        final sortedStats = locationStats.values.toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        for (final stat in sortedStats) {
          buffer.writeln(
            '${stat.name},${stat.latitude},${stat.longitude},${stat.count},${stat.totalAmount.toStringAsFixed(2)},${stat.averageAmount.toStringAsFixed(2)}',
          );
        }
        buffer.writeln('');

        // 按区域聚合（网格）
        buffer.writeln('区域热力数据（0.01度网格）');
        buffer.writeln('网格中心纬度,网格中心经度,消费次数,消费总额,热度等级');

        final gridStats = <String, GridStat>{};
        for (final record in locationRecords) {
          final lat = record['latitude'] as double;
          final lng = record['longitude'] as double;
          // 0.01度约1公里
          final gridLat = (lat / 0.01).round() * 0.01;
          final gridLng = (lng / 0.01).round() * 0.01;
          final key = '${gridLat}_$gridLng';

          if (!gridStats.containsKey(key)) {
            gridStats[key] = GridStat(
              centerLat: gridLat,
              centerLng: gridLng,
            );
          }
          gridStats[key]!.addTransaction(record['amount'] as double);
        }

        // 计算热度等级
        final maxCount =
            gridStats.values.map((g) => g.count).reduce((a, b) => a > b ? a : b);

        for (final stat in gridStats.values) {
          final heatLevel = _calculateHeatLevel(stat.count, maxCount);
          buffer.writeln(
            '${stat.centerLat},${stat.centerLng},${stat.count},${stat.totalAmount.toStringAsFixed(2)},$heatLevel',
          );
        }
        buffer.writeln('');
      }

      // 原始数据
      if (includeRawData) {
        buffer.writeln('原始位置消费记录');
        buffer.writeln('日期,时间,位置名称,纬度,经度,分类,金额,备注');

        for (final record in locationRecords) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            record['timestamp'] as int,
          );
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(date)},${DateFormat('HH:mm').format(date)},${record['locationName'] ?? ""},${record['latitude']},${record['longitude']},${record['category'] ?? ""},${record['amount']},${_escapeCSV(record['note'] as String? ?? "")}',
          );
        }
      }

      // 添加水印
      String content = buffer.toString();
      if (watermark != null) {
        content = _addTextWatermark(content, watermark);
      }

      // 保存文件
      final filePath = await _saveFile(
        content,
        'location_heatmap',
        format,
      );

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: locationRecords.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 导出位置数据为GeoJSON格式（用于地图可视化）
  Future<ExportResult> exportLocationGeoJson({
    DateTime? startDate,
    DateTime? endDate,
    WatermarkConfig? watermark,
  }) async {
    try {
      var locationRecords = await _db.getLocationRecords();
      // Filter by date locally since getLocationRecords doesn't support date params
      if (startDate != null) {
        locationRecords = locationRecords.where((r) {
          final timestamp = r['timestamp'];
          if (timestamp is int) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return date.isAfter(startDate);
          }
          return true;
        }).toList();
      }
      if (endDate != null) {
        locationRecords = locationRecords.where((r) {
          final timestamp = r['timestamp'];
          if (timestamp is int) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return date.isBefore(endDate);
          }
          return true;
        }).toList();
      }

      // 构建GeoJSON
      final features = <Map<String, dynamic>>[];

      for (final record in locationRecords) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [
              record['longitude'],
              record['latitude'],
            ],
          },
          'properties': {
            'name': record['locationName'] ?? '未知位置',
            'amount': record['amount'],
            'category': record['category'],
            'date': DateTime.fromMillisecondsSinceEpoch(
              record['timestamp'] as int,
            ).toIso8601String(),
          },
        });
      }

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
        'metadata': {
          'exportedAt': DateTime.now().toIso8601String(),
          'totalRecords': features.length,
          if (watermark != null) 'watermark': watermark.text,
        },
      };

      final content = const JsonEncoder.withIndent('  ').convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath =
          '${directory.path}/location_data_$timestamp.geojson';

      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: features.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ========== 钱龄数据导出 ==========

  /// 导出钱龄分析数据
  Future<ExportResult> exportMoneyAgeData({
    ExportFormat format = ExportFormat.csv,
    bool includePoolDetails = true,
    bool includeFifoFlow = true,
    WatermarkConfig? watermark,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.write('\uFEFF');

      buffer.writeln('钱龄分析数据导出');
      buffer.writeln('导出时间,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('');

      // 获取钱龄统计
      final moneyAgeStats = await _db.getMoneyAgeStats();
      buffer.writeln('钱龄概览');
      buffer.writeln('平均钱龄(天),${moneyAgeStats['averageAge']?.toStringAsFixed(1) ?? "0"}');
      buffer.writeln('最长钱龄(天),${moneyAgeStats['maxAge'] ?? 0}');
      buffer.writeln('资源池总余额,${moneyAgeStats['totalBalance']?.toStringAsFixed(2) ?? "0.00"}');
      buffer.writeln('');

      // 资源池明细
      if (includePoolDetails) {
        buffer.writeln('资源池明细');
        buffer.writeln('资源池ID,入账日期,原始金额,当前余额,钱龄(天),来源');

        final pools = await _db.getMoneyAgePools();
        for (final pool in pools) {
          final inDate = DateTime.fromMillisecondsSinceEpoch(
            pool['inDate'] as int,
          );
          final ageDays = DateTime.now().difference(inDate).inDays;
          buffer.writeln(
            '${pool['id']},${DateFormat('yyyy-MM-dd').format(inDate)},${pool['originalAmount']},${pool['currentBalance']},$ageDays,${pool['source'] ?? ""}',
          );
        }
        buffer.writeln('');
      }

      // FIFO流水
      if (includeFifoFlow) {
        buffer.writeln('FIFO消费流水（最近100笔）');
        buffer.writeln('消费日期,金额,消耗的资源池ID,资源池入账日期,消费时钱龄');

        var fifoFlow = await _db.getFifoFlowRecords();
        // Limit to 100 records locally
        if (fifoFlow.length > 100) {
          fifoFlow = fifoFlow.take(100).toList();
        }
        for (final flow in fifoFlow) {
          final consumeDate = DateTime.fromMillisecondsSinceEpoch(
            flow['consumeDate'] as int,
          );
          final poolInDate = DateTime.fromMillisecondsSinceEpoch(
            flow['poolInDate'] as int,
          );
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(consumeDate)},${flow['amount']},${flow['poolId']},${DateFormat('yyyy-MM-dd').format(poolInDate)},${flow['ageAtConsume']}',
          );
        }
        buffer.writeln('');

        // 钱龄分布
        buffer.writeln('钱龄分布统计');
        buffer.writeln('钱龄区间,笔数,总金额,占比');

        final ageDistribution = await _db.getMoneyAgeDistribution();
        // Sum total from map values
        final totalAmount = ageDistribution.values.fold<double>(
          0.0,
          (sum, count) => sum + count.toDouble(),
        );

        for (final entry in ageDistribution.entries) {
          final percentage = totalAmount > 0
              ? (entry.value.toDouble() / totalAmount * 100)
                  .toStringAsFixed(1)
              : '0.0';
          buffer.writeln(
            '${entry.key},${entry.value},${entry.value.toDouble().toStringAsFixed(2)},$percentage%',
          );
        }
      }

      // 添加水印
      String content = buffer.toString();
      if (watermark != null) {
        content = _addTextWatermark(content, watermark);
      }

      final filePath = await _saveFile(content, 'money_age', format);

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: 1,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ========== 预算执行导出 ==========

  /// 导出预算执行数据
  Future<ExportResult> exportBudgetExecutionData({
    DateTime? month,
    ExportFormat format = ExportFormat.csv,
    bool includeVaultDetails = true,
    WatermarkConfig? watermark,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.write('\uFEFF');

      final targetMonth = month ?? DateTime.now();
      buffer.writeln('预算执行报告');
      buffer.writeln('月份,${DateFormat('yyyy年MM月').format(targetMonth)}');
      buffer.writeln('导出时间,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('');

      // 获取预算数据
      final budgets = await _db.getBudgetsForMonth(targetMonth);
      final totalBudget = budgets.fold<double>(
        0.0,
        (sum, b) => sum + b.amount,
      );
      // TODO: Calculate spent from transactions if needed
      final totalSpent = 0.0;

      buffer.writeln('预算概览');
      buffer.writeln('总预算,${totalBudget.toStringAsFixed(2)}');
      buffer.writeln('已使用,${totalSpent.toStringAsFixed(2)}');
      buffer.writeln('剩余,${(totalBudget - totalSpent).toStringAsFixed(2)}');
      buffer.writeln('达成率,${totalBudget > 0 ? ((1 - totalSpent / totalBudget) * 100).toStringAsFixed(1) : 0}%');
      buffer.writeln('');

      // 分类预算明细
      buffer.writeln('分类预算明细');
      buffer.writeln('分类,预算金额,已使用,剩余,达成率,状态');

      for (final budget in budgets) {
        final amount = budget.amount;
        // TODO: Calculate spent from transactions if needed
        final spent = 0.0;
        final remaining = amount - spent;
        final rate = amount > 0 ? (1 - spent / amount) * 100 : 100;
        final status = spent > amount ? '超支' : (rate < 20 ? '紧张' : '正常');

        buffer.writeln(
          '${budget.categoryId ?? budget.name},${amount.toStringAsFixed(2)},${spent.toStringAsFixed(2)},${remaining.toStringAsFixed(2)},${rate.toStringAsFixed(1)}%,$status',
        );
      }
      buffer.writeln('');

      // 小金库明细
      if (includeVaultDetails) {
        buffer.writeln('小金库收支明细');
        buffer.writeln('小金库名称,类型,金额,日期,备注');

        final vaultRecords = await _db.getVaultRecordsForMonth(targetMonth);
        for (final record in vaultRecords) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            record['date'] as int,
          );
          buffer.writeln(
            '${record['vaultName']},${record['type']},${record['amount']},${DateFormat('yyyy-MM-dd').format(date)},${_escapeCSV(record['note'] as String? ?? "")}',
          );
        }
      }

      // 添加水印
      String content = buffer.toString();
      if (watermark != null) {
        content = _addTextWatermark(content, watermark);
      }

      final filePath = await _saveFile(content, 'budget_execution', format);

      return ExportResult(
        success: true,
        filePath: filePath,
        recordCount: budgets.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ========== 水印功能 ==========

  /// 添加文本水印
  String _addTextWatermark(String content, WatermarkConfig config) {
    final watermarkLine =
        '# 水印: ${config.text} | 导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}';

    if (config.position == WatermarkPosition.header) {
      return '$watermarkLine\n$content';
    } else if (config.position == WatermarkPosition.footer) {
      return '$content\n$watermarkLine';
    } else {
      // 每N行插入水印
      final lines = content.split('\n');
      final result = <String>[];
      for (int i = 0; i < lines.length; i++) {
        result.add(lines[i]);
        if ((i + 1) % (config.repeatEveryNLines ?? 50) == 0) {
          result.add(watermarkLine);
        }
      }
      return result.join('\n');
    }
  }

  // ========== 辅助方法 ==========

  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<String> _saveFile(
    String content,
    String prefix,
    ExportFormat format,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final extension = format == ExportFormat.csv ? 'csv' : 'xlsx';
    final fileName = '${prefix}_$timestamp.$extension';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return filePath;
  }

  int _calculateHeatLevel(int count, int maxCount) {
    if (maxCount == 0) return 0;
    final ratio = count / maxCount;
    if (ratio >= 0.8) return 5;
    if (ratio >= 0.6) return 4;
    if (ratio >= 0.4) return 3;
    if (ratio >= 0.2) return 2;
    return 1;
  }
}

/// 导出格式
enum ExportFormat {
  csv,
  excel,
  pdf,
  json,
}

/// 导出结果
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int recordCount;

  ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.recordCount = 0,
  });
}

/// 水印配置
class WatermarkConfig {
  final String text;
  final WatermarkPosition position;
  final int? repeatEveryNLines;

  WatermarkConfig({
    required this.text,
    this.position = WatermarkPosition.footer,
    this.repeatEveryNLines,
  });

  /// 从用户信息生成水印
  factory WatermarkConfig.fromUser({
    required String userId,
    String? userName,
  }) {
    final displayName = userName ?? userId.substring(0, 8);
    return WatermarkConfig(
      text: '导出者: $displayName (ID: ${userId.substring(0, 8)}...)',
      position: WatermarkPosition.footer,
    );
  }
}

/// 水印位置
enum WatermarkPosition {
  header,
  footer,
  repeated,
}

/// 位置统计
class LocationStat {
  final String name;
  final double latitude;
  final double longitude;
  int count = 0;
  double totalAmount = 0;

  LocationStat({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  void addTransaction(double amount) {
    count++;
    totalAmount += amount;
  }

  double get averageAmount => count > 0 ? totalAmount / count : 0;
}

/// 网格统计
class GridStat {
  final double centerLat;
  final double centerLng;
  int count = 0;
  double totalAmount = 0;

  GridStat({
    required this.centerLat,
    required this.centerLng,
  });

  void addTransaction(double amount) {
    count++;
    totalAmount += amount;
  }
}
