import 'package:flutter/material.dart';

import '../services/global_voice_assistant_manager.dart';
import '../theme/app_theme.dart';

/// 聊天消息列表组件
///
/// 统一封装消息列表的滚动行为：
/// - 首次进入时滚动到底部
/// - 有新消息时滚动到底部
/// - 消息内容更新时滚动到底部
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

  /// 上次最后一条消息的内容，用于检测消息更新
  String _lastMessageContent = '';

  /// 是否是首次构建
  bool _isFirstBuild = true;

  /// 用户是否正在手动向上滚动查看历史
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 如果用户滚动到距底部超过100像素，认为在查看历史
    _isUserScrolling = position.maxScrollExtent - position.pixels > 100;
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;

    // 获取最后一条消息的内容用于检测更新
    final lastContent = messages.isNotEmpty ? messages.last.content : '';
    final hasNewMessage = messages.length > _lastMessageCount;
    final hasContentUpdate = !hasNewMessage && lastContent != _lastMessageContent;

    // 滚动控制逻辑
    if (_isFirstBuild) {
      _isFirstBuild = false;
      _lastMessageCount = messages.length;
      _lastMessageContent = lastContent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: false);
      });
    } else if (hasNewMessage || hasContentUpdate) {
      _lastMessageCount = messages.length;
      _lastMessageContent = lastContent;
      // 如果用户没有在手动查看历史，自动滚动到底部
      if (!_isUserScrolling) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
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
  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
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
