import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_context_service.dart';

/// 麦克风权限状态
enum MicrophonePermissionStatus {
  granted,           // 已授权
  denied,            // 被拒绝（可再次请求）
  permanentlyDenied, // 永久拒绝（需要去设置）
  unknown,           // 未知状态
}

/// 悬浮球状态
enum FloatingBallState {
  idle,       // 默认状态，显示麦克风图标
  recording,  // 录音中，显示波浪动画
  processing, // 处理中，显示加载动画
  success,    // 成功，短暂显示勾号
  error,      // 错误，短暂显示错误图标
  hidden,     // 隐藏状态
}

/// 聊天消息类型
enum ChatMessageType {
  user,
  assistant,
  system,
}

/// 聊天消息
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.metadata,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      type: type,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    type: ChatMessageType.values.firstWhere((e) => e.name == json['type']),
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    metadata: json['metadata'],
  );
}

/// 命令处理回调类型
/// 返回处理结果消息，如果返回null则使用内置处理
typedef CommandProcessorCallback = Future<String?> Function(String command);

/// 全局语音助手管理器
///
/// 单例模式，管理：
/// - 悬浮球状态
/// - 语音交互流程
/// - 对话历史
/// - 页面上下文
class GlobalVoiceAssistantManager extends ChangeNotifier {
  // 单例模式
  static GlobalVoiceAssistantManager? _instance;
  static GlobalVoiceAssistantManager get instance {
    _instance ??= GlobalVoiceAssistantManager._internal();
    return _instance!;
  }

  GlobalVoiceAssistantManager._internal();

  /// 用于测试的工厂方法
  @visibleForTesting
  factory GlobalVoiceAssistantManager.forTest() {
    return GlobalVoiceAssistantManager._internal();
  }

  // 核心服务（延迟初始化）
  VoiceRecognitionEngine? _recognitionEngine;
  TTSService? _ttsService;
  VoiceContextService? _contextService;

  // 录音器
  AudioRecorder? _audioRecorder;

  // 状态
  FloatingBallState _ballState = FloatingBallState.idle;
  bool _isVisible = true;
  Offset _position = Offset.zero;
  bool _isInitialized = false;

  // 对话历史
  final List<ChatMessage> _conversationHistory = [];
  static const int _maxHistorySize = 100;

  // 录音相关
  DateTime? _recordingStartTime;
  String? _recordingPath;

  // 音频振幅 (0.0 - 1.0)
  double _amplitude = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // 连续对话模式
  bool _continuousMode = false;
  bool _shouldAutoRestart = false;

  // 权限回调（由 UI 层设置）
  void Function(MicrophonePermissionStatus status)? onPermissionRequired;

  // 命令处理回调（由 UI 层设置，用于集成 VoiceServiceCoordinator）
  CommandProcessorCallback? _commandProcessor;

  /// 设置命令处理回调
  void setCommandProcessor(CommandProcessorCallback? processor) {
    _commandProcessor = processor;
    debugPrint('[GlobalVoiceAssistant] 命令处理器已${processor != null ? "设置" : "清除"}');
  }

  // Getters
  FloatingBallState get ballState => _ballState;
  bool get isVisible => _isVisible;
  Offset get position => _position;
  bool get isInitialized => _isInitialized;
  double get amplitude => _amplitude;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  VoiceContextService? get contextService => _contextService;
  bool get isContinuousMode => _continuousMode;

  /// 启用/禁用连续对话模式
  void setContinuousMode(bool enabled) {
    _continuousMode = enabled;
    _shouldAutoRestart = enabled;
    debugPrint('[GlobalVoiceAssistant] 连续对话模式: $enabled');
    notifyListeners();
  }

  /// 停止连续对话
  void stopContinuousMode() {
    _continuousMode = false;
    _shouldAutoRestart = false;
    if (_ballState == FloatingBallState.recording) {
      stopRecording();
    }
    setBallState(FloatingBallState.idle);
    debugPrint('[GlobalVoiceAssistant] 连续对话已停止');
  }

  /// 检查麦克风权限状态
  Future<MicrophonePermissionStatus> checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
        return MicrophonePermissionStatus.granted;
      } else if (status.isPermanentlyDenied) {
        return MicrophonePermissionStatus.permanentlyDenied;
      } else if (status.isDenied) {
        return MicrophonePermissionStatus.denied;
      }
      return MicrophonePermissionStatus.unknown;
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 检查权限失败: $e');
      return MicrophonePermissionStatus.unknown;
    }
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    try {
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 请求权限失败: $e');
      return false;
    }
  }

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化上下文服务
      _contextService = VoiceContextService();

      // 延迟初始化语音服务，首次使用时才创建
      _isInitialized = true;

      // 从本地存储加载对话历史
      await loadHistoryFromStorage();

      // 如果没有历史记录，添加欢迎消息
      if (_conversationHistory.isEmpty) {
        _addSystemMessage('语音助手已就绪，点击悬浮球开始对话');
      }

      notifyListeners();
      debugPrint('[GlobalVoiceAssistant] 初始化完成');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 初始化失败: $e');
      rethrow;
    }
  }

  /// 确保语音服务已初始化
  Future<void> _ensureVoiceServicesInitialized() async {
    if (_audioRecorder != null) return;

    _audioRecorder = AudioRecorder();
    _recognitionEngine = VoiceRecognitionEngine();
    _ttsService = TTSService();
    await _ttsService!.initialize();

    debugPrint('[GlobalVoiceAssistant] 语音服务延迟初始化完成');
  }

  /// 设置悬浮球状态
  void setBallState(FloatingBallState state) {
    if (_ballState != state) {
      _ballState = state;
      notifyListeners();
    }
  }

  /// 设置悬浮球可见性
  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  /// 设置悬浮球位置
  void setPosition(Offset newPosition) {
    if (_position != newPosition) {
      _position = newPosition;
      notifyListeners();
    }
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (_ballState == FloatingBallState.recording) return;

    try {
      // 先检查权限状态
      final permissionStatus = await checkMicrophonePermission();

      if (permissionStatus == MicrophonePermissionStatus.permanentlyDenied) {
        // 永久拒绝，通知 UI 层显示引导对话框
        onPermissionRequired?.call(permissionStatus);
        _handleError('麦克风权限被禁用，请在设置中开启');
        return;
      }

      if (permissionStatus == MicrophonePermissionStatus.denied) {
        // 首次请求或被拒绝，通知 UI 层显示权限说明
        onPermissionRequired?.call(permissionStatus);
        // 尝试请求权限
        final granted = await requestMicrophonePermission();
        if (!granted) {
          _handleError('未获得麦克风权限');
          return;
        }
      }

      await _ensureVoiceServicesInitialized();

      // 再次确认权限（通过 AudioRecorder 检查）
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        _handleError('麦克风权限不可用');
        return;
      }

      // 振动反馈
      HapticFeedback.mediumImpact();

      // 生成录音路径
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/voice_assistant_$timestamp.wav';

      // 录音配置
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      );

      // 开始录音
      await _audioRecorder!.start(config, path: _recordingPath!);

      // 订阅振幅变化
      _amplitudeSubscription = _audioRecorder!
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        // 将 dB 值转换为 0-1 的振幅
        // amp.current 通常在 -60 到 0 之间，0 表示最大音量
        // 转换公式：将 -60~0 映射到 0~1
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        _amplitude = normalized;
        notifyListeners();
      });

      _recordingStartTime = DateTime.now();
      setBallState(FloatingBallState.recording);

      debugPrint('[GlobalVoiceAssistant] 开始录音: $_recordingPath');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 开始录音失败: $e');
      _handleError('无法开始录音，请检查麦克风权限');
    }
  }

  /// 停止录音并处理
  Future<void> stopRecording() async {
    debugPrint('[GlobalVoiceAssistant] stopRecording called, state=$_ballState');
    if (_ballState != FloatingBallState.recording) {
      debugPrint('[GlobalVoiceAssistant] 状态不是recording，忽略');
      return;
    }

    try {
      // 停止振幅订阅
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      _amplitude = 0.0;

      // 检查录音时长
      final duration = DateTime.now().difference(_recordingStartTime!);
      debugPrint('[GlobalVoiceAssistant] 录音时长: ${duration.inMilliseconds}ms');
      if (duration.inMilliseconds < 500) {
        await _audioRecorder!.stop();
        setBallState(FloatingBallState.idle);
        _showToast('录音时间太短，请说话后再松开');
        return;
      }

      setBallState(FloatingBallState.processing);

      // 停止录音
      debugPrint('[GlobalVoiceAssistant] 正在停止录音...');
      final path = await _audioRecorder!.stop();
      debugPrint('[GlobalVoiceAssistant] 录音已停止, path=$path');

      if (path == null || path.isEmpty) {
        _handleError('录音失败');
        return;
      }

      // 处理音频
      await _processAudio(path);
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 停止录音失败: $e');
      _handleError('处理录音失败');
    }
  }

  /// 处理音频
  Future<void> _processAudio(String audioPath) async {
    debugPrint('[GlobalVoiceAssistant] _processAudio: $audioPath');
    try {
      // 获取当前页面上下文
      final context = _contextService?.currentContext;
      debugPrint('[GlobalVoiceAssistant] 当前上下文: $context');

      // 语音识别
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        debugPrint('[GlobalVoiceAssistant] 录音文件不存在!');
        _handleError('录音文件不存在');
        return;
      }
      debugPrint('[GlobalVoiceAssistant] 开始语音识别...');

      final result = await _recognitionEngine!.recognizeFromFile(audioFile);
      debugPrint('[GlobalVoiceAssistant] 识别结果: ${result.text}, error: ${result.error}');
      final recognizedText = result.text;

      if (recognizedText.isEmpty) {
        // 检查是否有具体的错误信息
        if (result.error != null && result.error!.isNotEmpty) {
          final errorStr = result.error!.toLowerCase();
          if (errorStr.contains('token') || errorStr.contains('认证')) {
            _handleError('语音服务暂不可用，请稍后重试');
          } else if (errorStr.contains('network') || errorStr.contains('网络')) {
            _handleError('网络连接失败，请检查网络');
          } else {
            _handleError('未能识别语音内容');
          }
        } else {
          _handleError('未能识别语音内容，请靠近麦克风说话');
        }
        return;
      }

      // 添加用户消息
      _addUserMessage(recognizedText);

      // 获取即时反馈（不等待后台处理完成）
      final immediateResponse = _getImmediateResponse(recognizedText);

      // 添加即时反馈消息
      _addAssistantMessage(immediateResponse);

      // 显示处理中状态
      setBallState(FloatingBallState.processing);

      // 播放即时反馈
      if (_ttsService != null) {
        try {
          // 不等待TTS完成，异步播放
          _ttsService!.speak(immediateResponse);
        } catch (ttsError) {
          debugPrint('[GlobalVoiceAssistant] TTS播报失败（已忽略）: $ttsError');
        }
      }

      // 异步后台处理命令（不阻塞UI）
      _processCommandAsync(recognizedText, context);

      // 清理临时文件
      try {
        await audioFile.delete();
      } catch (_) {}
    } on SocketException catch (e) {
      debugPrint('[GlobalVoiceAssistant] 网络错误: $e');
      _handleError('网络连接失败，请检查网络后重试');
    } on TimeoutException catch (e) {
      debugPrint('[GlobalVoiceAssistant] 请求超时: $e');
      _handleError('请求超时，请检查网络后重试');
    } on HttpException catch (e) {
      debugPrint('[GlobalVoiceAssistant] HTTP错误: $e');
      _handleError('服务器连接失败，请稍后重试');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 处理音频失败: $e');
      // 检查错误信息是否包含网络相关关键词
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('timeout')) {
        _handleError('网络连接失败，请检查网络设置');
      } else {
        _handleError('处理失败，请重试');
      }
    }
  }

  /// 获取即时反馈（根据输入内容快速生成）
  String _getImmediateResponse(String text) {
    // 确认/取消指令 - 立即响应
    if (text.contains('确认') || text.contains('是的') || text.contains('好的')) {
      return '好的，正在处理~';
    }
    if (text.contains('取消') || text.contains('算了') || text.contains('不要')) {
      return '好的，已取消';
    }

    // 导航指令
    final navKeywords = ['打开', '进入', '查看', '看看', '去'];
    if (navKeywords.any((k) => text.contains(k))) {
      return '好的，马上~';
    }

    // 记账指令（包含金额）
    final hasAmount = RegExp(r'\d+|[一二三四五六七八九十百千万两]+').hasMatch(text);
    if (hasAmount) {
      // 多笔交易
      final amountCount = RegExp(r'\d+(?:\.\d+)?').allMatches(text).length;
      if (amountCount > 1) {
        return '好的，我来帮你记录这几笔~';
      }
      return '好的，我来记一下~';
    }

    // 查询指令
    if (text.contains('多少') || text.contains('查') || text.contains('统计')) {
      return '好的，我帮你看看~';
    }

    // 默认
    return '好的，收到~';
  }

  /// 异步处理命令（不阻塞UI）
  Future<void> _processCommandAsync(String text, PageContext? context) async {
    debugPrint('[GlobalVoiceAssistant] 开始异步处理: $text');

    try {
      // 调用命令处理器（后台执行）
      final response = await _processIntent(text, context);

      // 处理完成后，添加结果反馈到聊天记录
      if (response.message.isNotEmpty) {
        // 如果结果和即时反馈不同，添加结果消息
        final immediateResponse = _getImmediateResponse(text);
        if (response.message != immediateResponse) {
          _addAssistantMessage(response.message, metadata: response.metadata);
        }

        // 播放结果TTS
        if (_ttsService != null && response.shouldSpeak) {
          try {
            await _ttsService!.speak(response.message);
          } catch (ttsError) {
            debugPrint('[GlobalVoiceAssistant] 结果TTS播报失败: $ttsError');
          }
        }
      }

      // 显示成功状态
      setBallState(FloatingBallState.success);

      debugPrint('[GlobalVoiceAssistant] 异步处理完成, 连续模式=$_continuousMode');

      // 检查是否需要自动重新开始录音（连续对话模式）
      if (_continuousMode && _shouldAutoRestart) {
        // 短暂延迟后自动开始下一轮录音
        Future.delayed(const Duration(milliseconds: 800), () {
          debugPrint('[GlobalVoiceAssistant] 检查自动重启: 连续模式=$_continuousMode, 自动重启=$_shouldAutoRestart, 状态=$_ballState');
          if (_continuousMode && _shouldAutoRestart) {
            // 只要连续模式开启就自动重启，不严格检查状态
            if (_ballState != FloatingBallState.recording) {
              debugPrint('[GlobalVoiceAssistant] 连续对话: 自动开始下一轮录音');
              startRecording();
            }
          }
        });
      } else {
        // 2秒后恢复空闲状态，准备接收下一条指令
        Future.delayed(const Duration(seconds: 2), () {
          if (_ballState == FloatingBallState.success) {
            setBallState(FloatingBallState.idle);
          }
        });
      }
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 异步处理失败: $e');
      // 添加错误消息
      _addAssistantMessage('处理时遇到问题，请再试一次');

      // 连续模式下也尝试继续
      if (_continuousMode && _shouldAutoRestart) {
        Future.delayed(const Duration(seconds: 1), () {
          if (_continuousMode && _shouldAutoRestart) {
            startRecording();
          }
        });
      } else {
        setBallState(FloatingBallState.idle);
      }
    }

    notifyListeners();
  }

  /// 处理意图
  Future<_IntentResponse> _processIntent(String text, PageContext? context) async {
    // 获取上下文提示，用于增强理解
    final contextHint = _contextService?.getContextHint() ?? '';
    debugPrint('[GlobalVoiceAssistant] 上下文提示: $contextHint');

    // 如果设置了命令处理器，优先使用它（集成 VoiceServiceCoordinator）
    if (_commandProcessor != null) {
      debugPrint('[GlobalVoiceAssistant] 使用外部命令处理器处理: $text');
      try {
        final result = await _commandProcessor!(text);
        if (result != null && result.isNotEmpty) {
          return _IntentResponse(
            message: result,
            shouldSpeak: true,
          );
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 外部命令处理器出错: $e');
        // 出错时继续使用内置处理
      }
    }

    // 根据页面上下文增强处理
    if (context != null) {
      final contextResponse = _handleContextAwareQuery(text, context);
      if (contextResponse != null) {
        return contextResponse;
      }
    }

    // 处理记账意图
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元)?').firstMatch(text);

    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(1)!) ?? 0;
      String category = _inferCategory(text);

      return _IntentResponse(
        message: '已记录 ¥${amount.toStringAsFixed(2)} - $category',
        metadata: {'amount': amount, 'category': category, 'type': 'expense'},
        shouldSpeak: true,
      );
    }

    // 处理查询意图
    if (text.contains('花了多少') || text.contains('支出') || text.contains('今天')) {
      return _IntentResponse(
        message: '今日支出统计功能开发中...',
        shouldSpeak: true,
      );
    }

    // 处理导航意图
    final navigationResponse = _handleNavigationIntent(text);
    if (navigationResponse != null) {
      return navigationResponse;
    }

    return _IntentResponse(
      message: '抱歉，我没有理解您的意思。试试说"午餐35块"或"还剩多少预算"',
      shouldSpeak: true,
    );
  }

  /// 推断分类
  String _inferCategory(String text) {
    if (text.contains('餐') || text.contains('饭') || text.contains('吃') ||
        text.contains('外卖') || text.contains('美团') || text.contains('饿了么')) {
      return '餐饮';
    } else if (text.contains('车') || text.contains('打车') || text.contains('地铁') ||
        text.contains('公交') || text.contains('滴滴') || text.contains('油费')) {
      return '交通';
    } else if (text.contains('买') || text.contains('购') || text.contains('淘宝') ||
        text.contains('京东') || text.contains('拼多多')) {
      return '购物';
    } else if (text.contains('电影') || text.contains('游戏') || text.contains('娱乐')) {
      return '娱乐';
    } else if (text.contains('医') || text.contains('药') || text.contains('病')) {
      return '医疗';
    } else if (text.contains('水') || text.contains('电') || text.contains('燃气') ||
        text.contains('话费') || text.contains('网费')) {
      return '生活缴费';
    }
    return '其他';
  }

  /// 处理上下文感知查询
  _IntentResponse? _handleContextAwareQuery(String text, PageContext context) {
    switch (context.type) {
      case PageContextType.budget:
        // 在预算页面询问预算相关
        if (text.contains('还剩') || text.contains('余额') || text.contains('多少')) {
          final remaining = context.data?['remaining'];
          final category = context.data?['category'] ?? '总预算';
          if (remaining != null) {
            return _IntentResponse(
              message: '$category还剩 ¥$remaining',
              shouldSpeak: true,
            );
          }
          return _IntentResponse(
            message: '让我查一下$category的余额...',
            shouldSpeak: true,
          );
        }
        break;

      case PageContextType.transactionDetail:
        // 在交易详情页修改交易
        if (text.contains('改') || text.contains('修改')) {
          final txId = context.data?['transactionId'];
          final amountMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
          if (amountMatch != null && txId != null) {
            final newAmount = double.tryParse(amountMatch.group(1)!) ?? 0;
            return _IntentResponse(
              message: '已将金额修改为 ¥${newAmount.toStringAsFixed(2)}',
              metadata: {'transactionId': txId, 'newAmount': newAmount, 'action': 'modify'},
              shouldSpeak: true,
            );
          }
        }
        // 删除交易
        if (text.contains('删') || text.contains('删除')) {
          final txId = context.data?['transactionId'];
          if (txId != null) {
            return _IntentResponse(
              message: '确定要删除这笔交易吗？',
              metadata: {'transactionId': txId, 'action': 'delete', 'needConfirm': true},
              shouldSpeak: true,
            );
          }
        }
        break;

      case PageContextType.report:
        // 在报表页查询统计
        if (text.contains('多少') || text.contains('统计') || text.contains('总共')) {
          final dateRange = context.data?['dateRange'] ?? '本月';
          return _IntentResponse(
            message: '$dateRange统计数据加载中...',
            shouldSpeak: true,
          );
        }
        break;

      case PageContextType.savings:
        // 在储蓄页查询进度
        if (text.contains('进度') || text.contains('多少') || text.contains('还差')) {
          final goalName = context.data?['goalName'] ?? '储蓄目标';
          final progress = context.data?['progress'];
          if (progress != null) {
            return _IntentResponse(
              message: '$goalName已完成 $progress%',
              shouldSpeak: true,
            );
          }
        }
        break;

      default:
        break;
    }
    return null;
  }

  /// 处理导航意图
  _IntentResponse? _handleNavigationIntent(String text) {
    final navigationKeywords = {
      '首页': '/',
      '主页': '/',
      '预算': '/budget',
      '报表': '/reports',
      '统计': '/reports',
      '设置': '/settings',
      '储蓄': '/savings',
      '钱龄': '/money-age',
    };

    for (final entry in navigationKeywords.entries) {
      if (text.contains(entry.key)) {
        if (text.contains('打开') || text.contains('去') || text.contains('跳转')) {
          return _IntentResponse(
            message: '正在打开${entry.key}页面...',
            metadata: {'action': 'navigate', 'targetPage': entry.value},
            shouldSpeak: true,
          );
        }
      }
    }
    return null;
  }

  /// 处理错误
  void _handleError(String message) {
    setBallState(FloatingBallState.error);
    _addSystemMessage(message);

    Future.delayed(const Duration(seconds: 2), () {
      if (_ballState == FloatingBallState.error) {
        // 连续模式下，错误后也继续录音
        if (_continuousMode && _shouldAutoRestart) {
          debugPrint('[GlobalVoiceAssistant] 连续对话: 错误后自动继续');
          startRecording();
        } else {
          setBallState(FloatingBallState.idle);
        }
      }
    });
  }

  /// 显示 Toast（需要 UI 层实现）
  void _showToast(String message) {
    _addSystemMessage(message);
  }

  /// 添加用户消息
  void _addUserMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.user,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加助手消息
  void _addAssistantMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加处理结果消息（公开方法，供外部调用）
  ///
  /// 用于在语音命令处理完成后，将实际结果反馈给用户
  void addResultMessage(String content, {Map<String, dynamic>? metadata}) {
    _addAssistantMessage(content, metadata: metadata);
    notifyListeners();
  }

  /// 添加系统消息
  void _addSystemMessage(String content) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.system,
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  /// 添加消息到历史
  void _addMessage(ChatMessage message) {
    _conversationHistory.add(message);

    // 限制历史记录数量
    while (_conversationHistory.length > _maxHistorySize) {
      _conversationHistory.removeAt(0);
    }

    // 保存到本地存储
    _saveHistoryToStorage();

    notifyListeners();
  }

  /// 清除对话历史
  void clearHistory() {
    _conversationHistory.clear();
    _addSystemMessage('对话历史已清除');
    _saveHistoryToStorage();
    notifyListeners();
  }

  /// 持久化存储的key
  static const String _historyStorageKey = 'voice_assistant_history';

  /// 保存对话历史到本地存储
  Future<void> _saveHistoryToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _conversationHistory.map((m) => m.toJson()).toList();
      await prefs.setString(_historyStorageKey, jsonEncode(historyJson));
      debugPrint('[GlobalVoiceAssistant] 对话历史已保存 (${_conversationHistory.length}条)');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 保存对话历史失败: $e');
    }
  }

  /// 从本地存储加载对话历史
  Future<void> loadHistoryFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyStorageKey);
      if (historyString != null && historyString.isNotEmpty) {
        final historyJson = jsonDecode(historyString) as List<dynamic>;
        _conversationHistory.clear();
        for (final item in historyJson) {
          _conversationHistory.add(ChatMessage.fromJson(item as Map<String, dynamic>));
        }
        debugPrint('[GlobalVoiceAssistant] 对话历史已加载 (${_conversationHistory.length}条)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 加载对话历史失败: $e');
    }
  }

  /// 发送文本消息（非语音）
  Future<void> sendTextMessage(String text) async {
    if (text.isEmpty) return;

    _addUserMessage(text);
    setBallState(FloatingBallState.processing);

    try {
      final context = _contextService?.currentContext;
      final response = await _processIntent(text, context);

      _addAssistantMessage(response.message, metadata: response.metadata);
      setBallState(FloatingBallState.success);

      Future.delayed(const Duration(seconds: 1), () {
        if (_ballState == FloatingBallState.success) {
          setBallState(FloatingBallState.idle);
        }
      });
    } catch (e) {
      _handleError('处理失败');
    }
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _ttsService?.dispose();
    super.dispose();
  }
}

/// 意图响应
class _IntentResponse {
  final String message;
  final Map<String, dynamic>? metadata;
  final bool shouldSpeak;

  _IntentResponse({
    required this.message,
    this.metadata,
    this.shouldSpeak = false,
  });
}
