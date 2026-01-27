import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/app_info_provider.dart';
import '../services/help_content_service.dart';
import '../models/help_content.dart';
import '../widgets/help/help_search_widget.dart';
import '../widgets/help/module_list_widget.dart';
import '../widgets/help/page_help_detail_widget.dart';

/// 帮助与反馈页面
class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HelpContentService _helpService = HelpContentService();
  List<HelpContent> _searchResults = [];
  bool _isSearching = false;

  // 模块名称映射
  final Map<String, String> _moduleNames = {
    'home': '首页与快速记账',
    'money_age': '钱龄分析',
    'budget': '零基预算',
    'accounts': '账户管理',
    'categories': '智能分类',
    'statistics': '统计报表',
    'settings': '设置中心',
    'voice': '语音交互',
    'ai': 'AI智能中心',
    'import_export': '导入导出',
    'help_feedback': '帮助与反馈',
    'security': '安全与隐私',
    'habits': '习惯培养',
    'impulse_control': '冲动防护',
    'family': '家庭账本',
    'growth': '增长与分享',
    'data_sync': '数据联动',
    'errors': '异常处理',
    'monitoring': '系统监控',
    'bill_reminders': '账单提醒',
  };

  // 模块图标映射
  final Map<String, IconData> _moduleIcons = {
    'home': Icons.home,
    'money_age': Icons.timeline,
    'budget': Icons.account_balance_wallet,
    'accounts': Icons.account_balance,
    'categories': Icons.category,
    'statistics': Icons.analytics,
    'settings': Icons.settings,
    'voice': Icons.mic,
    'ai': Icons.psychology,
    'import_export': Icons.import_export,
    'help_feedback': Icons.help,
    'security': Icons.security,
    'habits': Icons.self_improvement,
    'impulse_control': Icons.shield,
    'family': Icons.family_restroom,
    'growth': Icons.trending_up,
    'data_sync': Icons.sync,
    'errors': Icons.error_outline,
    'monitoring': Icons.monitor_heart,
    'bill_reminders': Icons.notifications,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHelpContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpContent() async {
    try {
      await _helpService.preload();
      await _helpService.loadSearchHistory();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('加载帮助内容失败: $e');
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _searchResults = [];
      } else {
        _isSearching = true;
        _searchResults = _helpService.search(query);
        // 添加到搜索历史
        _helpService.addSearchHistory(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appInfo = ref.watch(appInfoSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助与反馈'),
        bottom: _isSearching
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '快速入门'),
                  Tab(text: '按模块浏览'),
                  Tab(text: '常见问题'),
                ],
              ),
      ),
      body: Column(
        children: [
          // 搜索栏
          HelpSearchWidget(
            onSearch: _onSearch,
            onResultTap: (content) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PageHelpDetailWidget(content: content),
                ),
              );
            },
          ),

          // 内容区域
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQuickStartTab(),
                      _buildModuleBrowserTab(),
                      _buildFAQTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 搜索结果
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              '未找到相关内容',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final content = _searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(content.title),
            subtitle: Text(
              content.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PageHelpDetailWidget(content: content),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // 快速入门标签页
  Widget _buildQuickStartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '欢迎使用AI智能记账',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '以下是一些快速入门教程，帮助您快速上手',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildQuickStartItem(
            Icons.add_circle,
            '添加第一笔记账',
            '点击首页的"快速记账"按钮，选择收入或支出类型，输入金额和分类，即可完成记账。',
            AppColors.primary,
          ),
          _buildQuickStartItem(
            Icons.mic,
            '使用语音记账',
            '说出"午餐花了35元"，AI自动解析并记录，让记账更加便捷。',
            AppColors.income,
          ),
          _buildQuickStartItem(
            Icons.analytics,
            '查看统计报表',
            '点击首页的"报表分析"，查看收支趋势、分类占比等统计图表。',
            AppColors.transfer,
          ),
          _buildQuickStartItem(
            Icons.account_balance_wallet,
            '设置预算提醒',
            '在"预算管理"中设置月度预算，超支时会收到提醒。',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 按模块浏览标签页
  Widget _buildModuleBrowserTab() {
    final moduleContents = <String, List<HelpContent>>{};
    for (final module in _helpService.getAllModules()) {
      moduleContents[module] = _helpService.getContentsByModule(module);
    }

    return ModuleListWidget(
      moduleContents: moduleContents,
      moduleNames: _moduleNames,
      moduleIcons: _moduleIcons,
    );
  }

  // 常见问题标签页
  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFaqItem(
            'Q: 如何修改或删除已记录的账目？',
            'A: 在"流水查询"页面找到对应记录，点击进入详情，可以编辑或删除该记录。',
          ),
          _buildFaqItem(
            'Q: 拍照记账识别不准确怎么办？',
            'A: 请确保拍摄清晰、光线充足。识别结果可手动修改后保存。复杂票据建议手动记账。',
          ),
          _buildFaqItem(
            'Q: 语音记账无法识别？',
            'A: 请检查麦克风权限是否开启，确保网络连接正常。建议使用标准普通话，语速适中。',
          ),
          _buildFaqItem(
            'Q: 如何添加自定义分类？',
            'A: 进入设置 → 分类管理，点击右上角"+"添加新分类，可自定义图标和颜色。',
          ),
          _buildFaqItem(
            'Q: 数据同步失败怎么办？',
            'A: 请检查网络连接，确认已登录账号。如仍有问题，可尝试退出重新登录。',
          ),
          _buildFaqItem(
            'Q: 如何切换记账账本？',
            'A: 进入设置 → 账本管理，可创建多个账本（如个人账本、家庭账本），点击切换。',
          ),
          _buildFaqItem(
            'Q: 预算提醒没有收到？',
            'A: 请检查：\n1. 系统通知权限是否开启\n2. 应用通知设置是否开启\n3. 预算金额是否设置正确',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
