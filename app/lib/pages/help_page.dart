import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/app_info_provider.dart';

/// 帮助与反馈页面
class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  // 展开状态管理
  final Map<String, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final appInfo = ref.watch(appInfoSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助与反馈'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 快速入门
            _buildSection(
              'quick_start',
              icon: Icons.rocket_launch,
              iconColor: AppColors.primary,
              title: '快速入门',
              children: [
                _buildHelpItem(
                  '1. 添加第一笔记账',
                  '点击首页的"快速记账"按钮，选择收入或支出类型，输入金额和分类，即可完成记账。',
                ),
                _buildHelpItem(
                  '2. 使用AI智能记账',
                  '• 拍照记账：拍摄小票或发票，AI自动识别金额和类目\n'
                  '• 语音记账：说出"午餐花了35元"，AI自动解析并记录',
                ),
                _buildHelpItem(
                  '3. 查看统计报表',
                  '点击首页的"报表分析"，查看收支趋势、分类占比等统计图表。',
                ),
                _buildHelpItem(
                  '4. 设置预算提醒',
                  '在"预算管理"中设置月度预算，超支时会收到提醒。',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 功能说明
            _buildSection(
              'features',
              icon: Icons.featured_play_list,
              iconColor: AppColors.income,
              title: '功能说明',
              children: [
                _buildFeatureItem(
                  Icons.flash_on,
                  '快速记账',
                  '手动输入记账信息，支持选择分类、账户、添加备注和标签。可设置为周期性交易自动记账。',
                ),
                _buildFeatureItem(
                  Icons.camera_alt,
                  '拍照记账',
                  '拍摄购物小票、发票或账单，AI自动识别商品名称、金额和日期，一键生成记账记录。',
                ),
                _buildFeatureItem(
                  Icons.mic,
                  '语音记账',
                  '使用语音描述支出或收入，如"今天打车花了30元"，AI智能解析并生成记账记录。',
                ),
                _buildFeatureItem(
                  Icons.analytics,
                  '报表分析',
                  '提供多维度统计分析：\n'
                  '• 收支趋势图：按日/周/月查看收支变化\n'
                  '• 分类占比：饼图展示各类支出比例\n'
                  '• 年度报告：全年财务总结与分析',
                ),
                _buildFeatureItem(
                  Icons.account_balance_wallet,
                  '账户管理',
                  '支持多账户管理：现金、银行卡、支付宝、微信等。可设置账户余额，支持转账操作。',
                ),
                _buildFeatureItem(
                  Icons.pie_chart,
                  '预算管理',
                  '设置月度总预算或分类预算，实时追踪预算使用情况，超支自动提醒。',
                ),
                _buildFeatureItem(
                  Icons.credit_card,
                  '信用卡管理',
                  '记录信用卡账单日、还款日，自动提醒还款，追踪信用卡消费。',
                ),
                _buildFeatureItem(
                  Icons.savings,
                  '储蓄目标',
                  '设置储蓄目标（如旅游基金、购车计划），追踪存款进度，激励达成目标。',
                ),
                _buildFeatureItem(
                  Icons.notifications,
                  '账单提醒',
                  '设置定期账单提醒（房租、水电费、会员订阅等），到期自动通知。',
                ),
                _buildFeatureItem(
                  Icons.repeat,
                  '周期记账',
                  '设置固定支出（工资、房租等）自动记账，无需重复手动输入。',
                ),
                _buildFeatureItem(
                  Icons.receipt_long,
                  '报销管理',
                  '标记可报销的支出，追踪报销状态，统计待报销金额。',
                ),
                _buildFeatureItem(
                  Icons.currency_exchange,
                  '多币种支持',
                  '支持多种货币记账，可在设置中切换默认货币和货币符号。',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 数据管理
            _buildSection(
              'data',
              icon: Icons.storage,
              iconColor: AppColors.transfer,
              title: '数据管理',
              children: [
                _buildHelpItem(
                  '数据备份',
                  '支持云端同步备份，登录账号后数据自动同步，换机无忧。',
                ),
                _buildHelpItem(
                  '数据导出',
                  '支持导出CSV格式文件，可在Excel中查看和分析。导出路径：设置 → 数据导出',
                ),
                _buildHelpItem(
                  '数据导入',
                  '支持从CSV文件导入历史记账数据，快速迁移其他记账软件的数据。',
                ),
                _buildHelpItem(
                  '数据安全',
                  '• 本地数据加密存储\n'
                  '• 支持应用锁（密码/指纹/面容）\n'
                  '• 云端数据传输加密',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 常见问题
            _buildSection(
              'faq',
              icon: Icons.help_outline,
              iconColor: AppColors.expense,
              title: '常见问题',
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
                  'A: 请检查：\n'
                  '1. 系统通知权限是否开启\n'
                  '2. 应用通知设置是否开启\n'
                  '3. 预算金额是否设置正确',
                ),
                _buildFaqItem(
                  'Q: 如何查看某个分类的历史记录？',
                  'A: 在"流水查询"页面，点击筛选按钮，选择对应分类即可筛选查看。',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 使用技巧
            _buildSection(
              'tips',
              icon: Icons.lightbulb,
              iconColor: Colors.amber,
              title: '使用技巧',
              children: [
                _buildTipItem(
                  '记账习惯养成',
                  '建议每次消费后立即记账，或每天固定时间统一记录。使用周期记账功能减少重复操作。',
                ),
                _buildTipItem(
                  '善用标签功能',
                  '为记录添加标签（如#报销、#旅行、#聚餐），方便后续筛选和统计特定场景的支出。',
                ),
                _buildTipItem(
                  '定期查看报表',
                  '每周或每月查看统计报表，了解消费结构，发现不合理支出，优化消费习惯。',
                ),
                _buildTipItem(
                  '合理设置预算',
                  '根据过往消费数据设置预算，建议预留10%-20%弹性空间，避免预算过紧造成压力。',
                ),
                _buildTipItem(
                  '多账户管理',
                  '为不同用途创建不同账户，如"日常消费"、"储蓄"、"投资"，便于资金分配管理。',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 联系我们
            _buildSection(
              'contact',
              icon: Icons.contact_support,
              iconColor: Colors.blue,
              title: '联系我们',
              initiallyExpanded: true,
              children: [
                _buildContactItem(
                  Icons.email,
                  '客服邮箱',
                  'support@ai-bookkeeping.com',
                  '工作日24小时内回复',
                ),
                _buildContactItem(
                  Icons.bug_report,
                  '问题反馈',
                  'feedback@ai-bookkeeping.com',
                  '发送问题描述和截图，我们会尽快处理',
                ),
                _buildContactItem(
                  Icons.rate_review,
                  '功能建议',
                  'ideas@ai-bookkeeping.com',
                  '欢迎提交您的宝贵建议',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 版本信息
            Center(
              child: Column(
                children: [
                  Text(
                    'AI智能记账 ${appInfo.displayVersion}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '感谢您的使用与支持',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String key, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    _expandedSections[key] ??= initiallyExpanded;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expandedSections[key]!,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedSections[key] = expanded;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
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

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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

  Widget _buildTipItem(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    IconData icon,
    String title,
    String value,
    String hint,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            color: AppColors.textSecondary,
            onPressed: () {
              // 复制到剪贴板
              _copyToClipboard(value);
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    // 使用 Clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
