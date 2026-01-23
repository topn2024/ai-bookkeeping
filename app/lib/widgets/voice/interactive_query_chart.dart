import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/voice/query/query_models.dart';

/// 交互查询图表
///
/// 用于Level 3响应，显示查询结果的交互式图表
/// 支持折线图、柱状图、饼图
class InteractiveQueryChart extends StatefulWidget {
  final QueryChartData chartData;
  final VoidCallback? onDismiss;

  const InteractiveQueryChart({
    Key? key,
    required this.chartData,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<InteractiveQueryChart> createState() => _InteractiveQueryChartState();
}

class _InteractiveQueryChartState extends State<InteractiveQueryChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.chartData.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    switch (widget.chartData.chartType) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
    }
  }

  /// 构建折线图
  Widget _buildLineChart() {
    final dataPoints = widget.chartData.dataPoints;
    if (dataPoints.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 限制数据点数量（最多1000个点）
    final limitedPoints = dataPoints.length > 1000
        ? _sampleData(dataPoints, 1000)
        : dataPoints;

    final spots = limitedPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final maxY = limitedPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minY = limitedPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (limitedPoints.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < limitedPoints.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      limitedPoints[index].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (limitedPoints.length - 1).toDouble(),
        minY: minY * 0.9,
        maxY: maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: limitedPoints.length <= 20,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < limitedPoints.length) {
                  return LineTooltipItem(
                    '${limitedPoints[index].label}\n${spot.y.toStringAsFixed(0)}元',
                    const TextStyle(color: Colors.white),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// 构建柱状图
  Widget _buildBarChart() {
    final dataPoints = widget.chartData.dataPoints;
    if (dataPoints.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 限制数据点数量
    final limitedPoints = dataPoints.length > 50
        ? dataPoints.take(50).toList()
        : dataPoints;

    final maxY = limitedPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${limitedPoints[groupIndex].label}\n${rod.toY.toStringAsFixed(0)}元',
                const TextStyle(color: Colors.white),
              );
            },
          ),
          touchCallback: (event, response) {
            setState(() {
              if (response != null && response.spot != null) {
                _touchedIndex = response.spot!.touchedBarGroupIndex;
              } else {
                _touchedIndex = null;
              }
            });
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < limitedPoints.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      limitedPoints[index].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        barGroups: limitedPoints.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          final isTouched = index == _touchedIndex;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: point.value,
                color: isTouched ? Colors.blue[700] : Colors.blue,
                width: isTouched ? 20 : 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建饼图
  Widget _buildPieChart() {
    final dataPoints = widget.chartData.dataPoints;
    if (dataPoints.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final total = dataPoints.fold(0.0, (sum, point) => sum + point.value);
    final colors = _generateColors(dataPoints.length);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (response != null && response.touchedSection != null) {
                      _touchedIndex = response.touchedSection!.touchedSectionIndex;
                    } else {
                      _touchedIndex = null;
                    }
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: dataPoints.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                final isTouched = index == _touchedIndex;
                final percentage = (point.value / total * 100);

                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: point.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: isTouched ? 65 : 55,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: dataPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              final percentage = (point.value / total * 100);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${point.label} ${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 数据采样（用于大数据量）
  List<DataPoint> _sampleData(List<DataPoint> data, int maxPoints) {
    if (data.length <= maxPoints) return data;

    final step = data.length / maxPoints;
    final sampled = <DataPoint>[];

    for (var i = 0; i < maxPoints; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        sampled.add(data[index]);
      }
    }

    return sampled;
  }

  /// 生成颜色列表
  List<Color> _generateColors(int count) {
    return [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];
  }
}
