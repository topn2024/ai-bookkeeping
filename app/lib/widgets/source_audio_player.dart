import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';

/// Widget for playing original source audio from voice recognition.
///
/// Features:
/// - Play/pause control
/// - Seek bar with progress
/// - Duration display
/// - Shows expiry status
class SourceAudioPlayer extends StatefulWidget {
  final String audioPath;
  final DateTime? expiresAt;
  final int? fileSize;
  final bool compact;

  const SourceAudioPlayer({
    super.key,
    required this.audioPath,
    this.expiresAt,
    this.fileSize,
    this.compact = false,
  });

  @override
  State<SourceAudioPlayer> createState() => _SourceAudioPlayerState();
}

class _SourceAudioPlayerState extends State<SourceAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    try {
      final file = File(widget.audioPath);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = '音频文件不存在';
        });
        return;
      }

      await _audioPlayer.setFilePath(widget.audioPath);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = '无法加载音频: $e';
      });
    }
  }

  bool get _isExpired {
    if (widget.expiresAt == null) return false;
    return DateTime.now().isAfter(widget.expiresAt!);
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpired) {
      return _buildExpiredWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return widget.compact ? _buildCompactPlayer() : _buildFullPlayer();
  }

  Widget _buildCompactPlayer() {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Duration
              StreamBuilder<Duration?>(
                stream: _audioPlayer.durationStream,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.graphic_eq,
                size: 16,
                color: playing ? Theme.of(context).primaryColor : Colors.grey[400],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullPlayer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.mic,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '原始语音录音',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (widget.fileSize != null)
                Text(
                  _formatFileSize(widget.fileSize!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          StreamBuilder<Duration?>(
            stream: _audioPlayer.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: _audioPlayer.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                            0,
                            duration.inMilliseconds.toDouble(),
                          ),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            _audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rewind 5s
              IconButton(
                icon: const Icon(Icons.replay_5),
                onPressed: () {
                  final newPosition = _audioPlayer.position - const Duration(seconds: 5);
                  _audioPlayer.seek(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
              ),
              // Play/Pause button
              StreamBuilder<PlayerState>(
                stream: _audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;

                  if (processingState == ProcessingState.completed) {
                    // Reset to beginning when completed
                    _audioPlayer.seek(Duration.zero);
                    _audioPlayer.pause();
                  }

                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  );
                },
              ),
              // Forward 5s
              IconButton(
                icon: const Icon(Icons.forward_5),
                onPressed: () {
                  final duration = _audioPlayer.duration ?? Duration.zero;
                  final newPosition = _audioPlayer.position + const Duration(seconds: 5);
                  _audioPlayer.seek(
                    newPosition > duration ? duration : newPosition,
                  );
                },
              ),
            ],
          ),
          // Expiry info
          if (widget.expiresAt != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                _getExpiryText(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.expense,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '音频加载失败',
              style: const TextStyle(
                color: AppColors.expense,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.orange,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            '原始录音已过期',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getExpiryText() {
    if (widget.expiresAt == null) return '';
    final remaining = widget.expiresAt!.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}天后过期';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}小时后过期';
    } else {
      return '即将过期';
    }
  }
}

/// Compact audio indicator button for transaction list items
class SourceAudioButton extends StatelessWidget {
  final String audioPath;
  final DateTime? expiresAt;
  final int? fileSize;
  final VoidCallback? onTap;

  const SourceAudioButton({
    super.key,
    required this.audioPath,
    this.expiresAt,
    this.fileSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(audioPath);
    final fileExists = file.existsSync();
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt!);

    return GestureDetector(
      onTap: fileExists && !isExpired ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isExpired
              ? Colors.grey[200]
              : Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Icon(
            isExpired
                ? Icons.mic_off
                : (fileExists ? Icons.mic : Icons.mic_none),
            color: isExpired
                ? Colors.grey[400]
                : (fileExists
                    ? Theme.of(context).primaryColor
                    : Colors.grey[400]),
            size: 24,
          ),
        ),
      ),
    );
  }
}
