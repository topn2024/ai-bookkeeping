import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';
import '../services/source_file_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../widgets/duplicate_transaction_dialog.dart';
import '../services/category_localization_service.dart';

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
  final SourceFileService _sourceFileService = SourceFileService();
  bool _isRecording = false;
  bool _hasPermission = false;
  String? _recordingPath;
  AIRecognitionResult? _recognitionResult;
  bool _isProcessing = false;
  late AnimationController _animationController;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartTime;
  DateTime? _recognitionTimestamp;
  // 缓存 ScaffoldMessenger 用于安全清除 SnackBar
  ScaffoldMessengerState? _scaffoldMessenger;

  // 可编辑字段的控制器
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = 'other';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // 清除 SnackBar，避免返回首页后继续显示
    _scaffoldMessenger?.clearSnackBars();
    _animationController.dispose();
    _audioRecorder.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    ref.read(aiBookkeepingProvider.notifier).reset();
    super.dispose();
  }

  /// 将识别结果填充到编辑字段
  void _populateFieldsFromResult(AIRecognitionResult result) {
    _amountController.text = result.amount?.toStringAsFixed(2) ?? '';
    _descriptionController.text = result.description ?? '';
    _selectedType = result.type ?? 'expense';

    // 确保分类在有效列表中
    final category = result.category ?? 'other';
    final validCategories = _selectedType == 'income'
        ? ['salary', 'bonus', 'parttime', 'investment', 'other']
        : ['food', 'transport', 'shopping', 'entertainment', 'housing', 'medical', 'education', 'other'];

    _selectedCategory = validCategories.contains(category) ? category : 'other';
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
      _recordingPath = '${directory.path}/recording_$timestamp.wav';

      // 配置录音参数 - 使用 WAV 格式（千问 API 支持）
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,  // 16kHz 适合语音识别
        numChannels: 1,     // 单声道
      );

      await _audioRecorder.start(config, path: _recordingPath!);

      setState(() {
        _isRecording = true;
        // 清空之前的结果
        _recognitionResult = null;
        _amountController.clear();
        _descriptionController.clear();
        _selectedType = 'expense';
        _selectedCategory = 'other';
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
      // Record recognition timestamp
      _recognitionTimestamp = DateTime.now();

      // 读取音频文件
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('录音文件不存在');
      }

      final audioData = await file.readAsBytes();

      // 使用AI服务识别音频
      final aiService = AIService();
      final result = await aiService.recognizeAudio(audioData, format: 'wav');

      setState(() {
        _recognitionResult = result;
        _isProcessing = false;
        if (result.success) {
          _populateFieldsFromResult(result);
        }
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
    // 验证金额
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('请输入有效金额');
      return;
    }

    // Generate transaction ID first
    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Save audio file to permanent local storage
    String? savedAudioPath;
    int? audioFileSize;
    if (_recordingPath != null) {
      final audioFile = File(_recordingPath!);
      if (await audioFile.exists()) {
        savedAudioPath = await _sourceFileService.saveAudioFile(audioFile, transactionId);
        if (savedAudioPath != null) {
          audioFileSize = await _sourceFileService.getFileSize(savedAudioPath);
        }
      }
    }

    // Prepare recognition raw data as JSON (保存原始识别结果和用户修改后的值)
    String? recognitionRawData;
    final rawData = {
      'original': _recognitionResult != null ? {
        'type': _recognitionResult!.type,
        'amount': _recognitionResult!.amount,
        'category': _recognitionResult!.category,
        'description': _recognitionResult!.description,
        'date': _recognitionResult!.date,
        'confidence': _recognitionResult!.confidence,
        'recognized_text': _recognitionResult!.recognizedText,
      } : null,
      'edited': {
        'type': _selectedType,
        'amount': amount,
        'category': _selectedCategory,
        'description': _descriptionController.text,
      },
      'timestamp': _recognitionTimestamp?.toIso8601String(),
    };
    recognitionRawData = jsonEncode(rawData);

    // Calculate expiry date based on user settings
    final expiryDate = await _sourceFileService.calculateExpiryDate();

    // 解析识别出的日期
    final transactionDate = _parseDate(_recognitionResult?.date);

    // 创建交易记录 - 使用用户编辑后的值
    final transaction = Transaction(
      id: transactionId,
      type: _selectedType == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: amount,
      category: _selectedCategory,
      note: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      date: transactionDate,
      accountId: 'cash',
      // Source data fields
      source: TransactionSource.voice,
      aiConfidence: _recognitionResult?.confidence ?? 0.0,
      sourceFileLocalPath: savedAudioPath,
      sourceFileType: 'audio/wav',
      sourceFileSize: audioFileSize,
      recognitionRawData: recognitionRawData,
      sourceFileExpiresAt: expiryDate,
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
            flex: _recognitionResult != null && _recognitionResult!.success ? 1 : 2,
            child: _buildVoiceInputArea(),
          ),
          // 识别结果区域（有结果时给更多空间显示表单）
          Expanded(
            flex: _recognitionResult != null && _recognitionResult!.success ? 2 : 1,
            child: _buildRecognitionResult(),
          ),
          // 底部提示（有识别结果时隐藏）
          if (_recognitionResult == null || !_recognitionResult!.success)
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
                  Text('千问全模态模型识别中...'),
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
                _recognitionResult!.errorMessage ?? '解析失败，请重新录音',
                style: const TextStyle(color: AppColors.expense),
              ),
            ],
          ),
        ),
      );
    }

    // 可编辑的结果表单
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
          // 可编辑表单
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 收入/支出切换
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton('expense', '支出', AppColors.expense),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton('income', '收入', AppColors.income),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 金额输入
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: '金额',
                      prefixText: '¥ ',
                      prefixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _selectedType == 'income' ? AppColors.income : AppColors.expense,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 分类选择
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _getCategoryItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // 备注输入
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                  ),
                ],
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
      onTap: () => setState(() {
        _selectedType = type;
        // 切换类型时，如果当前分类不适用，重置为 other
        final validCategories = type == 'income'
            ? ['salary', 'bonus', 'parttime', 'investment', 'other']
            : ['food', 'transport', 'shopping', 'entertainment', 'housing', 'medical', 'education', 'other'];
        if (!validCategories.contains(_selectedCategory)) {
          _selectedCategory = 'other';
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getCategoryItems() {
    final categories = _selectedType == 'income'
        ? ['salary', 'bonus', 'parttime', 'investment', 'other']
        : ['food', 'transport', 'shopping', 'entertainment', 'housing', 'medical', 'education', 'other'];

    return categories.map((id) {
      return DropdownMenuItem(
        value: id,
        child: Text(_getCategoryName(id)),
      );
    }).toList();
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) {
      return CategoryLocalizationService.instance.getCategoryName('other_expense');
    }

    // 使用本地化服务获取分类名称
    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.localizedName;
    }

    // 如果找不到分类，尝试使用本地化服务直接获取
    return CategoryLocalizationService.instance.getCategoryName(categoryId);
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
            '使用千问全模态模型直接识别语音',
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
