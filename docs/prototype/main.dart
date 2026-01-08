// 语音记账界面原型 - 独立演示代码
// 使用方式：将此文件复制到任意 Flutter 项目的 lib/main.dart 运行即可预览
//
// 快速运行：
// 1. flutter create voice_demo
// 2. 将本文件内容复制到 voice_demo/lib/main.dart
// 3. flutter run

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VoiceRecordingPrototype());
}

class VoiceRecordingPrototype extends StatelessWidget {
  const VoiceRecordingPrototype({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语音记账原型',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PingFang SC',
      ),
      home: const VoiceRecordingPage(),
    );
  }
}

// ============================================================================
// 主页面 - 语音记账
// ============================================================================
class VoiceRecordingPage extends StatefulWidget {
  const VoiceRecordingPage({super.key});

  @override
  State<VoiceRecordingPage> createState() => _VoiceRecordingPageState();
}

class _VoiceRecordingPageState extends State<VoiceRecordingPage>
    with TickerProviderStateMixin {
  // 状态: idle, recording, recognizing, result, success
  String _state = 'idle';

  // 录音时长
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // 模拟识别结果
  final Map<String, dynamic> _recognitionResult = {
    'amount': 28.50,
    'type': 'expense',
    'category': '餐饮',
    'categoryIcon': '🍜',
    'note': '午餐吃了一碗拉面',
    'confidence': 0.95,
    'date': DateTime.now(),
  };

  // 波形动画
  late AnimationController _waveController;
  final List<double> _waveHeights = List.generate(12, (_) => 0.3);

  // 成功动画
  late AnimationController _successController;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(_updateWaveHeights);

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
  }

  void _updateWaveHeights() {
    if (_state == 'recording') {
      setState(() {
        for (int i = 0; i < _waveHeights.length; i++) {
          _waveHeights[i] = 0.2 + Random().nextDouble() * 0.6;
        }
      });
      _waveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _waveController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // 开始录音
  void _startRecording() {
    setState(() {
      _state = 'recording';
      _recordingSeconds = 0;
    });

    _waveController.forward();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });

    // 触觉反馈
    HapticFeedback.mediumImpact();
  }

  // 停止录音
  void _stopRecording() {
    _recordingTimer?.cancel();
    _waveController.stop();

    setState(() {
      _state = 'recognizing';
    });

    HapticFeedback.mediumImpact();

    // 模拟识别过程
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _state = 'result';
        });
      }
    });
  }

  // 确认记账
  void _confirmTransaction() {
    setState(() {
      _state = 'success';
    });
    _successController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  // 继续记账
  void _continueRecording() {
    setState(() {
      _state = 'idle';
    });
  }

  // 打开编辑面板
  void _openEditPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTransactionPanel(
        result: _recognitionResult,
        onSave: (updated) {
          setState(() {
            _recognitionResult.addAll(updated);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(),

              // 主内容区
              Expanded(
                child: _buildMainContent(),
              ),

              // 底部操作栏
              if (_state == 'idle') _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () {},
          ),
          const Expanded(
            child: Text(
              '语音记账',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_state) {
      case 'idle':
        return _buildIdleState();
      case 'recording':
        return _buildRecordingState();
      case 'recognizing':
        return _buildRecognizingState();
      case 'result':
        return _buildResultState();
      case 'success':
        return _buildSuccessState();
      default:
        return _buildIdleState();
    }
  }

  // ============================================================================
  // 状态1: 准备录音
  // ============================================================================
  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // 提示文字
        Text(
          '点击开始语音记账',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 60),

        // 麦克风按钮
        GestureDetector(
          onTap: _startRecording,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 脉冲动画圈
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.3),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Container(
                      width: 160 * value,
                      height: 160 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF667eea)
                              .withOpacity(1.3 - value + 0.1),
                          width: 2,
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    if (mounted && _state == 'idle') {
                      setState(() {});
                    }
                  },
                ),
                // 麦克风图标
                const Icon(
                  Icons.mic,
                  size: 56,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // ============================================================================
  // 状态2: 录音中
  // ============================================================================
  Widget _buildRecordingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // 录音时长
        Text(
          _formatDuration(_recordingSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w300,
            fontFeatures: [FontFeature.tabularFigures()],
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
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
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // ============================================================================
  // 状态2.5: 识别中
  // ============================================================================
  Widget _buildRecognizingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '正在识别...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 状态3: 识别结果
  // ============================================================================
  Widget _buildResultState() {
    final amount = _recognitionResult['amount'] as double;
    final category = _recognitionResult['category'] as String;
    final categoryIcon = _recognitionResult['categoryIcon'] as String;
    final note = _recognitionResult['note'] as String;
    final confidence = _recognitionResult['confidence'] as double;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 结果卡片
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
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
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '置信度 ${(confidence * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 金额显示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '支出金额',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '-¥',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF6B6B),
                                ),
                              ),
                              TextSpan(
                                text: amount.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF6B6B),
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
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              categoryIcon,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category,
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
                  _buildDetailRow(
                    '备注',
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),

                  // 日期行
                  _buildDetailRow(
                    '日期',
                    const Text(
                      '今天 12:30',
                      style: TextStyle(
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
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF667eea).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.5),
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
  // 状态4: 记账成功
  // ============================================================================
  Widget _buildSuccessState() {
    final amount = _recognitionResult['amount'] as double;
    final category = _recognitionResult['category'] as String;
    final note = _recognitionResult['note'] as String;

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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
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

        const Text(
          '记账成功',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          '$category -¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          note,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),

        const Spacer(flex: 2),

        // 继续记账按钮
        GestureDetector(
          onTap: _continueRecording,
          child: Container(
            width: 200,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: Text(
                '继续记账',
                style: TextStyle(
                  color: Colors.white,
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
  // 底部操作栏
  // ============================================================================
  Widget _buildBottomBar() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomButton(Icons.keyboard, '键盘'),
          _buildBottomButton(Icons.camera_alt, '拍照'),
          _buildBottomButton(Icons.receipt_long, '记录'),
        ],
      ),
    );
  }

  Widget _buildBottomButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// 编辑面板组件
// ============================================================================
class EditTransactionPanel extends StatefulWidget {
  final Map<String, dynamic> result;
  final Function(Map<String, dynamic>) onSave;

  const EditTransactionPanel({
    super.key,
    required this.result,
    required this.onSave,
  });

  @override
  State<EditTransactionPanel> createState() => _EditTransactionPanelState();
}

class _EditTransactionPanelState extends State<EditTransactionPanel> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedCategory;
  late String _selectedCategoryIcon;

  final List<Map<String, String>> _categories = [
    {'name': '餐饮', 'icon': '🍜'},
    {'name': '交通', 'icon': '🚗'},
    {'name': '购物', 'icon': '🛒'},
    {'name': '娱乐', 'icon': '🎬'},
    {'name': '居住', 'icon': '🏠'},
    {'name': '医疗', 'icon': '💊'},
    {'name': '教育', 'icon': '📚'},
    {'name': '其他', 'icon': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.result['amount'] as double).toStringAsFixed(2),
    );
    _noteController = TextEditingController(
      text: widget.result['note'] as String,
    );
    _selectedCategory = widget.result['category'] as String;
    _selectedCategoryIcon = widget.result['categoryIcon'] as String;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B6B),
                    ),
                    decoration: InputDecoration(
                      prefixText: '¥ ',
                      prefixStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B6B),
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
                        borderSide:
                            const BorderSide(color: Color(0xFF667eea), width: 2),
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
                      final isSelected = category['name'] == _selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category['name']!;
                            _selectedCategoryIcon = category['icon']!;
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEDE7F6)
                                : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF667eea), width: 2)
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
                                      ? const Color(0xFF667eea)
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
                    controller: _noteController,
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
                        borderSide:
                            const BorderSide(color: Color(0xFF667eea), width: 2),
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
              onTap: () {
                widget.onSave({
                  'amount': double.tryParse(_amountController.text) ?? 0,
                  'category': _selectedCategory,
                  'categoryIcon': _selectedCategoryIcon,
                  'note': _noteController.text,
                });
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.3),
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
}
