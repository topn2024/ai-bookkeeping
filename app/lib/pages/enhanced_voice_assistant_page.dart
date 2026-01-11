import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/voice_coordinator_provider.dart';
import '../services/voice_service_coordinator.dart';
import '../widgets/multi_intent_confirm_widget.dart';
import '../widgets/amount_supplement_widget.dart';
import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';
import '../l10n/app_localizations.dart';
import 'settings_page.dart';
import 'main_navigation.dart';
import 'add_transaction_page.dart';
import 'image_recognition_page.dart';

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
  // ignore: unused_field
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
    final coordinator = ref.watch(voiceServiceCoordinatorProvider);
    final sessionState = coordinator.sessionState;
    final hasActiveSession = coordinator.hasActiveSession;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: _buildAppBar(context, l10n, coordinator),
      body: Column(
        children: [
          // 会话状态指示器
          if (hasActiveSession)
            _buildSessionIndicator(context, coordinator),

          // 消息列表
          Expanded(
            child: _buildMessageList(context),
          ),

          // 语音交互区域
          _buildVoiceInteractionArea(context, sessionState, coordinator),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    VoiceServiceCoordinator coordinator,
  ) {
    final sessionState = coordinator.sessionState;
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
                _getStatusText(sessionState),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(sessionState),
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
        if (sessionState != VoiceSessionState.idle)
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () async {
              final coordinator = ref.read(voiceServiceCoordinatorProvider);
              await coordinator.stopVoiceSession();
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
    VoiceServiceCoordinator coordinator,
  ) {
    final sessionState = coordinator.sessionState;
    final _ = coordinator.currentIntentType;

    if (sessionState == VoiceSessionState.idle) return const SizedBox.shrink();

    // 多意图确认状态显示专用组件
    if (sessionState == VoiceSessionState.waitingForMultiIntentConfirmation &&
        coordinator.hasPendingMultiIntent) {
      return _buildMultiIntentConfirmation(context, coordinator);
    }

    // 金额补充状态显示专用组件
    if (sessionState == VoiceSessionState.waitingForAmountSupplement &&
        coordinator.hasPendingMultiIntent) {
      return _buildAmountSupplement(context, coordinator);
    }

    String title = '';
    IconData icon = Icons.chat;
    Color color = AppTheme.primaryColor;

    switch (sessionState) {
      case VoiceSessionState.waitingForConfirmation:
        title = '等待确认';
        icon = Icons.check_circle_outline;
        color = AppColors.warning;
        break;
      case VoiceSessionState.waitingForClarification:
        title = '等待澄清';
        icon = Icons.help_outline;
        color = AppColors.primary;
        break;
      case VoiceSessionState.waitingForMultiIntentConfirmation:
        title = '多意图确认';
        icon = Icons.list_alt;
        color = AppColors.primary;
        break;
      case VoiceSessionState.waitingForAmountSupplement:
        title = '补充金额';
        icon = Icons.edit;
        color = AppColors.warning;
        break;
      case VoiceSessionState.processing:
        title = '处理中';
        icon = Icons.sync;
        color = AppColors.primary;
        break;
      case VoiceSessionState.listening:
        title = '正在聆听';
        icon = Icons.mic;
        color = AppColors.expense;
        break;
      case VoiceSessionState.error:
        title = '出错了';
        icon = Icons.error_outline;
        color = Colors.red;
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

  /// 构建多意图确认组件
  Widget _buildMultiIntentConfirmation(
    BuildContext context,
    VoiceServiceCoordinator coordinator,
  ) {
    final multiIntent = coordinator.pendingMultiIntent;
    if (multiIntent == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MultiIntentConfirmWidget(
        result: multiIntent,
        onConfirmAll: () async {
          final result = await coordinator.confirmMultiIntents();
          _addMessage(ChatMessage(
            type: MessageType.assistant,
            content: result.message ?? '操作完成',
            timestamp: DateTime.now(),
          ));
        },
        onCancelAll: () async {
          final result = await coordinator.cancelMultiIntents();
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '已取消',
            timestamp: DateTime.now(),
          ));
        },
        onCancelItem: (index) async {
          final result = await coordinator.cancelMultiIntentItem(index);
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '已移除',
            timestamp: DateTime.now(),
          ));
        },
        onSupplementAmount: (index, amount) async {
          final result = await coordinator.supplementAmount(index, amount);
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '金额已补充',
            timestamp: DateTime.now(),
          ));
        },
        showNoise: true,
      ),
    );
  }

  /// 构建金额补充组件
  Widget _buildAmountSupplement(
    BuildContext context,
    VoiceServiceCoordinator coordinator,
  ) {
    final multiIntent = coordinator.pendingMultiIntent;
    if (multiIntent == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AmountSupplementWidget(
        incompleteIntents: multiIntent.incompleteIntents,
        onSupplementAmount: (index, amount) async {
          final result = await coordinator.supplementAmount(index, amount);
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '金额已补充',
            timestamp: DateTime.now(),
          ));
        },
        onSkip: (index) async {
          final result = await coordinator.cancelMultiIntentItem(
            multiIntent.completeIntents.length + index,
          );
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '已跳过',
            timestamp: DateTime.now(),
          ));
        },
        onSkipAll: () async {
          final result = await coordinator.cancelMultiIntents();
          _addMessage(ChatMessage(
            type: MessageType.system,
            content: result.message ?? '已取消',
            timestamp: DateTime.now(),
          ));
        },
        onComplete: () async {
          // 所有金额补充完成，执行确认
          final result = await coordinator.confirmMultiIntents();
          _addMessage(ChatMessage(
            type: MessageType.assistant,
            content: result.message ?? '记录完成',
            timestamp: DateTime.now(),
          ));
        },
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
    VoiceSessionState sessionState,
    VoiceServiceCoordinator coordinator,
  ) {
    final isListening = sessionState == VoiceSessionState.listening;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 状态提示文字
            Text(
              _getActionText(sessionState),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isListening ? AppColors.expense : AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getActionHint(sessionState),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // 三个按钮区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 拍照记账按钮（左侧）
                _buildSideButton(
                  icon: Icons.camera_alt_outlined,
                  label: '拍照',
                  onTap: () => _navigateToImageRecognition(context),
                ),

                // 语音按钮（中间，主要）
                _buildMainMicButton(sessionState, coordinator),

                // 手动记账按钮（右侧）
                _buildSideButton(
                  icon: Icons.edit_outlined,
                  label: '手动',
                  onTap: () => _navigateToManualEntry(context),
                ),
              ],
            ),

            // 权限提示
            if (!_hasPermission) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _requestPermission,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_off, color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '点击申请麦克风权限',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 快捷操作按钮（会话进行中时显示）
            if (sessionState != VoiceSessionState.idle) ...[
              const SizedBox(height: 12),
              _buildQuickActionButtons(context, sessionState, coordinator),
            ],
          ],
        ),
      ),
    );
  }

  /// 主麦克风按钮（中央大按钮）
  Widget _buildMainMicButton(
    VoiceSessionState sessionState,
    VoiceServiceCoordinator coordinator,
  ) {
    final isListening = sessionState == VoiceSessionState.listening;

    return GestureDetector(
      onTapDown: _hasPermission ? (_) => _startListening(coordinator) : null,
      onTapUp: _hasPermission ? (_) => _stopListening(coordinator) : null,
      onTapCancel: _hasPermission ? () => _stopListening(coordinator) : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Column(
            children: [
              // 波浪动画容器
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外层波浪（录音时显示）
                    if (isListening) ...[
                      // 第三层波浪
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return Container(
                            width: 88 + (_waveController.value * 32),
                            height: 88 + (_waveController.value * 32),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.expense.withValues(
                                alpha: 0.1 * (1 - _waveController.value),
                              ),
                            ),
                          );
                        },
                      ),
                      // 第二层波浪
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 88 + (_pulseController.value * 20),
                            height: 88 + (_pulseController.value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.expense.withValues(
                                alpha: 0.15 * (1 - _pulseController.value),
                              ),
                            ),
                          );
                        },
                      ),
                      // 第一层波浪（最内层）
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.expense.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    // 主按钮
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hasPermission
                              ? (isListening
                                  ? [AppColors.expense, AppColors.expense.withValues(alpha: 0.85)]
                                  : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.85)])
                              : [Colors.grey, Colors.grey.shade400],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isListening ? AppColors.expense : AppTheme.primaryColor)
                                .withValues(alpha: 0.35),
                            blurRadius: isListening ? 24 : 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _hasPermission
                            ? (isListening ? Icons.mic : Icons.mic_none)
                            : Icons.mic_off,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '语音',
                style: TextStyle(
                  fontSize: 13,
                  color: isListening ? AppColors.expense : AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 侧边按钮（拍照/手动）
  Widget _buildSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.textSecondaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 导航到拍照记账
  void _navigateToImageRecognition(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageRecognitionPage()),
    );
  }

  /// 导航到手动记账
  void _navigateToManualEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
  }

  Widget _buildQuickActionButtons(
    BuildContext context,
    VoiceSessionState sessionState,
    VoiceServiceCoordinator coordinator,
  ) {
    return Row(
      children: [
        // 确认按钮
        IconButton(
          onPressed: () async {
            await coordinator.processVoiceCommand('确认');
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
          onPressed: () async {
            await coordinator.processVoiceCommand('取消');
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
  Future<void> _startListening(VoiceServiceCoordinator coordinator) async {
    if (!_hasPermission) return;

    await coordinator.startVoiceSession();
    _pulseController.repeat();
    _waveController.repeat();

    _addMessage(ChatMessage(
      type: MessageType.system,
      content: '正在聆听...',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _stopListening(VoiceServiceCoordinator coordinator) async {
    await coordinator.stopVoiceSession();
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();

    // 在模拟器上提示用户使用文字输入
    _addMessage(ChatMessage(
      type: MessageType.assistant,
      content: '语音识别需要真机环境。\n\n请在下方输入框中输入您的指令，例如：\n• 删除昨天的午餐\n• 把咖啡改成25元\n• 查看本月支出',
      timestamp: DateTime.now(),
    ));
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

  // ignore: unused_element
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
    // 过滤出用户发送的命令
    final userCommands = _messages
        .where((msg) => msg.type == MessageType.user)
        .toList()
        .reversed
        .toList();

    if (userCommands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无命令历史')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '命令历史',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmClearHistory();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清空'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.expense,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 命令列表
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: userCommands.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final command = userCommands[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(30),
                      radius: 16,
                      child: Icon(
                        Icons.mic,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      command.content,
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      _formatTime(command.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      color: AppColors.primary,
                      tooltip: '重新执行',
                      onPressed: () {
                        Navigator.pop(context);
                        _replayCommand(command.content);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _replayCommand(command.content);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认清空历史记录
  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空命令历史'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('聊天记录已清空')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  /// 重新执行命令
  Future<void> _replayCommand(String command) async {
    final coordinator = ref.read(voiceServiceCoordinatorProvider);

    // 添加用户消息
    _addMessage(ChatMessage(
      type: MessageType.user,
      content: command,
      timestamp: DateTime.now(),
    ));

    // 执行命令
    await coordinator.processVoiceCommand(command);

    // 获取处理结果并添加到聊天
    await Future.delayed(const Duration(milliseconds: 500));
    final state = ref.read(voiceServiceCoordinatorProvider);
    if (state.lastResponse != null && state.lastResponse!.isNotEmpty) {
      _addMessage(ChatMessage(
        type: MessageType.assistant,
        content: state.lastResponse!,
        timestamp: DateTime.now(),
      ));
    }
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
  String _getStatusText(VoiceSessionState sessionState) {
    if (sessionState == VoiceSessionState.listening) return '正在聆听...';
    if (sessionState == VoiceSessionState.processing) return '正在处理...';
    if (sessionState != VoiceSessionState.idle) return '会话进行中';
    return '在线';
  }

  Color _getStatusColor(VoiceSessionState sessionState) {
    if (sessionState == VoiceSessionState.listening) return AppColors.expense;
    if (sessionState == VoiceSessionState.processing) return AppColors.warning;
    if (sessionState != VoiceSessionState.idle) return AppColors.primary;
    return AppColors.income;
  }

  String _getActionText(VoiceSessionState sessionState) {
    if (!_hasPermission) return '需要权限';
    if (sessionState == VoiceSessionState.listening) return '正在聆听';
    if (sessionState == VoiceSessionState.processing) return '正在处理';
    if (sessionState != VoiceSessionState.idle) return '等待回应';
    return '按住说话';
  }

  String _getActionHint(VoiceSessionState sessionState) {
    if (!_hasPermission) return '点击申请麦克风权限';
    if (sessionState == VoiceSessionState.listening) return '松开结束录音';
    if (sessionState == VoiceSessionState.processing) return '正在理解您的指令...';
    if (sessionState != VoiceSessionState.idle) return '请说"确认"或"取消"';
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