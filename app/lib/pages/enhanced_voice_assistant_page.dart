import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/voice_coordinator_provider.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../services/voice_service_coordinator.dart';
import '../services/global_voice_assistant_manager.dart';
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
  /// 返回回调（用于嵌入在IndexedStack中时）
  final VoidCallback? onBack;

  const EnhancedVoiceAssistantPage({super.key, this.onBack});

  @override
  ConsumerState<EnhancedVoiceAssistantPage> createState() => _EnhancedVoiceAssistantPageState();
}

class _EnhancedVoiceAssistantPageState extends ConsumerState<EnhancedVoiceAssistantPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late AnimationController _waveController;

  /// 权限状态：null = 检查中，true = 已授权，false = 未授权
  bool? _hasPermission;

  // 交互模式：true = 点击开始/停止，false = 按住说话
  final bool _tapToToggleMode = true;

  // 使用 GlobalVoiceAssistantManager 进行录音和聊天记录管理
  GlobalVoiceAssistantManager get _voiceManager => ref.read(globalVoiceAssistantProvider);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

  /// 清除所有聊天记录
  Future<void> _clearChatHistory() async {
    _voiceManager.clearHistory();
  }

  Future<void> _checkPermissions() async {
    debugPrint('[VoiceAssistantPage] _checkPermissions 开始');
    final status = await Permission.microphone.status;
    debugPrint('[VoiceAssistantPage] 麦克风权限状态: $status, isGranted=${status.isGranted}');
    setState(() {
      _hasPermission = status.isGranted;
    });
    debugPrint('[VoiceAssistantPage] _hasPermission 设置为: $_hasPermission');
    // 注意：不在这里请求权限，由 GlobalVoiceAssistantManager 在实际录音时统一处理
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coordinator = ref.watch(voiceServiceCoordinatorProvider);
    final sessionState = coordinator.sessionState;
    final hasActiveSession = coordinator.hasActiveSession;

    // 监听 GlobalVoiceAssistantManager 的状态变化
    final voiceManager = ref.watch(globalVoiceAssistantProvider);
    final messages = voiceManager.conversationHistory;
    final isRecording = voiceManager.ballState == FloatingBallState.recording;
    final isProcessing = voiceManager.ballState == FloatingBallState.processing;

    // 根据录音状态控制动画
    if (isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat();
      _waveController.repeat();
    } else if (!isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
      _waveController.stop();
      _waveController.reset();
    }

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
            child: _buildMessageList(context, messages),
          ),

          // 语音交互区域
          _buildVoiceInteractionArea(context, sessionState, coordinator, isRecording, isProcessing),
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
        onPressed: () {
          if (widget.onBack != null) {
            widget.onBack!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能语音助手',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getStatusText(sessionState),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(sessionState),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

    final voiceManager = ref.read(globalVoiceAssistantProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MultiIntentConfirmWidget(
        result: multiIntent,
        onConfirmAll: () async {
          final result = await coordinator.confirmMultiIntents();
          voiceManager.sendTextMessage(result.message ?? '操作完成');
        },
        onCancelAll: () async {
          final result = await coordinator.cancelMultiIntents();
          voiceManager.sendTextMessage(result.message ?? '已取消');
        },
        onCancelItem: (index) async {
          final result = await coordinator.cancelMultiIntentItem(index);
          voiceManager.sendTextMessage(result.message ?? '已移除');
        },
        onSupplementAmount: (index, amount) async {
          final result = await coordinator.supplementAmount(index, amount);
          voiceManager.sendTextMessage(result.message ?? '金额已补充');
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

    final voiceManager = ref.read(globalVoiceAssistantProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AmountSupplementWidget(
        incompleteIntents: multiIntent.incompleteIntents,
        onSupplementAmount: (index, amount) async {
          final result = await coordinator.supplementAmount(index, amount);
          voiceManager.sendTextMessage(result.message ?? '金额已补充');
        },
        onSkip: (index) async {
          final result = await coordinator.cancelMultiIntentItem(
            multiIntent.completeIntents.length + index,
          );
          voiceManager.sendTextMessage(result.message ?? '已跳过');
        },
        onSkipAll: () async {
          final result = await coordinator.cancelMultiIntents();
          voiceManager.sendTextMessage(result.message ?? '已取消');
        },
        onComplete: () async {
          // 所有金额补充完成，执行确认
          final result = await coordinator.confirmMultiIntents();
          voiceManager.sendTextMessage(result.message ?? '记录完成');
        },
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages) {
    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '点击麦克风开始语音交互',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubbleFromGlobal(context, message);
      },
    );
  }

  /// 从 GlobalVoiceAssistantManager.ChatMessage 构建消息气泡
  Widget _buildMessageBubbleFromGlobal(BuildContext context, ChatMessage message) {
    final isUser = message.type == ChatMessageType.user;
    final isSystem = message.type == ChatMessageType.system;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && !isSystem) ...[
            _buildAvatarFromType(message.type),
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
                boxShadow: isSystem ? null : AntigravityShadows.l1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isUser ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '处理中...',
                          style: TextStyle(
                            color: isUser ? Colors.white70 : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  else
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
            _buildAvatarFromType(ChatMessageType.user),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarFromType(ChatMessageType type) {
    late IconData icon;
    late Color color;

    switch (type) {
      case ChatMessageType.user:
        icon = Icons.person;
        color = AppTheme.primaryColor;
        break;
      case ChatMessageType.assistant:
        icon = Icons.psychology;
        color = AppColors.income;
        break;
      case ChatMessageType.system:
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
    bool isRecording,
    bool isProcessing,
  ) {
    final voiceManager = ref.watch(globalVoiceAssistantProvider);
    final isListening = isRecording || sessionState == VoiceSessionState.listening;

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

            // 权限提示（只在明确知道没有权限时显示，检查中不显示）
            if (_hasPermission == false) ...[
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

            // 快捷操作按钮（会话进行中或连续模式时显示）
            if (sessionState != VoiceSessionState.idle ||
                voiceManager.isContinuousMode ||
                isRecording ||
                isProcessing) ...[
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
    final voiceManager = ref.watch(globalVoiceAssistantProvider);
    final isRecording = voiceManager.ballState == FloatingBallState.recording;
    final isProcessing = voiceManager.ballState == FloatingBallState.processing;
    final isListening = isRecording || sessionState == VoiceSessionState.listening;

    return GestureDetector(
      // 点击切换模式：点击开始/停止录音
      // 权限检查中(null)或已授权(true)时允许操作
      onTap: _tapToToggleMode && _hasPermission != false ? () => _toggleRecording() : null,
      // 按住说话模式：按下开始，松开停止
      onTapDown: !_tapToToggleMode && _hasPermission != false && !isProcessing ? (_) => _startRecording() : null,
      onTapUp: !_tapToToggleMode && _hasPermission != false ? (_) => _stopRecording() : null,
      onTapCancel: !_tapToToggleMode && _hasPermission != false ? () => _stopRecording() : null,
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
                          colors: _hasPermission != false
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
                        _hasPermission != false
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
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    final isContinuous = voiceManager.isContinuousMode;

    return Row(
      children: [
        // 确认按钮
        IconButton(
          onPressed: () async {
            await voiceManager.sendTextMessage('确认');
          },
          icon: const Icon(Icons.check_circle_outline),
          iconSize: 20,
          color: AppColors.income,
          tooltip: '确认操作',
        ),

        // 取消按钮
        IconButton(
          onPressed: () async {
            await voiceManager.sendTextMessage('取消');
          },
          icon: const Icon(Icons.cancel_outlined),
          iconSize: 20,
          color: AppColors.expense,
          tooltip: '取消操作',
        ),

        // 结束对话按钮（连续模式时显示）
        if (isContinuous)
          IconButton(
            onPressed: _endConversation,
            icon: const Icon(Icons.stop_circle_outlined),
            iconSize: 20,
            color: Colors.grey[600],
            tooltip: '结束对话',
          ),
      ],
    );
  }

  // 事件处理方法 - 使用 GlobalVoiceAssistantManager 进行录音

  /// 切换录音状态（点击模式）
  Future<void> _toggleRecording() async {
    // 如果没有权限，先请求权限
    if (_hasPermission == false) {
      debugPrint('[VoiceAssistantPage] 没有麦克风权限，请求权限');
      final granted = await _voiceManager.requestMicrophonePermission();
      setState(() {
        _hasPermission = granted;
      });
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能使用语音功能')),
          );
        }
        return;
      }
    }

    final voiceManager = ref.read(globalVoiceAssistantProvider);
    final currentState = voiceManager.ballState;

    if (currentState == FloatingBallState.recording) {
      // 正在录音，停止当前录音（但保持连续模式，处理完后会自动继续）
      await voiceManager.stopRecording();
      debugPrint('[VoiceAssistantPage] 停止录音，等待处理后自动继续');
    } else if (currentState == FloatingBallState.idle ||
        currentState == FloatingBallState.success ||
        currentState == FloatingBallState.error) {
      // 空闲状态，开始录音（启用连续对话模式）
      voiceManager.setContinuousMode(true);
      await _startRecording();
    }
    // 如果正在处理中，不做任何操作
  }

  /// 完全结束对话（停止连续模式）
  void _endConversation() {
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    voiceManager.stopContinuousMode();
    debugPrint('[VoiceAssistantPage] 对话已结束');
  }

  Future<void> _startRecording() async {
    // 如果没有权限，先请求权限
    if (_hasPermission == false) {
      debugPrint('[VoiceAssistantPage] 没有麦克风权限，请求权限');
      final granted = await _voiceManager.requestMicrophonePermission();
      setState(() {
        _hasPermission = granted;
      });
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能使用语音功能')),
          );
        }
        return;
      }
    }

    final voiceManager = ref.read(globalVoiceAssistantProvider);
    if (voiceManager.ballState == FloatingBallState.recording) return;

    try {
      // 振动反馈
      HapticFeedback.mediumImpact();

      // 使用 GlobalVoiceAssistantManager 开始录音
      await voiceManager.startRecording();

      debugPrint('[VoiceAssistantPage] 开始录音');
    } catch (e) {
      debugPrint('[VoiceAssistantPage] 开始录音失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
      );
    }
  }

  Future<void> _stopRecording() async {
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    if (voiceManager.ballState != FloatingBallState.recording) return;

    try {
      // 使用 GlobalVoiceAssistantManager 停止录音并处理
      // 注意：不要停止连续模式，让处理完后自动继续
      await voiceManager.stopRecording();
      debugPrint('[VoiceAssistantPage] 停止录音');
    } catch (e) {
      debugPrint('[VoiceAssistantPage] 停止录音失败: $e');
    }
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

    if (_hasPermission == false) {
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
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    final userCommands = voiceManager.conversationHistory
        .where((msg) => msg.type == ChatMessageType.user)
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
                separatorBuilder: (_, _) => const Divider(height: 1),
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
    // 使用 GlobalVoiceAssistantManager 发送文本消息
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    await voiceManager.sendTextMessage(command);
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
    if (_hasPermission == false) return '需要权限';
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    final isRecording = voiceManager.ballState == FloatingBallState.recording;
    final isProcessing = voiceManager.ballState == FloatingBallState.processing;
    if (isRecording) return '正在聆听...';
    if (isProcessing || sessionState == VoiceSessionState.processing) return '正在处理';
    if (sessionState != VoiceSessionState.idle) return '等待回应';
    return _tapToToggleMode ? '点击开始' : '按住说话';
  }

  String _getActionHint(VoiceSessionState sessionState) {
    if (_hasPermission == false) return '点击申请麦克风权限';
    final voiceManager = ref.read(globalVoiceAssistantProvider);
    final isRecording = voiceManager.ballState == FloatingBallState.recording;
    final isProcessing = voiceManager.ballState == FloatingBallState.processing;
    final isContinuous = voiceManager.isContinuousMode;
    if (isRecording) {
      return _tapToToggleMode ? '再次点击结束，说完会自动继续' : '松开即结束';
    }
    if (isProcessing || sessionState == VoiceSessionState.processing) {
      return isContinuous ? '处理完成后会自动开始下一轮...' : '正在理解您的指令...';
    }
    if (sessionState != VoiceSessionState.idle) return '请说"确认"或"取消"';
    return _tapToToggleMode ? '点击麦克风开始连续对话' : '按住麦克风直接说话';
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