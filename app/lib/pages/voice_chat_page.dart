import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../services/global_voice_assistant_manager.dart';

/// 6.12 连续对话记账页面
/// 支持多轮对话的语音记账交互
class VoiceChatPage extends ConsumerStatefulWidget {
  const VoiceChatPage({super.key});

  @override
  ConsumerState<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends ConsumerState<VoiceChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 使用共享的对话历史
    final messages = ref.watch(conversationHistoryProvider);
    final manager = ref.watch(globalVoiceAssistantProvider);
    final ballState = manager.ballState;

    // 当消息变化时滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.voiceChat,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _getStatusText(ballState, l10n),
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(ballState),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除对话',
            onPressed: () => _confirmClearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(l10n)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index]);
                    },
                  ),
          ),
          // 快捷问题
          _buildQuickQuestions(l10n),
          // 输入区域
          _buildInputArea(l10n, ballState),
        ],
      ),
    );
  }

  /// 构建消息气泡
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.type == ChatMessageType.user;
    final isSystem = message.type == ChatMessageType.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
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
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isLoading
                  ? _buildLoadingIndicator()
                  : _buildMessageContent(message, isUser),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 构建消息内容
  Widget _buildMessageContent(ChatMessage message, bool isUser) {
    final metadata = message.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppTheme.textPrimaryColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        // 如果有记账结果，显示卡片
        if (metadata != null && metadata['amount'] != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: isUser ? Colors.white : AppTheme.successColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '已记录 ¥${metadata['amount']}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isUser ? Colors.white : AppTheme.successColor,
                  ),
                ),
                if (metadata['category'] != null) ...[
                  Text(
                    ' · ${metadata['category']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 构建加载指示器
  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300 + index * 100),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  /// 构建快捷问题
  Widget _buildQuickQuestions(AppLocalizations l10n) {
    final questions = [
      '今天花了多少钱？',
      '本月餐饮支出',
      '查询钱龄',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickQuestions,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: questions.map((q) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _sendMessage(q),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea(AppLocalizations l10n, FloatingBallState ballState) {
    final isRecording = ballState == FloatingBallState.recording;
    final isProcessing = ballState == FloatingBallState.processing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 文字输入框
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  enabled: !isRecording && !isProcessing,
                  decoration: InputDecoration(
                    hintText: l10n.typeOrSpeak,
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      _sendMessage(text);
                      _textController.clear();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 语音按钮 - 使用共享的录音功能
            GestureDetector(
              onTap: () => _toggleRecording(ballState),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isRecording ? 64 : 48,
                height: isRecording ? 64 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isRecording
                        ? [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.8)]
                        : isProcessing
                            ? [Colors.orange, Colors.orange.withValues(alpha: 0.8)]
                            : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(isRecording ? 32 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? AppTheme.errorColor
                              : isProcessing
                                  ? Colors.orange
                                  : AppTheme.primaryColor)
                          .withValues(alpha: 0.4),
                      blurRadius: isRecording ? 20 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: isRecording ? 28 : 24,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 发送消息 - 使用共享的管理器
  void _sendMessage(String text) {
    if (text.isEmpty) return;
    ref.read(globalVoiceAssistantProvider).sendTextMessage(text);
  }

  /// 切换录音状态 - 使用共享的管理器
  void _toggleRecording(FloatingBallState currentState) {
    HapticFeedback.mediumImpact();
    final manager = ref.read(globalVoiceAssistantProvider);

    if (currentState == FloatingBallState.idle) {
      manager.startRecording();
    } else if (currentState == FloatingBallState.recording) {
      manager.stopRecording();
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
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

  /// 确认清除历史
  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话'),
        content: const Text('确定要清除所有对话记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(globalVoiceAssistantProvider).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 获取状态文本
  String _getStatusText(FloatingBallState state, AppLocalizations l10n) {
    switch (state) {
      case FloatingBallState.idle:
        return l10n.continuousChat;
      case FloatingBallState.recording:
        return '正在录音...';
      case FloatingBallState.processing:
        return '处理中...';
      case FloatingBallState.success:
        return '完成';
      case FloatingBallState.error:
        return '出错了';
      case FloatingBallState.hidden:
        return '';
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(FloatingBallState state) {
    switch (state) {
      case FloatingBallState.idle:
        return AppTheme.textSecondaryColor;
      case FloatingBallState.recording:
        return Colors.red;
      case FloatingBallState.processing:
        return Colors.orange;
      case FloatingBallState.success:
        return Colors.green;
      case FloatingBallState.error:
        return Colors.red;
      case FloatingBallState.hidden:
        return Colors.transparent;
    }
  }

  /// 构建空状态
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '开始对话吧！',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击麦克风按钮或输入文字',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
