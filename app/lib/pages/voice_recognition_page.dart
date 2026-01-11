import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';
import '../services/source_file_service.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../models/transaction.dart';
import '../widgets/duplicate_transaction_dialog.dart';
import '../services/category_localization_service.dart';
import '../utils/date_utils.dart';
import 'multi_transaction_confirm_page.dart';

/// 语音记账页面 - 单手操作优化设计
/// 使用千问音频模型直接识别语音内容并提取记账信息
class VoiceRecognitionPage extends ConsumerStatefulWidget {
  const VoiceRecognitionPage({super.key});

  @override
  ConsumerState<VoiceRecognitionPage> createState() =>
      _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends ConsumerState<VoiceRecognitionPage>
    with TickerProviderStateMixin {
  // 录音相关
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SourceFileService _sourceFileService = SourceFileService();
  bool _hasPermission = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  DateTime? _recognitionTimestamp;
  Duration _recordingDuration = Duration.zero;

  // 状态: idle, recording, recognizing, result, success
  String _state = 'idle';

  // 识别结果
  AIRecognitionResult? _recognitionResult;

  // 波形动画
  late AnimationController _waveController;
  final List<double> _waveHeights = List.generate(12, (_) => 0.3);

  // 成功动画
  late AnimationController _successController;
  late Animation<double> _successScale;

  // 脉冲动画
  late AnimationController _pulseController;

  // 可编辑字段
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = 'other';
  String _selectedCategoryIcon = '📦';

  // 缓存 ScaffoldMessenger
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _checkPermission();

    // 波形动画控制器 - 使用 repeat 而不是在 listener 中递归调用
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 成功动画控制器
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.elasticOut,
      ),
    );

    // 脉冲动画控制器 - 不在 initState 中启动，等到 idle 状态时才启动
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  // 波形动画更新 - 使用 Timer 而不是递归
  void _startWaveAnimation() {
    _waveController.repeat();
    _waveController.addListener(_onWaveAnimationTick);
  }

  void _stopWaveAnimation() {
    _waveController.removeListener(_onWaveAnimationTick);
    _waveController.stop();
    _waveController.reset();
  }

  void _onWaveAnimationTick() {
    // 只在动画完成一个周期时更新波形高度，减少 setState 频率
    if (_waveController.value >= 0.95 && _state == 'recording') {
      setState(() {
        for (int i = 0; i < _waveHeights.length; i++) {
          _waveHeights[i] = 0.2 + Random().nextDouble() * 0.6;
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    // 停止所有动画并移除 listeners
    _stopWaveAnimation();
    _waveController.dispose();
    _successController.dispose();
    _pulseController.stop();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    ref.read(aiBookkeepingProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        _hasPermission = true;
        setState(() {});
        return;
      }

      if (status.isDenied) {
        // 首次请求，显示说明对话框
        final shouldRequest = await _showPermissionExplanationDialog();
        if (shouldRequest) {
          final result = await Permission.microphone.request();
          _hasPermission = result.isGranted;
          setState(() {});

          if (!result.isGranted) {
            _showPermissionDeniedSnackBar();
          }
        }
        return;
      }

      if (status.isPermanentlyDenied) {
        // 永久拒绝，引导用户去设置
        _hasPermission = false;
        setState(() {});
        _showPermanentlyDeniedDialog();
        return;
      }

      // 其他情况，尝试请求权限
      _hasPermission = await _audioRecorder.hasPermission();
      setState(() {});
    } catch (e) {
      _showError('检查麦克风权限失败: $e');
    }
  }

  /// 显示权限说明对话框
  Future<bool> _showPermissionExplanationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: AppColors.primary),
            SizedBox(width: 8),
            Text('麦克风权限'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('语音记账需要使用麦克风来：'),
            SizedBox(height: 12),
            _PermissionFeatureItem(
              icon: Icons.record_voice_over,
              text: '录制您的语音指令',
            ),
            _PermissionFeatureItem(
              icon: Icons.psychology,
              text: '识别语音内容进行记账',
            ),
            _PermissionFeatureItem(
              icon: Icons.graphic_eq,
              text: '支持唤醒词语音唤醒',
            ),
            SizedBox(height: 12),
            Text(
              '您的录音仅用于本地识别，不会上传到服务器。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不开启'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('允许使用'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示权限被拒绝的提示
  void _showPermissionDeniedSnackBar() {
    if (!mounted) return;
    _scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: const Text('未获得麦克风权限，语音功能无法使用'),
        action: SnackBarAction(
          label: '重试',
          onPressed: _checkPermission,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// 显示永久拒绝权限的对话框
  void _showPermanentlyDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text(
          '您之前拒绝了麦克风权限。要使用语音记账功能，请在系统设置中手动开启麦克风权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  // 开始录音
  Future<void> _startRecording() async {
    if (!_hasPermission) {
      _showError('请授予麦克风权限');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/recording_$timestamp.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _audioRecorder.start(config, path: _recordingPath!);

      setState(() {
        _state = 'recording';
        _recognitionResult = null;
        _amountController.clear();
        _descriptionController.clear();
        _selectedType = 'expense';
        _selectedCategory = 'other';
        _selectedCategoryIcon = '📦';
        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;
      });

      _startWaveAnimation();
      _startDurationTimer();

      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError('开始录音失败: $e');
    }
  }

  // 使用定时器更新录音时长，降低频率到每秒1次
  void _startDurationTimer() {
    _updateRecordingDuration();
  }

  void _updateRecordingDuration() {
    if (_state != 'recording') return;

    // 降低更新频率到每500ms一次，减少 setState 调用
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_state == 'recording' && _recordingStartTime != null && mounted) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
        _updateRecordingDuration();
      }
    });
  }

  // 停止录音
  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _stopWaveAnimation();

      setState(() {
        _state = 'recognizing';
        _recordingPath = path;
      });

      HapticFeedback.mediumImpact();

      if (path != null && path.isNotEmpty) {
        await _processAudio(path);
      }
    } catch (e) {
      setState(() {
        _state = 'idle';
      });
      _showError('停止录音失败: $e');
    }
  }

  Future<void> _processAudio(String audioPath) async {
    try {
      _recognitionTimestamp = DateTime.now();

      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('录音文件不存在');
      }

      final audioData = await file.readAsBytes();
      final aiService = AIService();

      // 使用多笔交易识别
      final multiResult = await aiService.recognizeAudioMulti(audioData, format: 'wav');

      if (!multiResult.success) {
        setState(() {
          _state = 'idle';
        });
        _showError(multiResult.errorMessage ?? '识别失败');
        return;
      }

      // 检查是否识别到多笔交易
      if (multiResult.isMultiple) {
        // 多笔交易 -> 跳转到多笔确认页面
        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MultiTransactionConfirmPage(
                transactions: multiResult.transactions,
                audioFilePath: audioPath,
                recognitionTimestamp: _recognitionTimestamp,
              ),
            ),
          );

          // 如果成功保存，返回上一页
          if (result == true && mounted) {
            Navigator.pop(context);
          } else {
            setState(() {
              _state = 'idle';
            });
          }
        }
      } else {
        // 单笔交易 -> 保持原有流程
        final result = multiResult.first;
        setState(() {
          _recognitionResult = result;
          _state = result != null && result.success ? 'result' : 'idle';
          if (result != null && result.success) {
            _populateFieldsFromResult(result);
          }
        });

        if (result == null || !result.success) {
          _showError(result?.errorMessage ?? '识别失败');
        }
      }
    } catch (e) {
      setState(() {
        _state = 'idle';
      });
      _showError('处理音频失败: $e');
    }
  }

  void _populateFieldsFromResult(AIRecognitionResult result) {
    _amountController.text = result.amount?.toStringAsFixed(2) ?? '';
    _descriptionController.text = result.description ?? '';
    _selectedType = result.type ?? 'expense';

    final category = result.category ?? 'other';
    final validCategories = _selectedType == 'income'
        ? ['salary', 'bonus', 'parttime', 'investment', 'other']
        : [
            'food',
            'transport',
            'shopping',
            'entertainment',
            'housing',
            'medical',
            'education',
            'other'
          ];

    _selectedCategory = validCategories.contains(category) ? category : 'other';
    _selectedCategoryIcon = _getCategoryIcon(_selectedCategory);
  }

  String _getCategoryIcon(String categoryId) {
    const icons = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎬',
      'housing': '🏠',
      'medical': '💊',
      'education': '📚',
      'salary': '💰',
      'bonus': '🎁',
      'parttime': '💼',
      'investment': '📈',
      'other': '📦',
    };
    return icons[categoryId] ?? '📦';
  }

  void _showError(String message) {
    final themeColors = ThemeColors.of(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: themeColors.expense,
      ),
    );
  }

  /// 解析AI识别的日期字符串
  /// 使用集中的日期解析工具类 AppDateUtils.parseRecognizedDate
  DateTime _parseDate(String? dateStr) {
    return AppDateUtils.parseRecognizedDate(dateStr);
  }

  // 确认记账
  Future<void> _confirmTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('请输入有效金额');
      return;
    }

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    String? savedAudioPath;
    int? audioFileSize;
    if (_recordingPath != null) {
      final audioFile = File(_recordingPath!);
      if (await audioFile.exists()) {
        savedAudioPath =
            await _sourceFileService.saveAudioFile(audioFile, transactionId);
        if (savedAudioPath != null) {
          audioFileSize = await _sourceFileService.getFileSize(savedAudioPath);
        }
      }
    }

    String? recognitionRawData;
    final rawData = {
      'original': _recognitionResult != null
          ? {
              'type': _recognitionResult!.type,
              'amount': _recognitionResult!.amount,
              'category': _recognitionResult!.category,
              'description': _recognitionResult!.description,
              'date': _recognitionResult!.date,
              'confidence': _recognitionResult!.confidence,
              'recognized_text': _recognitionResult!.recognizedText,
            }
          : null,
      'edited': {
        'type': _selectedType,
        'amount': amount,
        'category': _selectedCategory,
        'description': _descriptionController.text,
      },
      'timestamp': _recognitionTimestamp?.toIso8601String(),
    };
    recognitionRawData = jsonEncode(rawData);

    final expiryDate = await _sourceFileService.calculateExpiryDate();
    final transactionDate = _parseDate(_recognitionResult?.date);

    final transaction = Transaction(
      id: transactionId,
      type: _selectedType == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: amount,
      category: _selectedCategory,
      note: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      date: transactionDate,
      accountId: 'cash',
      source: TransactionSource.voice,
      aiConfidence: _recognitionResult?.confidence ?? 0.0,
      sourceFileLocalPath: savedAudioPath,
      sourceFileType: 'audio/wav',
      sourceFileSize: audioFileSize,
      recognitionRawData: recognitionRawData,
      sourceFileExpiresAt: expiryDate,
    );

    final confirmed = await DuplicateTransactionHelper.checkAndConfirm(
      context: context,
      transaction: transaction,
      transactionNotifier: ref.read(transactionProvider.notifier),
    );

    if (!confirmed) return;

    // 显示成功状态
    setState(() {
      _state = 'success';
    });
    _successController.forward(from: 0);
    HapticFeedback.heavyImpact();

    // 延迟后返回
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context, _recognitionResult);
      }
    });
  }

  // 继续记账
  void _continueRecording() {
    setState(() {
      _state = 'idle';
      _recognitionResult = null;
    });
  }

  // 打开编辑面板
  void _openEditPanel() {
    final themeColors = ThemeColors.of(ref);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditTransactionPanel(
        amountController: _amountController,
        descriptionController: _descriptionController,
        selectedType: _selectedType,
        selectedCategory: _selectedCategory,
        selectedCategoryIcon: _selectedCategoryIcon,
        themeColors: themeColors,
        onTypeChanged: (type) {
          setState(() {
            _selectedType = type;
            // 重置分类
            _selectedCategory = 'other';
            _selectedCategoryIcon = '📦';
          });
        },
        onCategoryChanged: (category, icon) {
          setState(() {
            _selectedCategory = category;
            _selectedCategoryIcon = icon;
          });
        },
        onSave: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = ThemeColors.of(ref);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 背景渐变色 - 基于主题色
    final primaryColor = themeColors.primary;
    final backgroundGradient = isDark
        ? [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e),
            HSLColor.fromColor(primaryColor)
                .withLightness(0.15)
                .withSaturation(0.5)
                .toColor(),
          ]
        : [
            HSLColor.fromColor(primaryColor)
                .withLightness(0.95)
                .toColor(),
            HSLColor.fromColor(primaryColor)
                .withLightness(0.90)
                .toColor(),
            HSLColor.fromColor(primaryColor)
                .withLightness(0.85)
                .toColor(),
          ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(child: _buildMainContent(themeColors, isDark)),
              if (_state == 'idle') _buildBottomHint(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '语音记账',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () => _showVoiceHistory(isDark),
          ),
        ],
      ),
    );
  }

  /// 显示语音记账历史记录
  void _showVoiceHistory(bool isDark) {
    final transactions = ref.read(transactionProvider).where(
      (t) => t.source == TransactionSource.voice,
    ).toList();

    // 按日期排序，最新的在前
    transactions.sort((a, b) => b.date.compareTo(a.date));

    // 只显示最近20条
    final recentTransactions = transactions.take(20).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '语音记账历史',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${transactions.length} 条',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 列表
              Expanded(
                child: recentTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic_none,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无语音记账记录',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: recentTransactions.length,
                        itemBuilder: (context, index) {
                          final t = recentTransactions[index];
                          final isExpense = t.type == TransactionType.expense;
                          final color = isExpense
                              ? AppColors.expense
                              : AppColors.income;

                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isExpense
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              t.note ?? DefaultCategories.findById(t.category)?.name ?? t.category,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                            trailing: Text(
                              '${isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeColors themeColors, bool isDark) {
    // 管理脉冲动画 - 只在 idle 状态时运行
    if (_state == 'idle' && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (_state != 'idle' && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    switch (_state) {
      case 'idle':
        return _buildIdleState(themeColors, isDark);
      case 'recording':
        return _buildRecordingState(themeColors, isDark);
      case 'recognizing':
        return _buildRecognizingState(themeColors, isDark);
      case 'result':
        return _buildResultState(themeColors, isDark);
      case 'success':
        return _buildSuccessState(themeColors, isDark);
      default:
        return _buildIdleState(themeColors, isDark);
    }
  }

  // ============================================================================
  // 状态1: 准备录音
  // ============================================================================
  Widget _buildIdleState(ThemeColors themeColors, bool isDark) {
    final primaryColor = themeColors.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // 提示文字
        Text(
          _hasPermission ? '点击开始语音记账' : '请授予麦克风权限',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 60),

        // 麦克风按钮
        GestureDetector(
          onTap: _startRecording,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseValue = _pulseController.value;
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      HSLColor.fromColor(primaryColor)
                          .withLightness(
                              HSLColor.fromColor(primaryColor).lightness * 0.7)
                          .toColor(),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 脉冲圈
                    Container(
                      width: 160 * (1 + pulseValue * 0.3),
                      height: 160 * (1 + pulseValue * 0.3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 1 - pulseValue),
                          width: 2,
                        ),
                      ),
                    ),
                    // 麦克风图标
                    const Icon(
                      Icons.mic,
                      size: 56,
                      color: Colors.white,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // ============================================================================
  // 状态2: 录音中
  // ============================================================================
  Widget _buildRecordingState(ThemeColors themeColors, bool isDark) {
    final expenseColor = themeColors.expense;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // 录音时长
        Text(
          _formatDuration(_recordingDuration),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 48,
            fontWeight: FontWeight.w300,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),

        const SizedBox(height: 20),

        // 波形动画
        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 4,
                height: 60 * _waveHeights[index],
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [expenseColor, expenseColor.withValues(alpha: 0.7)],
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 60),

        // 停止按钮
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [expenseColor, expenseColor.withValues(alpha: 0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: expenseColor.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        Text(
          '点击结束录音',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 14,
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // ============================================================================
  // 状态3: 识别中
  // ============================================================================
  Widget _buildRecognizingState(ThemeColors themeColors, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(themeColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '正在识别...',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '千问全模态模型识别中',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 状态4: 识别结果
  // ============================================================================
  Widget _buildResultState(ThemeColors themeColors, bool isDark) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final isExpense = _selectedType == 'expense';
    final amountColor = isExpense ? themeColors.expense : themeColors.income;
    final confidence = _recognitionResult?.confidence ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 结果卡片
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '识别结果',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: themeColors.income.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '置信度 ${(confidence * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: themeColors.income,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 金额显示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isExpense ? '支出金额' : '收入金额',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: isExpense ? '-¥' : '+¥',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: amountColor,
                                ),
                              ),
                              TextSpan(
                                text: amount.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: amountColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 分类行
                  _buildDetailRow(
                    '分类',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: themeColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _selectedCategoryIcon,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getCategoryName(_selectedCategory),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 备注行
                  if (_descriptionController.text.isNotEmpty)
                    _buildDetailRow(
                      '备注',
                      Flexible(
                        child: Text(
                          _descriptionController.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // 日期行
                  _buildDetailRow(
                    '日期',
                    Text(
                      _recognitionResult?.date ?? '今天',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 操作按钮
                  Row(
                    children: [
                      // 编辑按钮
                      Expanded(
                        child: GestureDetector(
                          onTap: _openEditPanel,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                '编辑',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // 确认按钮
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _confirmTransaction,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeColors.primary,
                                  HSLColor.fromColor(themeColors.primary)
                                      .withLightness(HSLColor.fromColor(
                                                  themeColors.primary)
                                              .lightness *
                                          0.8)
                                      .toColor(),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '确认记账',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.check, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 提示文字
          Text(
            '向上滑动可编辑详情',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF5F5F5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
          value,
        ],
      ),
    );
  }

  // ============================================================================
  // 状态5: 记账成功
  // ============================================================================
  Widget _buildSuccessState(ThemeColors themeColors, bool isDark) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final isExpense = _selectedType == 'expense';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // 成功图标
        ScaleTransition(
          scale: _successScale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColors.income,
                  themeColors.income.withValues(alpha: 0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColors.income.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 30),

        Text(
          '记账成功',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          '${_getCategoryName(_selectedCategory)} ${isExpense ? "-" : "+"}¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),

        if (_descriptionController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _descriptionController.text,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 16,
            ),
          ),
        ],

        const Spacer(flex: 2),

        // 继续记账按钮
        GestureDetector(
          onTap: _continueRecording,
          child: Container(
            width: 200,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                '继续记账',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const Spacer(),
      ],
    );
  }

  // ============================================================================
  // 底部语音示例
  // ============================================================================
  Widget _buildBottomHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '语音示例',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildExampleChip('午餐35，咖啡15', isDark),
              _buildExampleChip('打车去公司20元', isDark),
              _buildExampleChip('超市168，水果28', isDark),
              _buildExampleChip('收到工资8000', isDark),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '支持一次说多笔消费，自动识别分类',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '"$text"',
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) {
      return CategoryLocalizationService.instance.getCategoryName('other_expense');
    }

    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.localizedName;
    }

    return CategoryLocalizationService.instance.getCategoryName(categoryId);
  }
}

// ============================================================================
// 编辑面板组件
// ============================================================================
class _EditTransactionPanel extends StatefulWidget {
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final String selectedType;
  final String selectedCategory;
  final String selectedCategoryIcon;
  final ThemeColors themeColors;
  final Function(String) onTypeChanged;
  final Function(String, String) onCategoryChanged;
  final VoidCallback onSave;

  const _EditTransactionPanel({
    required this.amountController,
    required this.descriptionController,
    required this.selectedType,
    required this.selectedCategory,
    required this.selectedCategoryIcon,
    required this.themeColors,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onSave,
  });

  @override
  State<_EditTransactionPanel> createState() => _EditTransactionPanelState();
}

class _EditTransactionPanelState extends State<_EditTransactionPanel> {
  late String _selectedType;
  late String _selectedCategory;

  final List<Map<String, String>> _expenseCategories = [
    {'id': 'food', 'name': '餐饮', 'icon': '🍜'},
    {'id': 'transport', 'name': '交通', 'icon': '🚗'},
    {'id': 'shopping', 'name': '购物', 'icon': '🛒'},
    {'id': 'entertainment', 'name': '娱乐', 'icon': '🎬'},
    {'id': 'housing', 'name': '居住', 'icon': '🏠'},
    {'id': 'medical', 'name': '医疗', 'icon': '💊'},
    {'id': 'education', 'name': '教育', 'icon': '📚'},
    {'id': 'other', 'name': '其他', 'icon': '📦'},
  ];

  final List<Map<String, String>> _incomeCategories = [
    {'id': 'salary', 'name': '工资', 'icon': '💰'},
    {'id': 'bonus', 'name': '奖金', 'icon': '🎁'},
    {'id': 'parttime', 'name': '兼职', 'icon': '💼'},
    {'id': 'investment', 'name': '投资', 'icon': '📈'},
    {'id': 'other', 'name': '其他', 'icon': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedCategory = widget.selectedCategory;
  }

  List<Map<String, String>> get _categories =>
      _selectedType == 'income' ? _incomeCategories : _expenseCategories;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 拖动手柄
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 头部
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '编辑账单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 表单内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收入/支出切换
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'expense',
                          '支出',
                          widget.themeColors.expense,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton(
                          'income',
                          '收入',
                          widget.themeColors.income,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 金额输入
                  const Text(
                    '金额',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: _selectedType == 'expense'
                          ? widget.themeColors.expense
                          : widget.themeColors.income,
                    ),
                    decoration: InputDecoration(
                      prefixText: '¥ ',
                      prefixStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: _selectedType == 'expense'
                            ? widget.themeColors.expense
                            : widget.themeColors.income,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFF0F0F0), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: widget.themeColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 分类选择
                  const Text(
                    '分类',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category['id'] == _selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category['id']!;
                          });
                          widget.onCategoryChanged(
                            category['id']!,
                            category['icon']!,
                          );
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.themeColors.primary.withValues(alpha: 0.15)
                                : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: widget.themeColors.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                category['icon']!,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                category['name']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? widget.themeColors.primary
                                      : const Color(0xFF666666),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 备注输入
                  const Text(
                    '备注',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.descriptionController,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF333333),
                    ),
                    decoration: InputDecoration(
                      hintText: '添加备注...',
                      hintStyle: const TextStyle(
                        color: Color(0xFFBBBBBB),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFF0F0F0), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: widget.themeColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 保存按钮
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: GestureDetector(
              onTap: widget.onSave,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.themeColors.primary,
                      HSLColor.fromColor(widget.themeColors.primary)
                          .withLightness(
                              HSLColor.fromColor(widget.themeColors.primary)
                                      .lightness *
                                  0.8)
                          .toColor(),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          // 切换类型时重置分类
          _selectedCategory = 'other';
        });
        widget.onTypeChanged(type);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : const Color(0xFF666666),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// 权限功能说明项
class _PermissionFeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionFeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
