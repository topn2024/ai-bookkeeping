import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../models/category.dart';

/// 语音记账页面
class VoiceRecognitionPage extends ConsumerStatefulWidget {
  const VoiceRecognitionPage({super.key});

  @override
  ConsumerState<VoiceRecognitionPage> createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends ConsumerState<VoiceRecognitionPage>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _transcribedText = '';
  AIRecognitionResult? _recognitionResult;
  bool _isProcessing = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    ref.read(aiBookkeepingProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            if (_transcribedText.isNotEmpty) {
              _parseVoiceInput();
            }
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
          });
          _showError('语音识别错误: ${error.errorMsg}');
        },
      );
      setState(() {});
    } catch (e) {
      _showError('语音初始化失败: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _showError('语音识别不可用');
      return;
    }

    setState(() {
      _isListening = true;
      _transcribedText = '';
      _recognitionResult = null;
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'zh_CN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });

    if (_transcribedText.isNotEmpty) {
      _parseVoiceInput();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _transcribedText = result.recognizedWords;
    });
  }

  Future<void> _parseVoiceInput() async {
    if (_transcribedText.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ref
          .read(aiBookkeepingProvider.notifier)
          .recognizeVoice(_transcribedText);

      setState(() {
        _recognitionResult = result;
        _isProcessing = false;
      });

      if (!result.success) {
        _showError(result.errorMessage ?? '解析失败');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('解析失败: $e');
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

  void _confirmAndCreateTransaction() {
    if (_recognitionResult == null || !_recognitionResult!.success) return;
    Navigator.pop(context, _recognitionResult);
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
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 语音按钮
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? AppColors.expense.withOpacity(0.1 + _animationController.value * 0.2)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    border: Border.all(
                      color: _isListening
                          ? AppColors.expense
                          : Theme.of(context).primaryColor,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: _isListening
                        ? AppColors.expense
                        : Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // 状态文本
          Text(
            _isListening
                ? '正在聆听...'
                : (_speechEnabled ? '点击开始语音输入' : '语音识别不可用'),
            style: TextStyle(
              fontSize: 16,
              color: _isListening ? AppColors.expense : Colors.grey[600],
              fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          // 转录文本
          if (_transcribedText.isNotEmpty || _isListening)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (_isProcessing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('AI 解析中...'),
                      ],
                    )
                  else
                    Text(
                      _transcribedText.isEmpty ? '...' : _transcribedText,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
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
            color: Colors.grey.withOpacity(0.1),
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
                      ? AppColors.income.withOpacity(0.1)
                      : AppColors.expense.withOpacity(0.1),
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
