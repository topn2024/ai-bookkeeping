import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../extensions/category_extensions.dart';

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
}

/// 6.12 连续对话记账页面
/// 支持多轮对话的语音记账交互
class VoiceChatPage extends ConsumerStatefulWidget {
  const VoiceChatPage({super.key});

  @override
  ConsumerState<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends ConsumerState<VoiceChatPage>
    with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;
  // ignore: unused_field
  bool _isProcessing = false;
  late AnimationController _waveController;
  final List<double> _waveHeights = List.generate(12, (_) => 0.3);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 添加欢迎消息
    _addSystemMessage('欢迎使用语音记账助手！\n您可以直接说出消费内容，我会帮您记录。');

    Future.delayed(const Duration(milliseconds: 500), () {
      _addAssistantMessage('您好！我是您的记账小助手 😊\n\n试试说"午餐35块"或者"打车去公司花了20块钱"');
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              l10n.continuousChat,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/voice-history');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          // 快捷问题
          _buildQuickQuestions(l10n),
          // 输入区域
          _buildInputArea(l10n),
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
  Widget _buildInputArea(AppLocalizations l10n) {
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
            // 语音按钮
            GestureDetector(
              onTapDown: (_) => _startRecording(),
              onTapUp: (_) => _stopRecording(),
              onTapCancel: () => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRecording ? 64 : 48,
                height: _isRecording ? 64 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isRecording
                        ? [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.8)]
                        : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(_isRecording ? 32 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor)
                          .withValues(alpha: 0.4),
                      blurRadius: _isRecording ? 20 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: _isRecording ? 28 : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加系统消息
  void _addSystemMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.system,
        content: content,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  /// 添加助手消息
  void _addAssistantMessage(String content, {Map<String, dynamic>? metadata}) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.assistant,
        content: content,
        timestamp: DateTime.now(),
        metadata: metadata,
      ));
    });
    _scrollToBottom();
  }

  /// 添加用户消息
  void _addUserMessage(String content, {Map<String, dynamic>? metadata}) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.user,
        content: content,
        timestamp: DateTime.now(),
        metadata: metadata,
      ));
    });
    _scrollToBottom();
  }

  /// 发送消息
  void _sendMessage(String text) {
    if (text.isEmpty) return;

    _addUserMessage(text);
    _processMessage(text);
  }

  /// 处理消息
  Future<void> _processMessage(String text) async {
    setState(() => _isProcessing = true);

    // 添加加载消息
    final loadingId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages.add(ChatMessage(
        id: loadingId,
        type: ChatMessageType.assistant,
        content: '',
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });
    _scrollToBottom();

    // 模拟处理延迟
    await Future.delayed(const Duration(seconds: 1));

    // 移除加载消息
    setState(() {
      _messages.removeWhere((m) => m.id == loadingId);
    });

    // 模拟AI响应
    final response = _simulateAIResponse(text);
    _addAssistantMessage(response['message']!, metadata: response['metadata'] as Map<String, dynamic>?);

    setState(() => _isProcessing = false);
  }

  /// 模拟AI响应
  Map<String, dynamic> _simulateAIResponse(String input) {
    // 简单的关键词匹配模拟
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元)?').firstMatch(input);

    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(1)!) ?? 0;
      String category = '其他';

      if (input.contains('餐') || input.contains('饭') || input.contains('吃')) {
        category = '餐饮';
      } else if (input.contains('车') || input.contains('打车') || input.contains('地铁')) {
        category = '交通';
      } else if (input.contains('买') || input.contains('购')) {
        category = '购物';
      }

      return {
        'message': '好的，已帮您记录这笔支出 ✅\n\n金额：¥${amount.toStringAsFixed(2)}\n分类：$category\n\n还有其他要记的吗？',
        'metadata': {
          'amount': amount.toStringAsFixed(2),
          'category': category,
        },
      };
    }

    if (input.contains('花了多少') || input.contains('支出')) {
      return _generateSpendingResponse();
    }

    if (input.contains('钱龄')) {
      return _generateMoneyAgeResponse();
    }

    return {
      'message': '抱歉，我没有完全理解您的意思 😅\n\n您可以试试：\n• "午餐35块"\n• "打车20元"\n• "今天花了多少钱"',
      'metadata': null,
    };
  }

  /// 开始录音
  void _startRecording() {
    HapticFeedback.mediumImpact();
    setState(() => _isRecording = true);
    _startWaveAnimation();
  }

  /// 停止录音
  void _stopRecording() {
    if (!_isRecording) return;

    setState(() => _isRecording = false);
    _stopWaveAnimation();

    // 模拟语音识别结果
    Future.delayed(const Duration(milliseconds: 500), () {
      _sendMessage('午餐花了35块');
    });
  }

  /// 开始波形动画
  void _startWaveAnimation() {
    _waveController.repeat();
    _waveController.addListener(() {
      if (_waveController.value >= 0.95 && _isRecording) {
        setState(() {
          for (int i = 0; i < _waveHeights.length; i++) {
            _waveHeights[i] = 0.2 + Random().nextDouble() * 0.6;
          }
        });
      }
    });
  }

  /// 停止波形动画
  void _stopWaveAnimation() {
    _waveController.stop();
    _waveController.reset();
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

  /// 生成支出查询响应（使用真实数据）
  Map<String, dynamic> _generateSpendingResponse() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 今日支出
    final todayExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == today.year &&
        t.date.month == today.month &&
        t.date.day == today.day).toList();

    // 昨日支出
    final yesterdayExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == yesterday.year &&
        t.date.month == yesterday.month &&
        t.date.day == yesterday.day).toList();

    final todayTotal = todayExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final yesterdayTotal = yesterdayExpenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 按分类汇总
    final categoryTotals = <String, double>{};
    for (final t in todayExpenses) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // 排序并生成分类明细
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoryDetails = sortedCategories.take(3).map((e) {
      final category = DefaultCategories.findById(e.key);
      final emoji = _getCategoryEmoji(e.key);
      return '$emoji ${category?.localizedName ?? e.key} ¥${e.value.toStringAsFixed(2)}';
    }).join('\n');

    // 与昨日比较
    String comparison = '';
    if (yesterdayTotal > 0) {
      final diff = yesterdayTotal - todayTotal;
      if (diff > 0) {
        comparison = '\n\n比昨天少花了 ¥${diff.toStringAsFixed(2)} 呢！';
      } else if (diff < 0) {
        comparison = '\n\n比昨天多花了 ¥${(-diff).toStringAsFixed(2)}';
      }
    }

    if (todayExpenses.isEmpty) {
      return {
        'message': '今天还没有支出记录哦！\n\n开始记录您的第一笔支出吧 ✨',
        'metadata': null,
      };
    }

    return {
      'message': '今天您一共支出了 ¥${todayTotal.toStringAsFixed(2)}，包括：\n\n$categoryDetails$comparison',
      'metadata': null,
    };
  }

  /// 生成钱龄查询响应（使用真实数据）
  Map<String, dynamic> _generateMoneyAgeResponse() {
    final moneyAge = ref.read(moneyAgeProvider);
    final avgAge = moneyAge.days;
    final level = moneyAge.statusText;

    String levelEmoji;
    switch (moneyAge.status) {
      case MoneyAgeStatus.excellent:
        levelEmoji = '🌟';
        break;
      case MoneyAgeStatus.good:
        levelEmoji = '✨';
        break;
      case MoneyAgeStatus.fair:
        levelEmoji = '📊';
        break;
      case MoneyAgeStatus.poor:
        levelEmoji = '💪';
        break;
    }

    return {
      'message': '您当前的钱龄是 $avgAge天，处于"$level"水平 $levelEmoji\n\n这意味着您花的钱平均是$avgAge天前赚的。\n\n想了解如何提升钱龄吗？',
      'metadata': null,
    };
  }

  /// 获取分类对应的emoji
  String _getCategoryEmoji(String categoryId) {
    final emojiMap = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎮',
      'medical': '💊',
      'education': '📚',
      'housing': '🏠',
      'utilities': '💡',
      'communication': '📱',
      'other': '📋',
    };
    return emojiMap[categoryId] ?? '📋';
  }
}
