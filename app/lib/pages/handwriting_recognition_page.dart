import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/antigravity_shadows.dart';

/// 手写识别页面
/// 原型设计 6.04：手写识别
/// - 手写输入区域
/// - 实时识别结果
/// - 历史记录
class HandwritingRecognitionPage extends ConsumerStatefulWidget {
  const HandwritingRecognitionPage({super.key});

  @override
  ConsumerState<HandwritingRecognitionPage> createState() =>
      _HandwritingRecognitionPageState();
}

class _HandwritingRecognitionPageState
    extends ConsumerState<HandwritingRecognitionPage> {
  final List<Offset?> _points = [];
  String _recognizedText = '';
  final List<_RecognizedItem> _history = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: Column(
                children: [
                  _buildRecognizedResult(context, theme),
                  Expanded(
                    child: _buildWritingArea(context, theme),
                  ),
                  _buildToolbar(context, theme),
                  if (_history.isNotEmpty) _buildHistory(context, theme),
                ],
              ),
            ),
            _buildConfirmButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '手写记账',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('帮助功能开发中')),
              );
            },
            icon: const Icon(Icons.help_outline),
            tooltip: '帮助',
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedResult(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AntigravityShadows.L2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '识别结果',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _recognizedText.isEmpty ? '请在下方区域手写输入...' : _recognizedText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: _recognizedText.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritingArea(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 2,
        ),
        boxShadow: AntigravityShadows.L2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _points.add(details.localPosition);
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _points.add(details.localPosition);
            });
            // 模拟实时识别
            _simulateRecognition();
          },
          onPanEnd: (details) {
            setState(() {
              _points.add(null); // 断点
            });
          },
          child: CustomPaint(
            painter: _HandwritingPainter(
              points: _points,
              color: theme.colorScheme.primary,
            ),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: _points.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.gesture,
                            size: 64,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '在此处手写输入',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '支持数字、中文、标点符号',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(
            theme,
            Icons.undo,
            '撤销',
            onTap: () {
              // 撤销最后一笔
              if (_points.isNotEmpty) {
                setState(() {
                  int lastNullIndex = _points.lastIndexOf(null);
                  if (lastNullIndex > 0) {
                    _points.removeRange(
                      _points.sublist(0, lastNullIndex).lastIndexOf(null) + 1,
                      _points.length,
                    );
                  } else {
                    _points.clear();
                  }
                });
              }
            },
          ),
          _buildToolButton(
            theme,
            Icons.delete_outline,
            '清除',
            onTap: () {
              setState(() {
                _points.clear();
                _recognizedText = '';
              });
            },
          ),
          _buildToolButton(
            theme,
            Icons.space_bar,
            '空格',
            onTap: () {
              setState(() {
                _recognizedText += ' ';
              });
            },
          ),
          _buildToolButton(
            theme,
            Icons.keyboard_return,
            '换行',
            onTap: () {
              setState(() {
                _recognizedText += '\n';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    ThemeData theme,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context, ThemeData theme) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _recognizedText = item.text;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  item.text,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: AntigravityShadows.L3,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _recognizedText.isNotEmpty
                ? () {
                    // 添加到历史
                    setState(() {
                      _history.insert(0, _RecognizedItem(_recognizedText));
                      if (_history.length > 10) _history.removeLast();
                    });
                    Navigator.pop(context, _recognizedText);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确认输入'),
          ),
        ),
      ),
    );
  }

  void _simulateRecognition() {
    // 模拟识别结果
    final samples = ['午餐 35元', '打车 18', '咖啡 28', '外卖 45', '地铁 5'];
    if (_points.length % 50 == 0 && _points.isNotEmpty) {
      setState(() {
        _recognizedText = samples[_points.length ~/ 50 % samples.length];
      });
    }
  }
}

class _HandwritingPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;

  _HandwritingPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandwritingPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RecognizedItem {
  final String text;
  final DateTime time;

  _RecognizedItem(this.text) : time = DateTime.now();
}
