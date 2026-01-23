# 设计文档：查询分层执行功能

## 1. 架构概述

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Voice Coordinator                       │
│                    (语音协调器 - 现有)                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              BookkeepingOperationAdapter                     │
│                  (记账操作适配器 - 现有)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  QueryExecutionEngine                        │
│                   (查询执行引擎 - 新增)                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  QueryComplexityAnalyzer (复杂度判定)                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  QueryResultRouter (结果路由)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CustomQueryExecutor (自定义查询执行)                │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ↓               ↓               ↓
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Level 1    │  │  Level 2    │  │  Level 3    │
│  纯语音响应  │  │  轻量卡片    │  │  交互图表    │
│  (增强现有)  │  │  (新增)     │  │  (新增)     │
└─────────────┘  └─────────────┘  └─────────────┘
```

### 1.2 数据流

```
用户语音输入
    ↓
SmartIntentRecognizer (意图识别)
    ↓
IntelligenceEngine (意图引擎)
    ↓
BookkeepingOperationAdapter._query()
    ↓
QueryExecutionEngine.execute()
    ├─ QueryComplexityAnalyzer.analyze() → 计算复杂度评分
    ├─ 根据评分选择查询策略
    │   ├─ Simple: 使用现有DatabaseService
    │   ├─ Medium: 使用现有DatabaseService + 聚合计算
    │   └─ Complex: 使用CustomQueryExecutor
    ├─ 执行查询，获取原始数据
    ├─ QueryResultRouter.route() → 根据复杂度选择响应方式
    │   ├─ Level 1: 生成语音文本
    │   ├─ Level 2: 生成语音文本 + 卡片数据
    │   └─ Level 3: 生成语音摘要 + 图表数据
    └─ 返回QueryResponse
        ↓
VoiceCoordinator (处理响应)
    ├─ 播放语音文本 (TTS)
    ├─ 显示卡片 (如果有)
    └─ 显示图表 (如果有)
```

## 2. 核心组件设计

### 2.1 QueryRequest（查询请求）

```dart
class QueryRequest {
  /// 查询类型
  final QueryType queryType;

  /// 时间范围
  final TimeRange? timeRange;

  /// 分类筛选
  final String? category;

  /// 来源筛选
  final String? source;

  /// 账户筛选
  final String? account;

  /// 交易类型筛选
  final TransactionType? transactionType;

  /// 聚合类型（SUM、AVG、COUNT等）
  final AggregationType? aggregationType;

  /// 分组维度（按分类、按时间等）
  final List<GroupByDimension>? groupBy;

  /// 排序方式
  final SortOrder? sortOrder;

  /// 数据点限制
  final int? limit;
}

enum QueryType {
  summary,        // 总额统计
  recent,         // 最近记录
  trend,          // 趋势分析
  distribution,   // 分布/占比
  comparison,     // 对比分析
  custom,         // 自定义查询
}

enum AggregationType {
  sum,      // 求和
  avg,      // 平均值
  count,    // 计数
  max,      // 最大值
  min,      // 最小值
}

enum GroupByDimension {
  category,     // 按分类
  date,         // 按日期
  month,        // 按月份
  source,       // 按来源
  account,      // 按账户
}
```

### 2.2 QueryResponse（查询响应）

```dart
class QueryResponse {
  /// 响应层级
  final QueryLevel level;

  /// 语音文本（所有层级都有）
  final String voiceText;

  /// 原始数据
  final QueryResult rawData;

  /// 卡片数据（Level 2）
  final QueryCardData? cardData;

  /// 图表数据（Level 3）
  final QueryChartData? chartData;

  /// 复杂度评分
  final int complexityScore;
}

enum QueryLevel {
  simple,   // Level 1: 纯语音
  medium,   // Level 2: 语音+卡片
  complex,  // Level 3: 语音+图表
}

class QueryResult {
  /// 总支出
  final double totalExpense;

  /// 总收入
  final double totalIncome;

  /// 交易笔数
  final int transactionCount;

  /// 时间段描述
  final String periodText;

  /// 详细数据（用于图表）
  final List<DataPoint>? detailedData;

  /// 分组数据（用于分类统计）
  final Map<String, double>? groupedData;
}

class QueryCardData {
  /// 主要数值
  final double primaryValue;

  /// 次要数值（可选）
  final double? secondaryValue;

  /// 进度百分比（0-1）
  final double? progress;

  /// 占比百分比（0-1）
  final double? percentage;

  /// 对比数据（环比、同比）
  final ComparisonData? comparison;

  /// 卡片类型
  final CardType cardType;
}

enum CardType {
  progress,     // 进度条
  percentage,   // 占比
  comparison,   // 对比
}

class QueryChartData {
  /// 图表类型
  final ChartType chartType;

  /// 数据点列表
  final List<DataPoint> dataPoints;

  /// X轴标签
  final List<String> xLabels;

  /// Y轴标签
  final String yLabel;

  /// 图表标题
  final String title;
}

enum ChartType {
  line,      // 折线图（趋势）
  bar,       // 柱状图（对比）
  pie,       // 饼图（占比）
}

class DataPoint {
  final String label;
  final double value;
  final DateTime? timestamp;
  final String? category;
}
```

### 2.3 QueryComplexityAnalyzer（复杂度判定引擎）

```dart
class QueryComplexityAnalyzer {
  /// 计算查询复杂度评分
  int calculateComplexity(QueryRequest request) {
    int score = 0;

    // 1. 时间跨度评分
    score += _scoreTimeSpan(request.timeRange);

    // 2. 数据维度评分
    score += _scoreDimensions(request);

    // 3. 数据点数评分
    score += _scoreDataPoints(request);

    // 4. 查询类型评分
    score += _scoreQueryType(request.queryType);

    return score;
  }

  /// 时间跨度评分
  int _scoreTimeSpan(TimeRange? timeRange) {
    if (timeRange == null) return 0;

    final days = timeRange.endDate.difference(timeRange.startDate).inDays;

    if (days <= 1) return 0;        // 单日：0分
    if (days <= 7) return 1;        // 一周内：1分
    if (days <= 31) return 2;       // 一月内：2分
    if (days <= 90) return 3;       // 三月内：3分
    return 4;                       // 三月以上：4分
  }

  /// 数据维度评分
  int _scoreDimensions(QueryRequest request) {
    int dimensions = 0;

    if (request.category != null) dimensions++;
    if (request.source != null) dimensions++;
    if (request.account != null) dimensions++;
    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      dimensions += request.groupBy!.length;
    }

    if (dimensions == 0) return 0;
    if (dimensions == 1) return 0;
    if (dimensions == 2) return 1;
    return 3;  // 3个及以上维度
  }

  /// 数据点数评分
  int _scoreDataPoints(QueryRequest request) {
    // 根据时间跨度和分组方式估算数据点数
    int estimatedPoints = 1;

    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      if (request.groupBy!.contains(GroupByDimension.date)) {
        final days = request.timeRange?.endDate
            .difference(request.timeRange!.startDate).inDays ?? 1;
        estimatedPoints = days;
      } else if (request.groupBy!.contains(GroupByDimension.month)) {
        final months = (request.timeRange?.endDate.month ?? 1) -
            (request.timeRange?.startDate.month ?? 1) + 1;
        estimatedPoints = months;
      } else if (request.groupBy!.contains(GroupByDimension.category)) {
        estimatedPoints = 7;  // 假设7个分类
      }
    }

    if (estimatedPoints <= 2) return 0;
    if (estimatedPoints <= 4) return 1;
    return 2;  // 5个及以上数据点
  }

  /// 查询类型评分
  int _scoreQueryType(QueryType queryType) {
    switch (queryType) {
      case QueryType.summary:
        return 0;  // 简单统计
      case QueryType.recent:
        return 0;  // 最近记录
      case QueryType.distribution:
        return 2;  // 分布/占比
      case QueryType.trend:
        return 2;  // 趋势分析
      case QueryType.comparison:
        return 1;  // 对比分析
      case QueryType.custom:
        return 3;  // 自定义查询
    }
  }

  /// 确定响应层级
  QueryLevel determineLevel(int complexityScore) {
    if (complexityScore <= 1) return QueryLevel.simple;
    if (complexityScore <= 4) return QueryLevel.medium;
    return QueryLevel.complex;
  }
}
```

### 2.4 QueryResultRouter（结果路由器）

```dart
class QueryResultRouter {
  final QueryComplexityAnalyzer _analyzer;
  final VoiceTextGenerator _voiceTextGenerator;
  final CardDataBuilder _cardDataBuilder;
  final ChartDataBuilder _chartDataBuilder;

  /// 路由查询结果到合适的响应方式
  Future<QueryResponse> route(
    QueryRequest request,
    QueryResult result,
  ) async {
    // 1. 计算复杂度
    final complexityScore = _analyzer.calculateComplexity(request);
    final level = _analyzer.determineLevel(complexityScore);

    // 2. 生成语音文本（所有层级都需要）
    final voiceText = _voiceTextGenerator.generate(request, result);

    // 3. 根据层级生成额外数据
    QueryCardData? cardData;
    QueryChartData? chartData;

    switch (level) {
      case QueryLevel.simple:
        // 只有语音文本
        break;

      case QueryLevel.medium:
        // 生成卡片数据
        cardData = await _cardDataBuilder.build(request, result);
        break;

      case QueryLevel.complex:
        // 生成图表数据
        chartData = await _chartDataBuilder.build(request, result);
        break;
    }

    return QueryResponse(
      level: level,
      voiceText: voiceText,
      rawData: result,
      cardData: cardData,
      chartData: chartData,
      complexityScore: complexityScore,
    );
  }
}
```

### 2.5 CustomQueryExecutor（自定义查询执行器）

```dart
class CustomQueryExecutor {
  final Database _database;
  final SqlQueryGenerator _sqlGenerator;
  final SqlValidator _sqlValidator;
  final ResultTransformer _resultTransformer;

  /// 执行自定义查询
  Future<QueryResult> execute(QueryRequest request) async {
    // 1. 生成SQL
    final sql = _sqlGenerator.generate(request);

    // 2. 验证SQL安全性
    _sqlValidator.validate(sql);

    // 3. 执行查询
    final rawData = await _database.rawQuery(sql);

    // 4. 转换为统一数据结构
    return _resultTransformer.transform(rawData, request);
  }
}

class SqlQueryGenerator {
  /// 生成安全的SQL查询
  String generate(QueryRequest request) {
    final buffer = StringBuffer();

    // SELECT子句
    buffer.write(_buildSelectClause(request));

    // FROM子句
    buffer.write(' FROM transactions');

    // WHERE子句
    final whereClause = _buildWhereClause(request);
    if (whereClause.isNotEmpty) {
      buffer.write(' WHERE $whereClause');
    }

    // GROUP BY子句
    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      buffer.write(' GROUP BY ${_buildGroupByClause(request.groupBy!)}');
    }

    // ORDER BY子句
    if (request.sortOrder != null) {
      buffer.write(' ORDER BY ${_buildOrderByClause(request.sortOrder!)}');
    }

    // LIMIT子句
    if (request.limit != null) {
      buffer.write(' LIMIT ${request.limit}');
    }

    return buffer.toString();
  }

  String _buildSelectClause(QueryRequest request) {
    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      // 分组查询
      final fields = <String>[];

      // 添加分组字段
      for (final dimension in request.groupBy!) {
        fields.add(_dimensionToField(dimension));
      }

      // 添加聚合字段
      final aggType = request.aggregationType ?? AggregationType.sum;
      fields.add('${_aggregationToSql(aggType)}(amount) as value');

      return 'SELECT ${fields.join(', ')}';
    } else {
      // 简单查询
      return 'SELECT *';
    }
  }

  String _buildWhereClause(QueryRequest request) {
    final conditions = <String>[];

    // 时间范围
    if (request.timeRange != null) {
      conditions.add(
        'date >= ${request.timeRange!.startDate.millisecondsSinceEpoch} '
        'AND date < ${request.timeRange!.endDate.millisecondsSinceEpoch}'
      );
    }

    // 分类筛选
    if (request.category != null) {
      conditions.add("category = '${_escape(request.category!)}'");
    }

    // 来源筛选
    if (request.source != null) {
      conditions.add("source = '${_escape(request.source!)}'");
    }

    // 账户筛选
    if (request.account != null) {
      conditions.add("account = '${_escape(request.account!)}'");
    }

    // 交易类型筛选
    if (request.transactionType != null) {
      conditions.add("type = '${request.transactionType!.name}'");
    }

    return conditions.join(' AND ');
  }

  String _buildGroupByClause(List<GroupByDimension> dimensions) {
    return dimensions.map(_dimensionToField).join(', ');
  }

  String _buildOrderByClause(SortOrder sortOrder) {
    // 实现排序逻辑
    return 'date DESC';
  }

  String _dimensionToField(GroupByDimension dimension) {
    switch (dimension) {
      case GroupByDimension.category:
        return 'category';
      case GroupByDimension.date:
        return 'date';
      case GroupByDimension.month:
        return "strftime('%Y-%m', date / 1000, 'unixepoch')";
      case GroupByDimension.source:
        return 'source';
      case GroupByDimension.account:
        return 'account';
    }
  }

  String _aggregationToSql(AggregationType type) {
    switch (type) {
      case AggregationType.sum:
        return 'SUM';
      case AggregationType.avg:
        return 'AVG';
      case AggregationType.count:
        return 'COUNT';
      case AggregationType.max:
        return 'MAX';
      case AggregationType.min:
        return 'MIN';
    }
  }

  String _escape(String value) {
    // SQL注入防护：转义单引号
    return value.replaceAll("'", "''");
  }
}

class SqlValidator {
  /// 白名单：允许的表名
  static const _allowedTables = {'transactions'};

  /// 白名单：允许的字段名
  static const _allowedFields = {
    'id', 'amount', 'category', 'date', 'source', 'account',
    'type', 'note', 'created_at', 'updated_at',
  };

  /// 验证SQL安全性
  void validate(String sql) {
    // 1. 检查是否包含危险关键字
    final dangerous = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE'];
    for (final keyword in dangerous) {
      if (sql.toUpperCase().contains(keyword)) {
        throw SecurityException('SQL包含危险关键字: $keyword');
      }
    }

    // 2. 检查表名是否在白名单中
    // （简化实现，实际需要解析SQL）

    // 3. 检查查询复杂度（防止慢查询）
    if (sql.length > 1000) {
      throw SecurityException('SQL查询过于复杂');
    }
  }
}
```

## 3. UI组件设计

### 3.1 LightweightQueryCard（轻量卡片）

```dart
class LightweightQueryCard extends StatefulWidget {
  final QueryCardData data;
  final Duration displayDuration;

  const LightweightQueryCard({
    required this.data,
    this.displayDuration = const Duration(seconds: 3),
  });

  @override
  State<LightweightQueryCard> createState() => _LightweightQueryCardState();
}

class _LightweightQueryCardState extends State<LightweightQueryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // 淡入
    _controller.forward();

    // 3秒后淡出
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    switch (widget.data.cardType) {
      case CardType.progress:
        return _buildProgressCard();
      case CardType.percentage:
        return _buildPercentageCard();
      case CardType.comparison:
        return _buildComparisonCard();
    }
  }

  Widget _buildProgressCard() {
    return Column(
      children: [
        Text('${widget.data.primaryValue.toStringAsFixed(0)}元'),
        LinearProgressIndicator(
          value: widget.data.progress,
        ),
      ],
    );
  }

  Widget _buildPercentageCard() {
    return Column(
      children: [
        Text('${widget.data.primaryValue.toStringAsFixed(0)}元'),
        Text('占比 ${(widget.data.percentage! * 100).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildComparisonCard() {
    return Column(
      children: [
        Text('本期: ${widget.data.primaryValue.toStringAsFixed(0)}元'),
        Text('上期: ${widget.data.secondaryValue!.toStringAsFixed(0)}元'),
      ],
    );
  }
}
```

### 3.2 InteractiveQueryChart（交互图表）

```dart
class InteractiveQueryChart extends StatelessWidget {
  final QueryChartData data;

  const InteractiveQueryChart({required this.data});

  @override
  Widget build(BuildContext context) {
    switch (data.chartType) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
    }
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: data.dataPoints
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.xLabels.length) {
                  return Text(data.xLabels[index]);
                }
                return const Text('');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    // 实现柱状图
    return Container();
  }

  Widget _buildPieChart() {
    // 实现饼图
    return Container();
  }
}
```

## 4. 集成方案

### 4.1 修改BookkeepingOperationAdapter

```dart
class BookkeepingOperationAdapter implements OperationAdapter {
  final QueryExecutionEngine _queryEngine;

  Future<ExecutionResult> _query(Map<String, dynamic> params) async {
    // 1. 构建QueryRequest
    final request = _buildQueryRequest(params);

    // 2. 执行查询
    final response = await _queryEngine.execute(request);

    // 3. 返回结果
    return ExecutionResult.success(data: {
      'queryResponse': response,
      'responseText': response.voiceText,
      'level': response.level.name,
      'cardData': response.cardData,
      'chartData': response.chartData,
    });
  }

  QueryRequest _buildQueryRequest(Map<String, dynamic> params) {
    // 从params构建QueryRequest
    // ...
  }
}
```

### 4.2 修改VoiceCoordinator

```dart
class VoiceCoordinator {
  Future<void> _handleQueryResult(ExecutionResult result) async {
    final queryResponse = result.data['queryResponse'] as QueryResponse;

    // 1. 播放语音文本
    await _ttsService.speak(queryResponse.voiceText);

    // 2. 根据层级显示UI
    switch (queryResponse.level) {
      case QueryLevel.simple:
        // 只有语音，不显示UI
        break;

      case QueryLevel.medium:
        // 显示轻量卡片
        _showQueryCard(queryResponse.cardData!);
        break;

      case QueryLevel.complex:
        // 显示交互图表
        _showQueryChart(queryResponse.chartData!);
        break;
    }
  }

  void _showQueryCard(QueryCardData cardData) {
    // 在语音助手界面显示卡片
    // ...
  }

  void _showQueryChart(QueryChartData chartData) {
    // 在语音助手界面显示图表
    // ...
  }
}
```

## 5. 性能优化

### 5.1 数据采样

对于数据点过多的查询（>1000个点），进行采样：

```dart
List<DataPoint> _sampleDataPoints(List<DataPoint> points, int maxPoints) {
  if (points.length <= maxPoints) return points;

  final step = points.length / maxPoints;
  final sampled = <DataPoint>[];

  for (var i = 0; i < maxPoints; i++) {
    final index = (i * step).floor();
    sampled.add(points[index]);
  }

  return sampled;
}
```

### 5.2 查询缓存

对于相同的查询请求，缓存结果：

```dart
class QueryCache {
  final Map<String, QueryResult> _cache = {};
  final Duration _ttl = Duration(minutes: 5);

  Future<QueryResult?> get(QueryRequest request) async {
    final key = _generateKey(request);
    return _cache[key];
  }

  void set(QueryRequest request, QueryResult result) {
    final key = _generateKey(request);
    _cache[key] = result;

    // 5分钟后清除
    Future.delayed(_ttl, () => _cache.remove(key));
  }

  String _generateKey(QueryRequest request) {
    // 生成唯一的缓存键
    return request.toString();
  }
}
```

## 6. 安全考虑

### 6.1 SQL注入防护

1. **参数化查询**：使用`?`占位符
2. **白名单验证**：只允许特定的表名和字段名
3. **输入转义**：转义所有用户输入
4. **查询复杂度限制**：限制SQL长度和执行时间

### 6.2 权限控制

1. **只读查询**：不允许修改数据的SQL
2. **数据隔离**：只能查询当前用户的数据

## 7. 测试策略

### 7.1 单元测试

- QueryComplexityAnalyzer：测试各种查询的复杂度评分
- SqlQueryGenerator：测试SQL生成的正确性
- SqlValidator：测试SQL安全验证

### 7.2 集成测试

- 端到端测试：从语音输入到UI显示的完整流程
- 性能测试：查询响应时间、图表渲染性能

### 7.3 安全测试

- SQL注入测试：尝试各种注入攻击
- 权限测试：验证数据隔离

## 8. 未来扩展

### 8.1 查询优化

- 智能索引建议
- 查询计划分析
- 自动查询优化

### 8.2 更多图表类型

- 散点图
- 雷达图
- 热力图

### 8.3 导出功能

- 导出为Excel
- 导出为PDF
- 分享图表

### 8.4 自然语言查询优化

- 更智能的查询意图识别
- 支持更复杂的自然语言表达
- 查询建议和自动补全
