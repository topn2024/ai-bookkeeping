import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../widgets/duplicate_transaction_dialog.dart';

/// 语音记账页面
/// 使用千问音频模型直接识别语音内容并提取记账信息
class VoiceRecognitionPage extends ConsumerStatefulWidget {
  const VoiceRecognitionPage({super.key});

  @override
  ConsumerState<VoiceRecognitionPage> createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends ConsumerState<VoiceRecognitionPage>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasPermission = false;
  String? _recordingPath;
  AIRecognitionResult? _recognitionResult;
  bool _isProcessing = false;
  late AnimationController _animationController;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioRecorder.dispose();
    ref.read(aiBookkeepingProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      _hasPermission = await _audioRecorder.hasPermission();
      setState(() {});
    } catch (e) {
      _showError('检查麦克风权限失败: $e');
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      _showError('请授予麦克风权限');
      return;
    }

    try {
      // 获取临时目录
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/recording_$timestamp.m4a';

      // 配置录音参数
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: _recordingPath!);

      setState(() {
        _isRecording = true;
        _recognitionResult = null;
        _recordingStartTime = DateTime.now();
      });

      // 更新录音时长
      _updateRecordingDuration();
    } catch (e) {
      _showError('开始录音失败: $e');
    }
  }

  void _updateRecordingDuration() {
    if (!_isRecording) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isRecording && _recordingStartTime != null) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
        _updateRecordingDuration();
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null && path.isNotEmpty) {
        await _processAudio(path);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      _showError('停止录音失败: $e');
    }
  }

  Future<void> _processAudio(String audioPath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 读取音频文件
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('录音文件不存在');
      }

      final audioData = await file.readAsBytes();

      // 使用AI服务识别音频
      final aiService = AIService();
      final result = await aiService.recognizeAudio(audioData, format: 'm4a');

      setState(() {
        _recognitionResult = result;
        _isProcessing = false;
      });

      if (!result.success) {
        _showError(result.errorMessage ?? '识别失败');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('处理音频失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  /// 解析日期字符串
  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == '今天') {
      return DateTime.now();
    }

    try {
      // 尝试多种日期格式
      final patterns = [
        RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),  // 2024-12-30
        RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})'),  // 2024/12/30
        RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日'), // 2024年12月30日
        RegExp(r'(\d{1,2})-(\d{1,2})'),           // 12-30
        RegExp(r'(\d{1,2})/(\d{1,2})'),           // 12/30
        RegExp(r'(\d{1,2})月(\d{1,2})日'),        // 12月30日
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(dateStr);
        if (match != null) {
          final groups = match.groups([1, 2, 3]).whereType<String>().toList();
          if (groups.length >= 3) {
            return DateTime(int.parse(groups[0]), int.parse(groups[1]), int.parse(groups[2]));
          } else if (groups.length == 2) {
            return DateTime(DateTime.now().year, int.parse(groups[0]), int.parse(groups[1]));
          }
        }
      }
    } catch (e) {
      // 解析失败，使用当前日期
    }
    return DateTime.now();
  }

  Future<void> _confirmAndCreateTransaction() async {
    if (_recognitionResult == null || !_recognitionResult!.success) return;

    // 解析识别出的日期
    final transactionDate = _parseDate(_recognitionResult!.date);

    // 创建交易记录
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _recognitionResult!.type == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: _recognitionResult!.amount ?? 0,
      category: _recognitionResult!.category ?? 'other',
      note: _recognitionResult!.description,
      date: transactionDate,
      accountId: 'cash',
    );

    // 使用重复检测保存交易
    final confirmed = await DuplicateTransactionHelper.checkAndConfirm(
      context: context,
      transaction: transaction,
      transactionNotifier: ref.read(transactionProvider.notifier),
    );

    if (!confirmed) return; // 用户取消

    // 返回上一页
    Navigator.pop(context, _recognitionResult);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音记账'),
        actions: [
          if (_recognitionResult != null && _recognitionResult!.success)
            TextButton(
              onPressed: _confirmAndCreateTransaction,
              child: const Text(
                '确认',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 语音输入区域
          Expanded(
            flex: 2,
            child: _buildVoiceInputArea(),
          ),
          // 识别结果区域
          Expanded(
            flex: 1,
            child: _buildRecognitionResult(),
          ),
          // 底部提示
          _buildBottomHint(),
        ],
      ),
    );
  }

  Widget _buildVoiceInputArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 录音按钮
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? AppColors.expense.withValues(alpha: 0.1 + _animationController.value * 0.2)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _isRecording
                          ? AppColors.expense
                          : Theme.of(context).primaryColor,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 48,
                    color: _isRecording
                        ? AppColors.expense
                        : Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // 状态文本和录音时长
          if (_isRecording)
            Column(
              children: [
                Text(
                  '正在录音...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    fontSize: 24,
                    color: AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            )
          else
            Text(
              _hasPermission ? '点击开始录音' : '请授予麦克风权限',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 16),
          // 处理状态
          if (_isProcessing)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('千问音频模型识别中...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecognitionResult() {
    if (_recognitionResult == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '解析结果将在这里显示',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    if (!_recognitionResult!.success) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.expense, size: 32),
              const SizedBox(height: 8),
              Text(
                _recognitionResult!.errorMessage ?? '解析失败',
                style: const TextStyle(color: AppColors.expense),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.income, size: 20),
              const SizedBox(width: 8),
              const Text(
                '解析成功',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.income,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _recognitionResult!.type == 'income'
                      ? AppColors.income.withValues(alpha: 0.1)
                      : AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _recognitionResult!.type == 'income' ? '收入' : '支出',
                  style: TextStyle(
                    fontSize: 12,
                    color: _recognitionResult!.type == 'income'
                        ? AppColors.income
                        : AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultItem('金额', '¥ ${_recognitionResult!.amount?.toStringAsFixed(2) ?? '未识别'}'),
                        _buildResultItem('分类', _getCategoryName(_recognitionResult!.category)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_recognitionResult!.description != null)
                          _buildResultItem('备注', _recognitionResult!.description!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return '其他';

    for (final category in DefaultCategories.expenseCategories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    for (final category in DefaultCategories.incomeCategories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    const categoryNames = {
      'food': '餐饮',
      'transport': '交通',
      'shopping': '购物',
      'entertainment': '娱乐',
      'housing': '住房',
      'medical': '医疗',
      'education': '教育',
      'other': '其他',
      'salary': '工资',
      'bonus': '奖金',
      'parttime': '兼职',
      'investment': '理财',
      '餐饮': '餐饮',
      '交通': '交通',
      '购物': '购物',
      '娱乐': '娱乐',
      '住房': '住房',
      '医疗': '医疗',
      '教育': '教育',
      '其他': '其他',
      '工资': '工资',
      '奖金': '奖金',
      '兼职': '兼职',
      '理财': '理财',
    };

    return categoryNames[categoryId] ?? categoryId;
  }

  Widget _buildBottomHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '语音示例',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildExampleChip('午餐花了35块'),
              _buildExampleChip('打车去公司20元'),
              _buildExampleChip('超市买菜168'),
              _buildExampleChip('收到工资8000'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '使用千问音频模型直接识别语音',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '"$text"',
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
        ),
      ),
    );
  }
}
