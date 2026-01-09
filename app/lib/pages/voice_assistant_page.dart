import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 6.20 语音智能客服页面
/// 提供全方位的语音交互帮助，解答用户关于记账、预算、钱龄等问题
class VoiceAssistantPage extends ConsumerStatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  ConsumerState<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends ConsumerState<VoiceAssistantPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _messages.add({
      'type': 'assistant',
      'content': '您好！我是您的智能记账助手 🤖\n\n我可以帮您：\n• 快速记账\n• 查询消费统计\n• 分析财务状况\n• 提供省钱建议\n\n有什么我可以帮您的吗？',
      'time': DateTime.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                  l10n.voiceAssistant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.online,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptions,
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
          // 功能快捷入口
          _buildQuickActions(l10n),
          // 输入区域
          _buildInputArea(l10n),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      color: isUser ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  // 如果有附加组件
                  if (message['widget'] != null) ...[
                    const SizedBox(height: 12),
                    message['widget'],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations l10n) {
    final actions = [
      {
        'icon': Icons.add_circle_outline,
        'label': l10n.quickBookkeep,
        'color': AppTheme.primaryColor,
      },
      {
        'icon': Icons.pie_chart_outline,
        'label': l10n.viewStats,
        'color': AppTheme.successColor,
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'label': l10n.budgetQuery,
        'color': AppTheme.warningColor,
      },
      {
        'icon': Icons.lightbulb_outline,
        'label': l10n.getSuggestion,
        'color': AppTheme.infoColor,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: actions.map((action) {
            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleQuickAction(action['label'] as String),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          action['icon'] as IconData,
                          size: 18,
                          color: action['color'] as Color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          action['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: action['color'] as Color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 文字输入
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.askAnything,
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _sendMessage,
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
                width: _isRecording ? 56 : 48,
                height: _isRecording ? 56 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.8)]
                        : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(_isRecording ? 28 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppTheme.errorColor : AppTheme.primaryColor)
                          .withValues(alpha: 0.4),
                      blurRadius: _isRecording ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: _isRecording ? 26 : 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    _addUserMessage(action);

    // 模拟回复
    Future.delayed(const Duration(milliseconds: 800), () {
      String response;
      switch (action) {
        case '快速记账':
          response = '好的，请告诉我您要记录的消费内容。\n\n比如："午餐花了35块"或者"打车去公司20元"';
          break;
        case '查看统计':
          response = '📊 本月消费统计\n\n总支出：¥3,280.50\n总收入：¥8,000.00\n\n支出分布：\n🍜 餐饮 28%\n🚗 交通 15%\n🛒 购物 35%\n🎬 娱乐 12%\n📦 其他 10%\n\n比上月减少了 12%，继续保持！';
          break;
        case '预算查询':
          response = '💰 本月预算情况\n\n总预算：¥5,000\n已使用：¥2,819.50 (56%)\n剩余：¥2,180.50\n\n⚠️ 购物预算已用 81%，建议控制';
          break;
        case '获取建议':
          response = '💡 根据您的消费习惯，我有以下建议：\n\n1. 餐饮支出偏高，可以考虑多做家常菜\n2. 交通费用稳定，保持良好\n3. 建议设置购物冷静期，减少冲动消费\n4. 可以考虑每月固定存款500元\n\n需要我帮您设置预算提醒吗？';
          break;
        default:
          response = '好的，我来帮您处理这个问题。';
      }

      _addAssistantMessage(response);
    });
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    _addUserMessage(text);

    // 模拟AI回复
    Future.delayed(const Duration(milliseconds: 1000), () {
      _addAssistantMessage(_generateResponse(text));
    });
  }

  String _generateResponse(String input) {
    // 简单的关键词匹配
    if (input.contains('多少') || input.contains('花了')) {
      return '让我帮您查一下...\n\n今天您一共花了 ¥128.50\n\n包括：\n🍜 餐饮 ¥45.00\n🚗 交通 ¥38.50\n🛒 购物 ¥45.00';
    }

    if (input.contains('预算') || input.contains('还剩')) {
      return '本月预算还剩 ¥2,180.50\n\n按照目前的消费速度，到月底预算刚好够用 ✨';
    }

    if (input.contains('帮') || input.contains('记')) {
      return '好的，请告诉我消费金额和类别，我帮您记录。\n\n比如："午餐35块"';
    }

    return '好的，我已经收到您的问题。\n\n请问您是想要：\n1. 记一笔账\n2. 查看消费统计\n3. 获取省钱建议\n\n请告诉我您的需求~';
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add({
        'type': 'user',
        'content': content,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addAssistantMessage(String content, {Widget? widget}) {
    setState(() {
      _messages.add({
        'type': 'assistant',
        'content': content,
        'time': DateTime.now(),
        'widget': widget,
      });
    });
    _scrollToBottom();
  }

  void _startRecording() {
    setState(() => _isRecording = true);
  }

  void _stopRecording() {
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    // 模拟语音识别
    _sendMessage('今天花了多少钱？');
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

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('对话历史'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/voice-history');
              },
            ),
            // TODO: Implement these pages
            // ListTile(
            //   leading: const Icon(Icons.edit_note),
            //   title: const Text('编辑记录'),
            //   subtitle: const Text('查看语音编辑历史'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const VoiceEditRecordPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.undo),
            //   title: const Text('撤销操作'),
            //   subtitle: const Text('语音撤销最近的操作'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const VoiceUndoPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.timer),
            //   title: const Text('记录时间统计'),
            //   subtitle: const Text('查看语音记账效率'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const RecordingTimeStatsPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.gesture),
            //   title: const Text('手写输入'),
            //   subtitle: const Text('切换到手写记账'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const HandwritingRecognitionPage()),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.input),
            //   title: const Text('多模态输入'),
            //   subtitle: const Text('语音/手写/拍照/键盘'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const MultimodalInputPage()),
            //     );
            //   },
            // ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空对话'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _initializeChat();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('助手设置'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
