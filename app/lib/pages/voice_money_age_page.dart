import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 聊天消息类型
enum MoneyAgeChatType {
  user,
  assistant,
}

/// 聊天消息
class MoneyAgeChatMessage {
  final String id;
  final MoneyAgeChatType type;
  final String content;
  final Widget? widget;
  final DateTime timestamp;

  MoneyAgeChatMessage({
    required this.id,
    required this.type,
    required this.content,
    this.widget,
    required this.timestamp,
  });
}

/// 6.13 语音查询钱龄页面
class VoiceMoneyAgePage extends ConsumerStatefulWidget {
  const VoiceMoneyAgePage({super.key});

  @override
  ConsumerState<VoiceMoneyAgePage> createState() => _VoiceMoneyAgePageState();
}

class _VoiceMoneyAgePageState extends ConsumerState<VoiceMoneyAgePage> {
  final List<MoneyAgeChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // 模拟对话
    _messages.addAll([
      MoneyAgeChatMessage(
        id: '1',
        type: MoneyAgeChatType.user,
        content: '我的钱龄多少天？',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      MoneyAgeChatMessage(
        id: '2',
        type: MoneyAgeChatType.assistant,
        content: '',
        widget: _buildMoneyAgeCard(),
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      MoneyAgeChatMessage(
        id: '3',
        type: MoneyAgeChatType.user,
        content: '上次买手机花的是什么时候的钱？',
        timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
      MoneyAgeChatMessage(
        id: '4',
        type: MoneyAgeChatType.assistant,
        content: '',
        widget: _buildTransactionTraceCard(),
        timestamp: DateTime.now(),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBF3FF), Color(0xFFFAFBFC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部状态栏
              _buildTopBar(l10n),
              // 对话区域
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildChatBubble(_messages[index]);
                  },
                ),
              ),
              // 快捷问题
              _buildQuickQuestions(l10n),
              // 输入区域
              _buildInputArea(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            l10n?.moneyAgeQuery ?? '钱龄查询',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildChatBubble(MoneyAgeChatMessage message) {
    final isUser = message.type == MoneyAgeChatType.user;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: message.widget != null
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.widget ??
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 14,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建钱龄卡片
  Widget _buildMoneyAgeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.access_time,
              color: AppTheme.successColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              '钱龄查询结果',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 钱龄显示卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.successColor.withValues(alpha: 0.2),
                AppTheme.successColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '当前钱龄',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '42',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              Text(
                '天',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '良好 Lv.4',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '您当前的钱龄是42天，处于良好水平。这意味着您花的钱平均是42天前赚的，有较好的财务缓冲能力。',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  /// 构建交易追溯卡片
  Widget _buildTransactionTraceCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.smartphone,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              '交易资金追溯',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 交易信息
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'iPhone 15 Pro',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '-¥7,999',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.expenseColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(
            '12月28日 · 数码',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '这笔消费的钱龄是38天。资金主要来自：',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppTheme.successColor,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• 11月工资 (¥6,500) - 43天前',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• 11月奖金 (¥1,499) - 35天前',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建快捷问题
  Widget _buildQuickQuestions(AppLocalizations? l10n) {
    final questions = [
      '如何提升钱龄？',
      '本月钱龄变化',
      '什么拉低了钱龄',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.youCanAsk ?? '您还可以问：',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions.map((q) {
              return Material(
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
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                l10n?.continueAsking ?? '继续提问...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5A85DD),
                    AppTheme.primaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (!_isRecording) {
      // 模拟语音识别结果
      _sendMessage('如何提升钱龄？');
    }
  }

  void _sendMessage(String text) {
    setState(() {
      _messages.add(MoneyAgeChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MoneyAgeChatType.user,
        content: text,
        timestamp: DateTime.now(),
      ));
    });

    // 模拟回复
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add(MoneyAgeChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MoneyAgeChatType.assistant,
          content: '要提升钱龄，您可以：\n\n1️⃣ 延迟非必要消费\n2️⃣ 建立应急储蓄金\n3️⃣ 减少冲动消费\n4️⃣ 优先使用"老钱"消费\n\n坚持一个月，您的钱龄就能明显提升！',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });

    _scrollToBottom();
  }

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
}
