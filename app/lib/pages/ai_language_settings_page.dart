import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'main_navigation.dart';

/// 8.06 AI语言设置页面
/// AI回复语言、语音识别语言设置
class AILanguageSettingsPage extends ConsumerStatefulWidget {
  const AILanguageSettingsPage({super.key});

  @override
  ConsumerState<AILanguageSettingsPage> createState() =>
      _AILanguageSettingsPageState();
}

class _AILanguageSettingsPageState
    extends ConsumerState<AILanguageSettingsPage> {
  String _aiReplyLanguage = 'follow_app';
  // ignore: unused_field
  final String _voiceRecognitionLanguage = 'auto';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回首页而不是简单的pop
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
              (route) => false,
            );
          },
        ),
        title: Text(
          l10n.aiLanguageSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAIInfoCard(),
            _buildAIReplyLanguageSection(l10n),
            _buildVoiceRecognitionSection(l10n),
            _buildExampleSection(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF9370DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI智能助手',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '语音识别与内容生成',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI助手会根据您的语言设置，用您熟悉的语言进行交流和生成内容。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReplyLanguageSection(AppLocalizations l10n) {
    final options = [
      {
        'value': 'follow_app',
        'emoji': '🔄',
        'title': '跟随应用语言',
        'subtitle': '当前：简体中文',
      },
      {
        'value': 'zh_CN',
        'emoji': '🇨🇳',
        'title': '始终使用简体中文',
        'subtitle': null,
      },
      {
        'value': 'en_US',
        'emoji': '🇺🇸',
        'title': '始终使用English',
        'subtitle': null,
      },
      {
        'value': 'ja_JP',
        'emoji': '🇯🇵',
        'title': '始終使用日本語',
        'subtitle': null,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiReplyLanguage,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isLast = index == options.length - 1;
                final isSelected = _aiReplyLanguage == option['value'];

                return InkWell(
                  onTap: () =>
                      setState(() => _aiReplyLanguage = option['value']!),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: !isLast
                          ? Border(
                              bottom: BorderSide(
                                color: AppTheme.dividerColor,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          option['emoji']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['title']!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (option['subtitle'] != null)
                                Text(
                                  option['subtitle']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                      ],
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

  Widget _buildVoiceRecognitionSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.voiceRecognitionLanguage,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.mic, color: AppTheme.primaryColor),
              title: const Text('自动检测'),
              subtitle: Text(
                '支持中/英/日/韩混合识别',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              trailing: Icon(
                Icons.check,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleSection(AppLocalizations l10n) {
    final examples = [
      {
        'label': '财务洞察',
        'content': '"本月餐饮支出增长15%，建议关注外卖消费频率。"',
      },
      {
        'label': '省钱建议',
        'content': '"您附近500米内有3家优惠餐厅，可节省约¥45。"',
      },
      {
        'label': '语音识别',
        'content': '"午餐花了35块" → 餐饮 ¥35.00',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI内容本地化示例',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: examples.map((example) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        example['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          example['content']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
