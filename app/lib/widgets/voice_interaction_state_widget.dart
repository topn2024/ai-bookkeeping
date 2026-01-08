import 'package:flutter/material.dart';

/// Voice interaction state visual feedback widget (第21章语音交互状态视觉反馈)
class VoiceInteractionStateWidget extends StatefulWidget {
  final VoiceInteractionState state;
  final String? recognizedText;
  final double? audioLevel;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const VoiceInteractionStateWidget({
    super.key,
    required this.state,
    this.recognizedText,
    this.audioLevel,
    this.onTap,
    this.onCancel,
  });

  @override
  State<VoiceInteractionStateWidget> createState() => _VoiceInteractionStateWidgetState();
}

class _VoiceInteractionStateWidgetState extends State<VoiceInteractionStateWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_waveController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _getStateColor(context).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main interaction indicator
            _buildMainIndicator(context),
            const SizedBox(height: 16),

            // Status text
            Text(
              _getStatusText(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: _getStateColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),

            // Recognized text (if any)
            if (widget.recognizedText != null &&
                widget.recognizedText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.recognizedText!,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Cancel button for active states
            if (widget.state == VoiceInteractionState.listening ||
                widget.state == VoiceInteractionState.processing) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getStateColor(context);

    switch (widget.state) {
      case VoiceInteractionState.idle:
        return _buildIdleIndicator(theme, color);
      case VoiceInteractionState.listening:
        return _buildListeningIndicator(theme, color);
      case VoiceInteractionState.processing:
        return _buildProcessingIndicator(theme, color);
      case VoiceInteractionState.success:
        return _buildSuccessIndicator(theme, color);
      case VoiceInteractionState.error:
        return _buildErrorIndicator(theme, color);
    }
  }

  Widget _buildIdleIndicator(ThemeData theme, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.mic,
        size: 36,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildListeningIndicator(ThemeData theme, Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
              ),
            ),
            // Inner ring with audio level
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.3),
              ),
            ),
            // Center icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(
                Icons.mic,
                size: 32,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            // Audio wave visualization
            if (widget.audioLevel != null)
              _buildAudioWave(theme, color),
          ],
        );
      },
    );
  }

  Widget _buildAudioWave(ThemeData theme, Color color) {
    final level = widget.audioLevel ?? 0.0;
    return CustomPaint(
      size: const Size(100, 100),
      painter: AudioWavePainter(
        color: color,
        level: level,
        animation: _waveAnimation.value,
      ),
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        Icon(
          Icons.psychology,
          size: 32,
          color: color,
        ),
      ],
    );
  }

  Widget _buildSuccessIndicator(ThemeData theme, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Icon(
        Icons.check,
        size: 40,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildErrorIndicator(ThemeData theme, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(
        Icons.error_outline,
        size: 40,
        color: color,
      ),
    );
  }

  String _getStatusText() {
    switch (widget.state) {
      case VoiceInteractionState.idle:
        return '点击或说"记一笔"开始';
      case VoiceInteractionState.listening:
        return '我在听...';
      case VoiceInteractionState.processing:
        return '思考中...';
      case VoiceInteractionState.success:
        return '识别成功';
      case VoiceInteractionState.error:
        return '识别失败，请重试';
    }
  }

  Color _getStateColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.state) {
      case VoiceInteractionState.idle:
        return theme.colorScheme.onSurfaceVariant;
      case VoiceInteractionState.listening:
        return theme.colorScheme.primary;
      case VoiceInteractionState.processing:
        return theme.colorScheme.tertiary;
      case VoiceInteractionState.success:
        return Colors.green;
      case VoiceInteractionState.error:
        return theme.colorScheme.error;
    }
  }
}

/// Voice interaction states
enum VoiceInteractionState {
  idle,       // 待唤醒
  listening,  // 聆听中
  processing, // 处理中
  success,    // 成功
  error,      // 失败
}

/// Audio wave painter for listening state
class AudioWavePainter extends CustomPainter {
  final Color color;
  final double level;
  final double animation;

  AudioWavePainter({
    required this.color,
    required this.level,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 50.0;

    // Draw animated wave circles
    for (int i = 0; i < 3; i++) {
      final waveOffset = (animation + i * 0.33) % 1.0;
      final radius = baseRadius + (level * 20 * waveOffset);
      final opacity = 1.0 - waveOffset;

      paint.color = color.withValues(alpha: 0.5 * opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioWavePainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.animation != animation;
  }
}

/// Offline status indicator widget
class OfflineStatusWidget extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;

  const OfflineStatusWidget({
    super.key,
    required this.isOffline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Text(
            '离线模式',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Icon(
                Icons.refresh,
                size: 18,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error guidance widget
class ErrorGuidanceWidget extends StatelessWidget {
  final String errorType;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onHelp;

  const ErrorGuidanceWidget({
    super.key,
    required this.errorType,
    this.errorMessage,
    this.onRetry,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guidance = _getGuidance();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  guidance.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            guidance.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          if (guidance.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...guidance.suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onHelp != null)
                TextButton(
                  onPressed: onHelp,
                  child: const Text('获取帮助'),
                ),
              if (onRetry != null)
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('重试'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  ErrorGuidance _getGuidance() {
    switch (errorType) {
      case 'network':
        return ErrorGuidance(
          title: '网络连接问题',
          description: '无法连接到服务器，请检查网络设置。',
          suggestions: [
            '检查Wi-Fi或移动数据是否开启',
            '尝试切换网络环境',
            '稍后重试',
          ],
        );
      case 'voice_recognition':
        return ErrorGuidance(
          title: '语音识别失败',
          description: '未能识别您的语音，请重试。',
          suggestions: [
            '确保在安静的环境中录音',
            '靠近麦克风说话',
            '说话清晰、语速适中',
          ],
        );
      case 'permission':
        return ErrorGuidance(
          title: '权限不足',
          description: '应用需要相关权限才能正常工作。',
          suggestions: [
            '前往设置开启所需权限',
          ],
        );
      default:
        return ErrorGuidance(
          title: '发生错误',
          description: errorMessage ?? '请稍后重试。',
          suggestions: [],
        );
    }
  }
}

class ErrorGuidance {
  final String title;
  final String description;
  final List<String> suggestions;

  ErrorGuidance({
    required this.title,
    required this.description,
    required this.suggestions,
  });
}
