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

  // 权限回调（由 UI 层设置）
  void Function(MicrophonePermissionStatus status)? onPermissionRequired;

  // Getters
  FloatingBallState get ballState => _ballState;
  bool get isVisible => _isVisible;
  Offset get position => _position;
  bool get isInitialized => _isInitialized;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  VoiceContextService? get contextService => _contextService;

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
    if (_ballState != FloatingBallState.recording) return;

    try {
      // 检查录音时长
      final duration = DateTime.now().difference(_recordingStartTime!);
      if (duration.inMilliseconds < 500) {
        await _audioRecorder!.stop();
        setBallState(FloatingBallState.idle);
        _showToast('录音时间太短，请说话后再松开');
        return;
      }

      setBallState(FloatingBallState.processing);

      // 停止录音
      final path = await _audioRecorder!.stop();

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
    try {
      // 获取当前页面上下文
      final context = _contextService?.currentContext;

      // 语音识别
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        _handleError('录音文件不存在');
        return;
      }

      final result = await _recognitionEngine!.recognizeFromFile(audioFile);
      final recognizedText = result.text;

      if (recognizedText.isEmpty) {
        _handleError('未能识别语音内容');
        return;
      }

      // 添加用户消息
      _addUserMessage(recognizedText);

      // 处理意图（这里简化处理，实际应调用 VoiceServiceCoordinator）
      final response = await _processIntent(recognizedText, context);

      // 添加助手响应
      _addAssistantMessage(response.message, metadata: response.metadata);

      // 显示成功状态
      setBallState(FloatingBallState.success);

      // 2秒后恢复空闲状态
      Future.delayed(const Duration(seconds: 2), () {
        if (_ballState == FloatingBallState.success) {
          setBallState(FloatingBallState.idle);
        }
      });

      // 可选：TTS 播报
      if (_ttsService != null && response.shouldSpeak) {
        await _ttsService!.speak(response.message);
      }

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

  /// 处理意图
  Future<_IntentResponse> _processIntent(String text, PageContext? context) async {
    // 获取上下文提示，用于增强理解
    final contextHint = _contextService?.getContextHint() ?? '';
    debugPrint('[GlobalVoiceAssistant] 上下文提示: $contextHint');

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
        setBallState(FloatingBallState.idle);
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
