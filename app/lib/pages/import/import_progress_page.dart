import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'import_success_page.dart';

/// 导入进度页面
/// 原型设计 5.13：导入进度
/// - 进度环显示
/// - 状态说明
/// - 当前操作
/// - 已完成步骤
/// - 取消按钮
class ImportProgressPage extends ConsumerStatefulWidget {
  final String fileName;
  final int totalCount;

  const ImportProgressPage({
    super.key,
    required this.fileName,
    required this.totalCount,
  });

  @override
  ConsumerState<ImportProgressPage> createState() => _ImportProgressPageState();
}

class _ImportProgressPageState extends ConsumerState<ImportProgressPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  double _progress = 0;
  int _currentRecord = 0;
  String _currentStep = '格式检测';
  bool _isCancelled = false;

  final List<CompletedStep> _completedSteps = [];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _startImport();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startImport() async {
    // 模拟导入过程
    await _simulateStep('格式检测', 0.1);
    if (_isCancelled) return;
    _completedSteps.add(CompletedStep(name: '格式检测完成', icon: Icons.check_circle));

    await _simulateStep('去重检测', 0.25);
    if (_isCancelled) return;
    _completedSteps.add(CompletedStep(name: '去重检测完成（排除6条）', icon: Icons.check_circle));

    await _simulateStep('AI智能分类', 0.4);
    if (_isCancelled) return;
    _completedSteps.add(CompletedStep(name: 'AI智能分类完成', icon: Icons.check_circle));

    // 写入数据库
    for (int i = 0; i < widget.totalCount && !_isCancelled; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      setState(() {
        _currentStep = '写入数据库';
        _currentRecord = i + 1;
        _progress = 0.4 + (0.6 * (i + 1) / widget.totalCount);
      });
      _updateProgress(_progress);
    }

    if (_isCancelled) return;

    // 导入完成，跳转到成功页面
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ImportSuccessPage(
            fileName: widget.fileName,
            importedCount: widget.totalCount,
            totalExpense: 12580.00,
          ),
        ),
      );
    }
  }

  Future<void> _simulateStep(String stepName, double targetProgress) async {
    setState(() => _currentStep = stepName);

    final steps = 10;
    final startProgress = _progress;
    final progressIncrement = (targetProgress - startProgress) / steps;

    for (int i = 0; i < steps && !_isCancelled; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _progress = startProgress + progressIncrement * (i + 1);
      });
      _updateProgress(_progress);
    }
  }

  void _updateProgress(double newProgress) {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _progressController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressRing(theme),
              const SizedBox(height: 32),
              _buildStatusText(theme),
              const SizedBox(height: 32),
              _buildCurrentOperation(theme),
              const SizedBox(height: 24),
              _buildCompletedSteps(theme),
              const Spacer(),
              _buildCancelButton(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 进度环
  Widget _buildProgressRing(ThemeData theme) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final progress = _progressAnimation.value;
        final percentage = (progress * 100).round();
        final currentCount = (_currentRecord > 0) ? _currentRecord : (progress * widget.totalCount).round();

        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _ProgressRingPainter(
                  progress: progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: theme.colorScheme.primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '$currentCount/${widget.totalCount}',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 状态文本
  Widget _buildStatusText(ThemeData theme) {
    return Column(
      children: [
        Text(
          '正在导入数据...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.fileName,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 当前操作
  Widget _buildCurrentOperation(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentStep,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_currentStep == '写入数据库')
                  Text(
                    '正在写入第$_currentRecord条记录...',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 已完成步骤
  Widget _buildCompletedSteps(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _completedSteps.map((step) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                step.icon,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                step.name,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 取消按钮
  Widget _buildCancelButton(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () => _cancelImport(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('取消导入'),
      ),
    );
  }

  void _cancelImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消导入'),
        content: const Text('确定要取消导入吗？已处理的数据将不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续导入'),
          ),
          TextButton(
            onPressed: () {
              _isCancelled = true;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
  }
}

/// 进度环绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 12.0;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆环
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

/// 已完成步骤
class CompletedStep {
  final String name;
  final IconData icon;

  CompletedStep({required this.name, required this.icon});
}
