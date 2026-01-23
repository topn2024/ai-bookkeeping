import 'package:flutter/material.dart';

import '../services/global_voice_assistant_manager.dart';
import '../theme/app_theme.dart';

/// 聊天消息列表组件
///
/// 统一封装消息列表的滚动行为：
/// - 首次进入时滚动到底部
/// - 有新消息时滚动到底部
/// - 允许用户向上查看历史记录（不会被自动滚动打断）
class ChatMessageListWidget extends StatefulWidget {
  /// 消息列表
  final List<ChatMessage> messages;

  /// 消息气泡构建器
  final Widget Function(BuildContext context, ChatMessage message) messageBuilder;

  /// 空状态构建器
  final Widget Function(BuildContext context)? emptyBuilder;

  /// 内边距
  final EdgeInsets padding;

  const ChatMessageListWidget({
    super.key,
    required this.messages,
    required this.messageBuilder,
    this.emptyBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<ChatMessageListWidget> createState() => _ChatMessageListWidgetState();
}

class _ChatMessageListWidgetState extends State<ChatMessageListWidget> {
  final ScrollController _scrollController = ScrollController();

  /// 上次消息数量，用于检测是否有新消息
  int _lastMessageCount = -1; // -1表示未初始化

  /// 是否是首次构建
  bool _isFirstBuild = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;

    // 滚动控制逻辑：只在首次进入和有新消息时滚动到底部
    if (_isFirstBuild) {
      _isFirstBuild = false;
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else if (messages.length > _lastMessageCount) {
      // 只在有新消息时才滚动到底部（允许用户向上查看历史）
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    if (messages.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _buildDefaultEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return widget.messageBuilder(context, messages[index]);
      },
    );
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 默认空状态
  Widget _buildDefaultEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '点击麦克风开始语音交互',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
