import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/voice_service_provider.dart';
import '../services/voice_service_coordinator.dart';
import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';
import '../l10n/app_localizations.dart';
import 'settings_page.dart';
import 'main_navigation.dart';

/// 增强版语音助手页面 - 集成完整语音服务功能
///
/// 支持的功能：
/// - 语音命令识别
/// - 实体消歧
/// - 智能删除/修改
/// - 语音反馈
/// - 会话管理
class EnhancedVoiceAssistantPage extends ConsumerStatefulWidget {
  const EnhancedVoiceAssistantPage({super.key});

  @override
  ConsumerState<EnhancedVoiceAssistantPage> createState() => _EnhancedVoiceAssistantPageState();
}

class _EnhancedVoiceAssistantPageState extends ConsumerState<EnhancedVoiceAssistantPage>
    with TickerProviderStateMixin {
  static const String _chatHistoryKey = 'voice_assistant_chat_history';
  static const int _maxHistoryDays = 30; // 保留30天的聊天记录

  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late AnimationController _pulseController;
  late AnimationController _waveController;
  bool _hasPermission = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadChatHistory();
    _checkPermissions();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  /// 加载聊天历史记录
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_chatHistoryKey);

      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        final loadedMessages = historyList
            .map((item) => ChatMessage.fromJson(item))
            .toList();

        // 清理超过30天的旧记录
        final cutoffDate = DateTime.now().subtract(Duration(days: _maxHistoryDays));
        final recentMessages = loadedMessages
            .where((msg) => msg.timestamp.isAfter(cutoffDate))
            .toList();

        setState(() {
          _messages.clear();
          _messages.addAll(recentMessages);
          _isLoadingHistory = false;
        });

        // 如果清理了旧记录，保存更新后的历史
        if (recentMessages.length < loadedMessages.length) {
          await _saveChatHistory();
        }
      } else {
        // 首次使用，添加欢迎消息
        setState(() {
          _isLoadingHistory = false;
        });
        _addWelcomeMessage();
      }
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });
      _addWelcomeMessage();
    }
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() {
    _addMessage(ChatMessage(
      type: MessageType.assistant,
      content: '您好！我是您的智能语音助手 🤖\n\n我可以帮您：\n• 语音记账和管理\n• 删除和修改记录\n• 查询财务信息\n• 导航到各个页面\n\n请点击麦克风开始语音交互！',
      timestamp: DateTime.now(),
    ));
  }

  /// 保存聊天历史记录
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(
        _messages.map((msg) => msg.toJson()).toList(),
      );
      await prefs.setString(_chatHistoryKey, historyJson);
    } catch (e) {
      // 保存失败，静默处理
    }
  }

  /// 清除所有聊天记录
  Future<void> _clearChatHistory() async {
    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
    _addWelcomeMessage();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasPermission = status.isGranted;
    });

    if (!_hasPermission) {
      final result = await Permission.microphone.request();
      setState(() {
        _hasPermission = result.isGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voiceState = ref.watch(voiceInteractionStateProvider);
    final coordinator = ref.read(voiceInteractionStateProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: _buildAppBar(context, l10n, voiceState),
      body: Column(
        children: [
          // 会话状态指示器
          if (voiceState.currentSessionType != null)
            _buildSessionIndicator(context, voiceState),

          // 消息列表
          Expanded(
            child: _buildMessageList(context),
          ),

          // 语音交互区域
          _buildVoiceInteractionArea(context, voiceState, coordinator),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    VoiceInteractionState voiceState,
  ) {
    return AppBar(
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '智能语音助手',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _getStatusText(voiceState),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(voiceState),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // 清除历史记录按钮
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('清除聊天记录'),
                content: const Text('确定要清除所有聊天记录吗？此操作不可恢复。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _clearChatHistory();
            }
          },
          tooltip: '清除聊天记录',
        ),
        // 会话控制按钮
        if (voiceState.currentSessionType != null)
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () {
              final coordinator = ref.read(voiceInteractionStateProvider.notifier);
              coordinator.clearSession();
              _addMessage(ChatMessage(
                type: MessageType.system,
                content: '会话已取消',
                timestamp: DateTime.now(),
              ));
            },
            tooltip: '取消当前会话',
          ),
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: _showCommandHistory,
          tooltip: '查看命令历史',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showOptions,
        ),
      ],
    );
  }

  Widget _buildSessionIndicator(
    BuildContext context,
    VoiceInteractionState voiceState,
  ) {
    final sessionType = voiceState.currentSessionType;
    if (sessionType == null) return const SizedBox.shrink();

    String title = '';
    IconData icon = Icons.chat;
    Color color = AppTheme.primaryColor;

    switch (sessionType) {
      case VoiceSessionType.delete:
        title = '删除会话';
        icon = Icons.delete_outline;
        color = AppColors.expense;
        break;
      case VoiceSessionType.modify:
        title = '修改会话';
        icon = Icons.edit_outlined;
        color = AppColors.primary;
        break;
      case VoiceSessionType.add:
        title = '添加会话';
        icon = Icons.add_circle_outline;
        color = AppColors.income;
        break;
      case VoiceSessionType.query:
        title = '查询会话';
        icon = Icons.search;
        color = AppColors.primary;
        break;
      default:
        title = '活跃会话';
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            '进行中...',
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(context, message);
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final isUser = message.type == MessageType.user;
    final isSystem = message.type == MessageType.system;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && !isSystem) ...[
            _buildAvatar(message.type),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSystem
                    ? Colors.grey.withValues(alpha: 0.1)
                    : isUser
                        ? AppTheme.primaryColor
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: isSystem ? null : AntigravityShadows.L1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isSystem
                          ? Colors.grey[600]
                          : isUser
                              ? Colors.white
                              : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isSystem
                          ? Colors.grey[500]
                          : isUser
                              ? Colors.white70
                              : Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(MessageType.user),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(MessageType type) {
    late IconData icon;
    late Color color;

    switch (type) {
      case MessageType.user:
        icon = Icons.person;
        color = AppTheme.primaryColor;
        break;
      case MessageType.assistant:
        icon = Icons.psychology;
        color = AppColors.income;
        break;
      case MessageType.system:
        icon = Icons.info_outline;
        color = Colors.grey;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildVoiceInteractionArea(
    BuildContext context,
    VoiceInteractionState voiceState,
    VoiceInteractionNotifier coordinator,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AntigravityShadows.L2,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 反馈文本
            if (voiceState.feedback != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  voiceState.feedback!,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // 语音按钮和状态
            Row(
              children: [
                // 语音按钮
                GestureDetector(
                  onTapDown: _hasPermission ? (_) => _startListening(coordinator) : null,
                  onTapUp: _hasPermission ? (_) => _stopListening(coordinator) : null,
                  onTapCancel: _hasPermission ? () => _stopListening(coordinator) : null,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _hasPermission
                              ? (voiceState.isListening
                                  ? AppColors.expense
                                  : AppTheme.primaryColor)
                              : Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: voiceState.isListening
                              ? [
                                  BoxShadow(
                                    color: AppColors.expense.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: _pulseController.value * 10,
                                  ),
                                ]
                              : AntigravityShadows.L2,
                        ),
                        child: Icon(
                          _hasPermission
                              ? (voiceState.isListening ? Icons.mic : Icons.mic_none)
                              : Icons.mic_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // 状态文本
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getActionText(voiceState),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getActionHint(voiceState),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // 快捷操作按钮
                if (voiceState.currentSessionType != null) ...[
                  const SizedBox(width: 8),
                  _buildQuickActionButtons(context, voiceState, coordinator),
                ],
              ],
            ),

            // 权限提示
            if (!_hasPermission) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_off, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '需要麦克风权限才能使用语音功能',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _requestPermission,
                      child: const Text('申请权限'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(
    BuildContext context,
    VoiceInteractionState voiceState,
    VoiceInteractionNotifier coordinator,
  ) {
    return Row(
      children: [
        // 确认按钮
        IconButton(
          onPressed: () {
            coordinator.handleConfirmation('确认');
            _addMessage(ChatMessage(
              type: MessageType.user,
              content: '确认',
              timestamp: DateTime.now(),
            ));
          },
          icon: const Icon(Icons.check_circle_outline),
          iconSize: 20,
          color: AppColors.income,
          tooltip: '确认操作',
        ),

        // 取消按钮
        IconButton(
          onPressed: () {
            coordinator.handleConfirmation('取消');
            _addMessage(ChatMessage(
              type: MessageType.user,
              content: '取消',
              timestamp: DateTime.now(),
            ));
          },
          icon: const Icon(Icons.cancel_outlined),
          iconSize: 20,
          color: AppColors.expense,
          tooltip: '取消操作',
        ),
      ],
    );
  }

  // 事件处理方法
  void _startListening(VoiceInteractionNotifier coordinator) {
    if (!_hasPermission) return;

    coordinator.startListening();
    _pulseController.repeat();

    _addMessage(ChatMessage(
      type: MessageType.system,
      content: '正在聆听...',
      timestamp: DateTime.now(),
    ));
  }

  void _stopListening(VoiceInteractionNotifier coordinator) {
    coordinator.stopListening();
    _pulseController.stop();
    _pulseController.reset();

    // 模拟语音处理
    _simulateVoiceProcessing(coordinator);
  }

  // 模拟语音处理（在实际应用中这里应该连接真实的语音识别）
  Future<void> _simulateVoiceProcessing(VoiceInteractionNotifier coordinator) async {
    const testCommands = [
      '删除昨天的午餐',
      '把咖啡的金额改成25元',
      '查看本月的支出',
      '添加一笔打车费用30元',
      '打开设置页面',
    ];

    final randomCommand = testCommands[DateTime.now().microsecond % testCommands.length];

    _addMessage(ChatMessage(
      type: MessageType.user,
      content: randomCommand,
      timestamp: DateTime.now(),
    ));

    // 延迟处理以模拟真实的语音识别过程
    await Future.delayed(const Duration(milliseconds: 500));

    await coordinator.processVoiceCommand(randomCommand);

    // 获取语音服务的处理结果并添加到聊天
    await Future.delayed(const Duration(milliseconds: 500));

    final state = ref.read(voiceInteractionStateProvider);
    if (state.feedback != null && state.feedback!.isNotEmpty) {
      _addMessage(ChatMessage(
        type: MessageType.assistant,
        content: state.feedback!,
        timestamp: DateTime.now(),
      ));
    }

    // 检查是否有导航数据，如果有则执行导航
    if (state.currentSessionType == VoiceSessionType.navigation &&
        state.currentSessionData != null) {
      final navData = state.currentSessionData as Map<String, dynamic>;
      final route = navData['route'] as String?;
      if (route != null) {
        _navigateToRoute(route);
        // 清除导航会话数据
        coordinator.clearSession();
      }
    }
  }

  String _generateMockResponse(String command) {
    if (command.contains('删除')) {
      return '好的，我找到了相关记录。请确认要删除的项目：\n• 昨天 12:30 午餐 ¥35.00\n\n请说"确认"删除，或"取消"操作。';
    } else if (command.contains('改成') || command.contains('修改')) {
      return '好的，我找到了咖啡的记录。确认要将金额从¥28.00改为¥25.00吗？\n\n请说"确认"或"取消"。';
    } else if (command.contains('查看') || command.contains('统计')) {
      return '本月支出统计：\n• 餐饮：¥1,250\n• 交通：¥380\n• 购物：¥650\n• 其他：¥220\n\n总支出：¥2,500';
    } else if (command.contains('添加')) {
      return '好的，已为您添加一笔交易：\n• 类型：交通\n• 金额：¥30.00\n• 时间：刚刚\n\n记录已保存成功！';
    } else if (command.contains('打开') || command.contains('页面')) {
      return '正在为您跳转到设置页面...';
    } else {
      return '抱歉，我没有完全理解您的指令。请再说一遍，或者尝试其他表达方式。';
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });

    // 保存聊天历史
    _saveChatHistory();

    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToRoute(String route) {
    if (!mounted) return;

    Widget targetPage;
    switch (route) {
      case '/home':
        targetPage = const MainNavigation();
        break;
      case '/settings':
        targetPage = const SettingsPage();
        break;
      case '/statistics':
      case '/accounts':
        // 这些页面暂时显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$route 页面开发中')),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未知路由: $route')),
        );
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  Future<void> _requestPermission() async {
    final result = await Permission.microphone.request();
    setState(() {
      _hasPermission = result.isGranted;
    });

    if (!_hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要麦克风权限才能使用语音功能，请在设置中手动开启'),
          ),
        );
      }
    }
  }

  void _showCommandHistory() {
    // TODO: 实现命令历史显示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('命令历史功能正在开发中')),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('命令历史'),
              onTap: () {
                Navigator.pop(context);
                _showCommandHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('语音设置'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 打开语音设置
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('使用帮助'),
              onTap: () {
                Navigator.pop(context);
                _showHelp();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('语音助手使用指南'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('支持的语音命令：\n', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('删除操作：\n• "删除昨天的午餐"\n• "删掉刚才那笔"\n• "取消上一笔记录"\n'),
              Text('修改操作：\n• "把午餐改成35元"\n• "修改分类为交通"\n• "改成昨天的时间"\n'),
              Text('查询操作：\n• "查看本月支出"\n• "显示餐饮统计"\n• "今天花了多少钱"\n'),
              Text('导航操作：\n• "打开设置页面"\n• "进入预算中心"\n• "切换到首页"\n'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  // 辅助方法
  String _getStatusText(VoiceInteractionState voiceState) {
    if (voiceState.isListening) return '正在聆听...';
    if (voiceState.isProcessing) return '正在处理...';
    if (voiceState.currentSessionType != null) return '会话进行中';
    return '在线';
  }

  Color _getStatusColor(VoiceInteractionState voiceState) {
    if (voiceState.isListening) return AppColors.expense;
    if (voiceState.isProcessing) return AppColors.warning;
    if (voiceState.currentSessionType != null) return AppColors.primary;
    return AppColors.income;
  }

  String _getActionText(VoiceInteractionState voiceState) {
    if (!_hasPermission) return '需要权限';
    if (voiceState.isListening) return '正在聆听';
    if (voiceState.isProcessing) return '正在处理';
    if (voiceState.currentSessionType != null) return '等待回应';
    return '按住说话';
  }

  String _getActionHint(VoiceInteractionState voiceState) {
    if (!_hasPermission) return '点击申请麦克风权限';
    if (voiceState.isListening) return '松开结束录音';
    if (voiceState.isProcessing) return '正在理解您的指令...';
    if (voiceState.currentSessionType != null) return '请说"确认"或"取消"';
    return '长按麦克风开始语音交互';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// 数据类型定义
enum MessageType { user, assistant, system }

class ChatMessage {
  final MessageType type;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.type,
    required this.content,
    required this.timestamp,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 从JSON创建
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      type: MessageType.values[json['type'] as int],
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}