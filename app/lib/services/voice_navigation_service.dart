import 'package:flutter/foundation.dart';

/// 语音页面导航服务
///
/// 支持通过语音指令导航到APP的237个页面
/// 对应设计文档：第18.4节 智能语音导航模块
///
/// 页面统计（20个模块，237页）：
/// - 首页与快速记账: 6页
/// - 钱龄分析: 11页
/// - 零基预算: 12页
/// - 账户管理: 9页
/// - 智能分类: 7页
/// - 统计报表: 12页
/// - 设置中心: 33页
/// - 语音交互: 21页
/// - AI智能中心: 10页
/// - 导入导出: 18页
/// - 帮助与反馈: 8页
/// - 安全与隐私: 7页
/// - 习惯培养: 20页
/// - 冲动防护: 6页
/// - 家庭账本: 16页
/// - 增长与分享: 12页
/// - 数据联动: 5页
/// - 异常处理: 10页
/// - 系统监控: 6页
/// - 账单提醒: 8页
///
/// 使用示例：
/// ```dart
/// final service = VoiceNavigationService();
/// final result = service.parseNavigation('打开钱龄分析');
/// if (result.success) {
///   Navigator.pushNamed(context, result.route!);
/// }
/// ```
class VoiceNavigationService extends ChangeNotifier {
  /// 导航历史
  final List<NavigationRecord> _history = [];

  /// 最大历史记录数
  static const int maxHistorySize = 20;

  /// 页面路由配置（20个模块，237个页面）
  static final Map<String, PageConfig> _pageConfigs = {
    // ═══════════════════════════════════════════════════════════════
    // 模块1：首页与快速记账（6页）
    // ═══════════════════════════════════════════════════════════════
    '/home': PageConfig(
      route: '/home',
      name: '首页',
      module: '首页与快速记账',
      aliases: ['主页', '首页', '回到首页', '返回首页'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/quick-add': PageConfig(
      route: '/quick-add',
      name: '快速记账',
      module: '首页与快速记账',
      aliases: ['记账', '快速记账', '添加记录', '记一笔'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice-input': PageConfig(
      route: '/voice-input',
      name: '语音记账',
      module: '首页与快速记账',
      aliases: ['语音记账', '说一笔', '语音输入'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/camera-input': PageConfig(
      route: '/camera-input',
      name: '拍照记账',
      module: '首页与快速记账',
      aliases: [
        '拍照记账', '拍一下', '扫描票据', '拍照',
        '扫描小票', '识别小票', '扫描发票', '识别发票',
        '扫描账单', '识别账单', '拍照识别', '识别图片',
        '截图识别', '识别截图', '导入截图',
      ],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/transaction-list': PageConfig(
      route: '/transaction-list',
      name: '交易列表',
      module: '首页与快速记账',
      aliases: ['交易记录', '账单列表', '消费记录', '看看账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/search': PageConfig(
      route: '/search',
      name: '搜索',
      module: '首页与快速记账',
      aliases: ['搜索', '查找', '找一下'],
      voiceAdaptation: VoiceAdaptation.high,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块2：钱龄分析（11页）
    // ═══════════════════════════════════════════════════════════════
    '/money-age': PageConfig(
      route: '/money-age',
      name: '钱龄总览',
      module: '钱龄分析',
      aliases: ['钱龄', '钱龄分析', '资金年龄', '钱龄总览'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/money-age/dashboard': PageConfig(
      route: '/money-age/dashboard',
      name: '钱龄仪表盘',
      module: '钱龄分析',
      aliases: ['钱龄仪表盘', '钱龄看板'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/money-age/trend': PageConfig(
      route: '/money-age/trend',
      name: '钱龄趋势',
      module: '钱龄分析',
      aliases: ['钱龄趋势', '钱龄变化', '趋势图'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/money-age/influence': PageConfig(
      route: '/money-age/influence',
      name: '影响因素',
      module: '钱龄分析',
      aliases: ['影响因素', '钱龄影响'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/money-age/resource-pool': PageConfig(
      route: '/money-age/resource-pool',
      name: '资源池详情',
      module: '钱龄分析',
      aliases: ['资源池', '资金池'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/money-age/health': PageConfig(
      route: '/money-age/health',
      name: '健康等级',
      module: '钱龄分析',
      aliases: ['健康等级', '钱龄健康', '财务健康'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/money-age/prediction': PageConfig(
      route: '/money-age/prediction',
      name: '钱龄预测',
      module: '钱龄分析',
      aliases: ['钱龄预测', '预测分析'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/money-age/suggestion': PageConfig(
      route: '/money-age/suggestion',
      name: '优化建议',
      module: '钱龄分析',
      aliases: ['优化建议', '钱龄建议', '改善建议'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/money-age/history': PageConfig(
      route: '/money-age/history',
      name: '历史回顾',
      module: '钱龄分析',
      aliases: ['钱龄历史', '历史记录'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/money-age/comparison': PageConfig(
      route: '/money-age/comparison',
      name: '钱龄对比',
      module: '钱龄分析',
      aliases: ['钱龄对比', '对比分析'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/money-age/settings': PageConfig(
      route: '/money-age/settings',
      name: '钱龄设置',
      module: '钱龄分析',
      aliases: ['钱龄设置', '策略设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块3：零基预算（12页）
    // ═══════════════════════════════════════════════════════════════
    '/budget': PageConfig(
      route: '/budget',
      name: '预算总览',
      module: '零基预算',
      aliases: ['预算', '预算总览', '看看预算'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/vault-list': PageConfig(
      route: '/budget/vault-list',
      name: '小金库列表',
      module: '零基预算',
      aliases: ['小金库', '金库列表', '所有金库'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/vault-detail': PageConfig(
      route: '/budget/vault-detail',
      name: '小金库详情',
      module: '零基预算',
      aliases: ['金库详情', '小金库详情'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/budget/vault-create': PageConfig(
      route: '/budget/vault-create',
      name: '创建小金库',
      module: '零基预算',
      aliases: ['新建金库', '创建小金库', '添加金库'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/allocation': PageConfig(
      route: '/budget/allocation',
      name: '资金分配',
      module: '零基预算',
      aliases: ['资金分配', '分配资金', '预算分配'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/smart-suggest': PageConfig(
      route: '/budget/smart-suggest',
      name: '智能建议',
      module: '零基预算',
      aliases: ['智能建议', '预算建议', '分配建议'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/vault-ai-suggestion': PageConfig(
      route: '/budget/vault-ai-suggestion',
      name: '小金库AI建议',
      module: '零基预算',
      aliases: ['小金库建议', '金库AI建议', '智能分配建议'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/budget/carryover': PageConfig(
      route: '/budget/carryover',
      name: '预算结转',
      module: '零基预算',
      aliases: ['预算结转', '结转设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/budget/alert': PageConfig(
      route: '/budget/alert',
      name: '预算预警',
      module: '零基预算',
      aliases: ['预算预警', '超支预警', '预警设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/budget/history': PageConfig(
      route: '/budget/history',
      name: '预算历史',
      module: '零基预算',
      aliases: ['预算历史', '历史预算'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/budget/analysis': PageConfig(
      route: '/budget/analysis',
      name: '预算分析',
      module: '零基预算',
      aliases: ['预算分析', '执行分析'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/budget/template': PageConfig(
      route: '/budget/template',
      name: '预算模板',
      module: '零基预算',
      aliases: ['预算模板', '模板管理'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/budget/settings': PageConfig(
      route: '/budget/settings',
      name: '预算设置',
      module: '零基预算',
      aliases: ['预算设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块4：账户管理（9页）
    // ═══════════════════════════════════════════════════════════════
    '/accounts': PageConfig(
      route: '/accounts',
      name: '账户列表',
      module: '账户管理',
      aliases: ['账户', '账户列表', '我的账户', '账本管理', '账本', '账户管理'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/detail': PageConfig(
      route: '/accounts/detail',
      name: '账户详情',
      module: '账户管理',
      aliases: ['账户详情'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/accounts/create': PageConfig(
      route: '/accounts/create',
      name: '添加账户',
      module: '账户管理',
      aliases: ['添加账户', '新建账户', '创建账户'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/transfer': PageConfig(
      route: '/accounts/transfer',
      name: '账户转账',
      module: '账户管理',
      aliases: ['转账', '账户转账', '内部转账'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/balance': PageConfig(
      route: '/accounts/balance',
      name: '余额调整',
      module: '账户管理',
      aliases: ['余额调整', '调整余额', '校准余额'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/accounts/assets': PageConfig(
      route: '/accounts/assets',
      name: '资产概览',
      module: '账户管理',
      aliases: ['资产', '资产概览', '总资产'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/liabilities': PageConfig(
      route: '/accounts/liabilities',
      name: '负债概览',
      module: '账户管理',
      aliases: ['负债', '负债概览', '总负债'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/net-worth': PageConfig(
      route: '/accounts/net-worth',
      name: '净资产',
      module: '账户管理',
      aliases: ['净资产', '净值'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/accounts/settings': PageConfig(
      route: '/accounts/settings',
      name: '账户设置',
      module: '账户管理',
      aliases: ['账户设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块5：智能分类（7页）
    // ═══════════════════════════════════════════════════════════════
    '/categories': PageConfig(
      route: '/categories',
      name: '分类管理',
      module: '智能分类',
      aliases: ['分类', '分类管理', '消费分类'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/categories/expense': PageConfig(
      route: '/categories/expense',
      name: '支出分类',
      module: '智能分类',
      aliases: ['支出分类'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/categories/income': PageConfig(
      route: '/categories/income',
      name: '收入分类',
      module: '智能分类',
      aliases: ['收入分类'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/categories/create': PageConfig(
      route: '/categories/create',
      name: '创建分类',
      module: '智能分类',
      aliases: ['创建分类', '添加分类', '新建分类'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/categories/smart': PageConfig(
      route: '/categories/smart',
      name: '智能分类',
      module: '智能分类',
      aliases: ['智能分类', 'AI分类'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/categories/rules': PageConfig(
      route: '/categories/rules',
      name: '分类规则',
      module: '智能分类',
      aliases: ['分类规则', '规则设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/categories/feedback': PageConfig(
      route: '/categories/feedback',
      name: '分类纠错',
      module: '智能分类',
      aliases: ['分类纠错', '纠正分类'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块6：统计报表（12页）
    // ═══════════════════════════════════════════════════════════════
    '/statistics': PageConfig(
      route: '/statistics',
      name: '统计总览',
      module: '统计报表',
      aliases: ['统计', '报表', '统计报表', '看看统计'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/expense': PageConfig(
      route: '/statistics/expense',
      name: '支出统计',
      module: '统计报表',
      aliases: ['支出统计', '消费统计', '花了多少'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/income': PageConfig(
      route: '/statistics/income',
      name: '收入统计',
      module: '统计报表',
      aliases: ['收入统计', '赚了多少'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/category': PageConfig(
      route: '/statistics/category',
      name: '分类统计',
      module: '统计报表',
      aliases: ['分类统计', '按分类看'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/trend': PageConfig(
      route: '/statistics/trend',
      name: '趋势分析',
      module: '统计报表',
      aliases: ['趋势分析', '消费趋势', '趋势图'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/comparison': PageConfig(
      route: '/statistics/comparison',
      name: '对比分析',
      module: '统计报表',
      aliases: ['对比分析', '月度对比', '同比环比'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/statistics/heatmap': PageConfig(
      route: '/statistics/heatmap',
      name: '消费热力图',
      module: '统计报表',
      aliases: ['热力图', '消费热力图'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/statistics/calendar': PageConfig(
      route: '/statistics/calendar',
      name: '日历视图',
      module: '统计报表',
      aliases: ['日历视图', '按日期看'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/statistics/weekly': PageConfig(
      route: '/statistics/weekly',
      name: '周报',
      module: '统计报表',
      aliases: ['周报', '本周统计'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/monthly': PageConfig(
      route: '/statistics/monthly',
      name: '月报',
      module: '统计报表',
      aliases: ['月报', '本月统计', '月度报告'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/annual': PageConfig(
      route: '/statistics/annual',
      name: '年报',
      module: '统计报表',
      aliases: ['年报', '年度报告', '今年统计'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/statistics/export': PageConfig(
      route: '/statistics/export',
      name: '导出报表',
      module: '统计报表',
      aliases: ['导出报表', '导出统计'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块7：设置中心（33页）
    // ═══════════════════════════════════════════════════════════════
    '/settings': PageConfig(
      route: '/settings',
      name: '设置',
      module: '设置中心',
      aliases: ['设置', '设置中心', '打开设置', '配置', '配置界面', '系统配置'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/settings/profile': PageConfig(
      route: '/settings/profile',
      name: '个人资料',
      module: '设置中心',
      aliases: ['个人资料', '我的资料', '个人信息'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/theme': PageConfig(
      route: '/settings/theme',
      name: '主题设置',
      module: '设置中心',
      aliases: ['主题', '主题设置', '换主题', '深色模式'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/settings/currency': PageConfig(
      route: '/settings/currency',
      name: '货币设置',
      module: '设置中心',
      aliases: ['货币设置', '默认货币'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/language': PageConfig(
      route: '/settings/language',
      name: '语言设置',
      module: '设置中心',
      aliases: ['语言设置', '切换语言'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/ai-language': PageConfig(
      route: '/settings/ai-language',
      name: 'AI语言设置',
      module: '设置中心',
      aliases: ['AI语言', 'AI语言设置', '智能语言'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/notification': PageConfig(
      route: '/settings/notification',
      name: '通知设置',
      module: '设置中心',
      aliases: ['通知设置', '提醒设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/reminder': PageConfig(
      route: '/settings/reminder',
      name: '记账提醒',
      module: '设置中心',
      aliases: ['记账提醒', '提醒我记账'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/settings/backup': PageConfig(
      route: '/settings/backup',
      name: '数据备份',
      module: '设置中心',
      aliases: ['数据备份', '备份数据', '云备份'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/sync': PageConfig(
      route: '/settings/sync',
      name: '同步设置',
      module: '设置中心',
      aliases: ['同步设置', '数据同步'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/voice': PageConfig(
      route: '/settings/voice',
      name: '语音设置',
      module: '设置中心',
      aliases: ['语音设置', '语音识别设置'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/settings/location': PageConfig(
      route: '/settings/location',
      name: '位置服务',
      module: '设置中心',
      aliases: ['位置服务', '位置设置', '定位设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/personalization': PageConfig(
      route: '/settings/personalization',
      name: '个性化',
      module: '设置中心',
      aliases: ['个性化', '个性化设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/accessibility': PageConfig(
      route: '/settings/accessibility',
      name: '无障碍',
      module: '设置中心',
      aliases: ['无障碍', '无障碍设置', '辅助功能'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/settings/about': PageConfig(
      route: '/settings/about',
      name: '关于',
      module: '设置中心',
      aliases: ['关于', '关于我们', '版本信息'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/developer': PageConfig(
      route: '/settings/developer',
      name: '开发者选项',
      module: '设置中心',
      aliases: ['开发者选项', '开发模式'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/ai': PageConfig(
      route: '/settings/ai',
      name: 'AI设置',
      module: '设置中心',
      aliases: ['AI设置', '智能设置', '人工智能设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/security': PageConfig(
      route: '/settings/security',
      name: '安全设置',
      module: '设置中心',
      aliases: ['安全设置', '安全'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/storage': PageConfig(
      route: '/settings/storage',
      name: '存储管理',
      module: '设置中心',
      aliases: ['存储管理', '存储', '空间管理'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/cache': PageConfig(
      route: '/settings/cache',
      name: '缓存清理',
      module: '设置中心',
      aliases: ['缓存清理', '清理缓存', '清除缓存'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/export': PageConfig(
      route: '/settings/export',
      name: '导出设置',
      module: '设置中心',
      aliases: ['导出设置', '数据导出设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/import': PageConfig(
      route: '/settings/import',
      name: '导入设置',
      module: '设置中心',
      aliases: ['导入设置', '数据导入设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/family': PageConfig(
      route: '/settings/family',
      name: '家庭设置',
      module: '设置中心',
      aliases: ['家庭设置', '家庭账本设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/budget': PageConfig(
      route: '/settings/budget',
      name: '预算设置',
      module: '设置中心',
      aliases: ['预算设置', '默认预算'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/category': PageConfig(
      route: '/settings/category',
      name: '分类设置',
      module: '设置中心',
      aliases: ['分类设置', '类别设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/account': PageConfig(
      route: '/settings/account',
      name: '账户设置',
      module: '设置中心',
      aliases: ['账户设置', '默认账户'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/template': PageConfig(
      route: '/settings/template',
      name: '模板设置',
      module: '设置中心',
      aliases: ['模板设置', '记账模板'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/shortcut': PageConfig(
      route: '/settings/shortcut',
      name: '快捷方式',
      module: '设置中心',
      aliases: ['快捷方式', '快捷设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/widget': PageConfig(
      route: '/settings/widget',
      name: '桌面小组件',
      module: '设置中心',
      aliases: ['桌面小组件', '小组件', 'Widget'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/gesture': PageConfig(
      route: '/settings/gesture',
      name: '手势设置',
      module: '设置中心',
      aliases: ['手势设置', '手势操作'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/display': PageConfig(
      route: '/settings/display',
      name: '显示设置',
      module: '设置中心',
      aliases: ['显示设置', '屏幕显示'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/font': PageConfig(
      route: '/settings/font',
      name: '字体设置',
      module: '设置中心',
      aliases: ['字体设置', '字体大小'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/settings/reset': PageConfig(
      route: '/settings/reset',
      name: '重置设置',
      module: '设置中心',
      aliases: ['重置设置', '恢复默认'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/settings/feedback': PageConfig(
      route: '/settings/feedback',
      name: '反馈设置',
      module: '设置中心',
      aliases: ['反馈设置', '触觉反馈'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块8：语音交互（21页）
    // ═══════════════════════════════════════════════════════════════
    '/voice': PageConfig(
      route: '/voice',
      name: '语音助手',
      module: '语音交互',
      aliases: ['语音助手', '语音', '对话助手'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/history': PageConfig(
      route: '/voice/history',
      name: '语音历史',
      module: '语音交互',
      aliases: ['语音历史', '对话历史'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/commands': PageConfig(
      route: '/voice/commands',
      name: '语音指令',
      module: '语音交互',
      aliases: ['语音指令', '指令列表', '能说什么'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/training': PageConfig(
      route: '/voice/training',
      name: '语音训练',
      module: '语音交互',
      aliases: ['语音训练', '声纹训练'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/feedback': PageConfig(
      route: '/voice/feedback',
      name: '语音纠错',
      module: '语音交互',
      aliases: ['语音纠错', '纠正识别'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/shortcuts': PageConfig(
      route: '/voice/shortcuts',
      name: '快捷指令',
      module: '语音交互',
      aliases: ['快捷指令', '自定义指令'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/wake-word': PageConfig(
      route: '/voice/wake-word',
      name: '唤醒词',
      module: '语音交互',
      aliases: ['唤醒词', '唤醒设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/voice/tts': PageConfig(
      route: '/voice/tts',
      name: '语音播报',
      module: '语音交互',
      aliases: ['语音播报', '播报设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/continuous': PageConfig(
      route: '/voice/continuous',
      name: '连续对话',
      module: '语音交互',
      aliases: ['连续对话', '多轮对话'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/ocr-result': PageConfig(
      route: '/voice/ocr-result',
      name: 'OCR结果',
      module: '语音交互',
      aliases: ['OCR结果', '识别结果'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/split': PageConfig(
      route: '/voice/split',
      name: 'AA分摊处理',
      module: '语音交互',
      aliases: ['AA分摊', '分摊处理', 'AA制', 'AA记账', '平摊'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/wakeup-settings': PageConfig(
      route: '/voice/wakeup-settings',
      name: '多模态唤醒设置',
      module: '语音交互',
      aliases: ['唤醒设置', '多模态唤醒', '唤醒方式', '快捷唤醒'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/timing': PageConfig(
      route: '/voice/timing',
      name: '流程时间',
      module: '语音交互',
      aliases: ['流程时间', '识别耗时'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/voice/accuracy': PageConfig(
      route: '/voice/accuracy',
      name: '准确率统计',
      module: '语音交互',
      aliases: ['准确率', '识别准确率'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/customer-service': PageConfig(
      route: '/voice/customer-service',
      name: '语音客服',
      module: '语音交互',
      aliases: ['语音客服', '客服'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/batch': PageConfig(
      route: '/voice/batch',
      name: '批量确认',
      module: '语音交互',
      aliases: ['批量确认', '批量记账'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/voice/context': PageConfig(
      route: '/voice/context',
      name: '上下文管理',
      module: '语音交互',
      aliases: ['上下文', '对话上下文'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/voice/dialect': PageConfig(
      route: '/voice/dialect',
      name: '方言设置',
      module: '语音交互',
      aliases: ['方言设置', '方言识别'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/noise': PageConfig(
      route: '/voice/noise',
      name: '降噪设置',
      module: '语音交互',
      aliases: ['降噪设置', '噪音过滤'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/voice/offline': PageConfig(
      route: '/voice/offline',
      name: '离线识别',
      module: '语音交互',
      aliases: ['离线识别', '离线语音'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/voice/model': PageConfig(
      route: '/voice/model',
      name: '模型管理',
      module: '语音交互',
      aliases: ['模型管理', '语音模型'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/voice/permission': PageConfig(
      route: '/voice/permission',
      name: '麦克风权限',
      module: '语音交互',
      aliases: ['麦克风权限', '录音权限'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块9：AI智能中心（10页）
    // ═══════════════════════════════════════════════════════════════
    '/ai': PageConfig(
      route: '/ai',
      name: 'AI助手',
      module: 'AI智能中心',
      aliases: ['AI助手', '智能助手', 'AI中心'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/insights': PageConfig(
      route: '/ai/insights',
      name: '智能洞察',
      module: 'AI智能中心',
      aliases: ['智能洞察', 'AI洞察', '消费洞察'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/suggestions': PageConfig(
      route: '/ai/suggestions',
      name: 'AI建议',
      module: 'AI智能中心',
      aliases: ['AI建议', '智能建议', '理财建议'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/anomaly': PageConfig(
      route: '/ai/anomaly',
      name: '异常检测',
      module: 'AI智能中心',
      aliases: ['异常检测', '异常消费', '检测异常'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/prediction': PageConfig(
      route: '/ai/prediction',
      name: '消费预测',
      module: 'AI智能中心',
      aliases: ['消费预测', '预测分析'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/learning': PageConfig(
      route: '/ai/learning',
      name: '学习进度',
      module: 'AI智能中心',
      aliases: ['学习进度', 'AI学习', '准确率'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/learning-curve': PageConfig(
      route: '/ai/learning-curve',
      name: 'AI学习曲线',
      module: 'AI智能中心',
      aliases: ['学习曲线', 'AI成长', '准确率曲线', '成长曲线'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/batch-training': PageConfig(
      route: '/ai/batch-training',
      name: '批量训练AI',
      module: 'AI智能中心',
      aliases: ['批量训练', 'AI训练', '训练AI', '批量校正'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/cost-monitor': PageConfig(
      route: '/ai/cost-monitor',
      name: 'AI成本监控',
      module: 'AI智能中心',
      aliases: ['AI成本', '成本监控', 'AI费用', '成本统计'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/learning-report': PageConfig(
      route: '/ai/learning-report',
      name: '智能学习报告',
      module: 'AI智能中心',
      aliases: ['学习报告', 'AI报告', '学习统计'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/profile': PageConfig(
      route: '/ai/profile',
      name: '用户画像',
      module: 'AI智能中心',
      aliases: ['用户画像', '我的画像'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/ai/dialog': PageConfig(
      route: '/ai/dialog',
      name: '对话记账',
      module: 'AI智能中心',
      aliases: ['对话记账', '聊天记账'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/ocr': PageConfig(
      route: '/ai/ocr',
      name: 'OCR识别',
      module: 'AI智能中心',
      aliases: ['OCR识别', '票据识别', '文字识别'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/ai/settings': PageConfig(
      route: '/ai/settings',
      name: 'AI设置',
      module: 'AI智能中心',
      aliases: ['AI设置', '智能设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块10：导入导出（18页）
    // ═══════════════════════════════════════════════════════════════
    '/import': PageConfig(
      route: '/import',
      name: '导入数据',
      module: '导入导出',
      aliases: ['导入', '导入数据', '导入账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/wechat': PageConfig(
      route: '/import/wechat',
      name: '微信账单',
      module: '导入导出',
      aliases: ['导入微信', '微信账单', '微信导入'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/alipay': PageConfig(
      route: '/import/alipay',
      name: '支付宝账单',
      module: '导入导出',
      aliases: ['导入支付宝', '支付宝账单', '支付宝导入'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/bank': PageConfig(
      route: '/import/bank',
      name: '银行账单',
      module: '导入导出',
      aliases: ['导入银行', '银行账单', '银行流水'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/review': PageConfig(
      route: '/import/review',
      name: '导入预览',
      module: '导入导出',
      aliases: ['导入预览', '预览导入'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/import/duplicate': PageConfig(
      route: '/import/duplicate',
      name: '去重处理',
      module: '导入导出',
      aliases: ['去重', '去重处理', '重复检测'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/export': PageConfig(
      route: '/export',
      name: '导出数据',
      module: '导入导出',
      aliases: ['导出', '导出数据', '导出账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/history': PageConfig(
      route: '/import/history',
      name: '导入历史',
      module: '导入导出',
      aliases: ['导入历史', '导入记录'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/import/creditcard': PageConfig(
      route: '/import/creditcard',
      name: '信用卡账单',
      module: '导入导出',
      aliases: ['信用卡账单', '导入信用卡'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/import/csv': PageConfig(
      route: '/import/csv',
      name: 'CSV导入',
      module: '导入导出',
      aliases: ['CSV导入', '表格导入'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/import/app': PageConfig(
      route: '/import/app',
      name: '其他APP',
      module: '导入导出',
      aliases: ['其他APP', '随手记导入', '记账APP导入'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/import/mapping': PageConfig(
      route: '/import/mapping',
      name: '字段映射',
      module: '导入导出',
      aliases: ['字段映射', '映射设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/import/conflict': PageConfig(
      route: '/import/conflict',
      name: '冲突处理',
      module: '导入导出',
      aliases: ['冲突处理', '导入冲突'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/export/excel': PageConfig(
      route: '/export/excel',
      name: 'Excel导出',
      module: '导入导出',
      aliases: ['Excel导出', '表格导出'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/export/pdf': PageConfig(
      route: '/export/pdf',
      name: 'PDF导出',
      module: '导入导出',
      aliases: ['PDF导出', '报告导出'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/export/template': PageConfig(
      route: '/export/template',
      name: '导出模板',
      module: '导入导出',
      aliases: ['导出模板', '模板选择'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/export/schedule': PageConfig(
      route: '/export/schedule',
      name: '定时导出',
      module: '导入导出',
      aliases: ['定时导出', '自动导出'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/export/share': PageConfig(
      route: '/export/share',
      name: '导出分享',
      module: '导入导出',
      aliases: ['导出分享', '分享导出'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块11：帮助与反馈（8页）
    // ═══════════════════════════════════════════════════════════════
    '/help': PageConfig(
      route: '/help',
      name: '帮助中心',
      module: '帮助与反馈',
      aliases: ['帮助', '帮助中心', '使用帮助'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/help/faq': PageConfig(
      route: '/help/faq',
      name: '常见问题',
      module: '帮助与反馈',
      aliases: ['常见问题', 'FAQ', '问题解答'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/help/tutorial': PageConfig(
      route: '/help/tutorial',
      name: '使用教程',
      module: '帮助与反馈',
      aliases: ['使用教程', '教程', '怎么用'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/help/newbie': PageConfig(
      route: '/help/newbie',
      name: '新手引导',
      module: '帮助与反馈',
      aliases: ['新手引导', '新手教程'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/feedback': PageConfig(
      route: '/feedback',
      name: '意见反馈',
      module: '帮助与反馈',
      aliases: ['反馈', '意见反馈', '提建议'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/feedback/bug': PageConfig(
      route: '/feedback/bug',
      name: '问题反馈',
      module: '帮助与反馈',
      aliases: ['问题反馈', '报告问题', '有问题'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/contact': PageConfig(
      route: '/contact',
      name: '联系我们',
      module: '帮助与反馈',
      aliases: ['联系我们', '联系客服'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/changelog': PageConfig(
      route: '/changelog',
      name: '更新日志',
      module: '帮助与反馈',
      aliases: ['更新日志', '版本更新', '更新了什么'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块12：安全与隐私（7页）
    // ═══════════════════════════════════════════════════════════════
    '/security': PageConfig(
      route: '/security',
      name: '安全中心',
      module: '安全与隐私',
      aliases: ['安全', '安全中心', '安全设置'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/security/password': PageConfig(
      route: '/security/password',
      name: '密码设置',
      module: '安全与隐私',
      aliases: ['密码设置', '修改密码', '设置密码'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/security/biometric': PageConfig(
      route: '/security/biometric',
      name: '生物识别',
      module: '安全与隐私',
      aliases: ['生物识别', '指纹', '面容'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/security/privacy': PageConfig(
      route: '/security/privacy',
      name: '隐私设置',
      module: '安全与隐私',
      aliases: ['隐私设置', '隐私'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/security/devices': PageConfig(
      route: '/security/devices',
      name: '设备管理',
      module: '安全与隐私',
      aliases: ['设备管理', '登录设备'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/security/permissions': PageConfig(
      route: '/security/permissions',
      name: '权限管理',
      module: '安全与隐私',
      aliases: ['权限管理', '权限设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/security/audit': PageConfig(
      route: '/security/audit',
      name: '安全日志',
      module: '安全与隐私',
      aliases: ['安全日志', '登录记录'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块13：习惯培养（20页）
    // ═══════════════════════════════════════════════════════════════
    '/habits': PageConfig(
      route: '/habits',
      name: '习惯中心',
      module: '习惯培养',
      aliases: ['习惯', '习惯中心', '习惯培养'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/subscription': PageConfig(
      route: '/habits/subscription',
      name: '订阅追踪',
      module: '习惯培养',
      aliases: ['订阅追踪', '订阅管理', '我的订阅'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/latte-factor': PageConfig(
      route: '/habits/latte-factor',
      name: '拿铁因子',
      module: '习惯培养',
      aliases: ['拿铁因子', '小额消费', '拿铁分析'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/insights': PageConfig(
      route: '/habits/insights',
      name: '消费洞察',
      module: '习惯培养',
      aliases: ['消费洞察', '消费分析'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/commitment': PageConfig(
      route: '/habits/commitment',
      name: '承诺机制',
      module: '习惯培养',
      aliases: ['承诺', '承诺机制', '我的承诺'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/streak': PageConfig(
      route: '/habits/streak',
      name: '连续记账',
      module: '习惯培养',
      aliases: ['连续记账', '打卡', '记账天数'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/health-score': PageConfig(
      route: '/habits/health-score',
      name: '健康评分',
      module: '习惯培养',
      aliases: ['健康评分', '财务健康', '健康分数'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/buffer': PageConfig(
      route: '/habits/buffer',
      name: '应急储备',
      module: '习惯培养',
      aliases: ['应急储备', '应急金', '备用金'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/debt': PageConfig(
      route: '/habits/debt',
      name: '债务管理',
      module: '习惯培养',
      aliases: ['债务管理', '债务健康', '还债计划'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/motivation': PageConfig(
      route: '/habits/motivation',
      name: '激励系统',
      module: '习惯培养',
      aliases: ['激励', '奖励', '成就'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/goals': PageConfig(
      route: '/habits/goals',
      name: '财务目标',
      module: '习惯培养',
      aliases: ['财务目标', '理财目标', '目标设定'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/savings': PageConfig(
      route: '/habits/savings',
      name: '储蓄追踪',
      module: '习惯培养',
      aliases: ['储蓄追踪', '存钱进度', '攒钱'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/challenge': PageConfig(
      route: '/habits/challenge',
      name: '省钱挑战',
      module: '习惯培养',
      aliases: ['省钱挑战', '挑战', '节约挑战'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/reward': PageConfig(
      route: '/habits/reward',
      name: '奖励兑换',
      module: '习惯培养',
      aliases: ['奖励兑换', '兑换奖励', '积分兑换'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/calendar': PageConfig(
      route: '/habits/calendar',
      name: '习惯日历',
      module: '习惯培养',
      aliases: ['习惯日历', '打卡日历', '记账日历'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/analysis': PageConfig(
      route: '/habits/analysis',
      name: '习惯分析',
      module: '习惯培养',
      aliases: ['习惯分析', '行为分析'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/reminder': PageConfig(
      route: '/habits/reminder',
      name: '习惯提醒',
      module: '习惯培养',
      aliases: ['习惯提醒', '打卡提醒'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/badge': PageConfig(
      route: '/habits/badge',
      name: '徽章墙',
      module: '习惯培养',
      aliases: ['徽章墙', '我的徽章', '成就墙'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/habits/freedom': PageConfig(
      route: '/habits/freedom',
      name: '财务自由',
      module: '习惯培养',
      aliases: ['财务自由', '自由进度', '自由计算器'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/habits/settings': PageConfig(
      route: '/habits/settings',
      name: '习惯设置',
      module: '习惯培养',
      aliases: ['习惯设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块14：冲动防护（6页）
    // ═══════════════════════════════════════════════════════════════
    '/impulse': PageConfig(
      route: '/impulse',
      name: '冲动防护',
      module: '冲动防护',
      aliases: ['冲动防护', '防冲动', '冲动消费'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/impulse/cooling': PageConfig(
      route: '/impulse/cooling',
      name: '冷静期',
      module: '冲动防护',
      aliases: ['冷静期', '冷静一下'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/impulse/wishlist': PageConfig(
      route: '/impulse/wishlist',
      name: '愿望清单',
      module: '冲动防护',
      aliases: ['愿望清单', '想买的', '心愿单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/impulse/planning': PageConfig(
      route: '/impulse/planning',
      name: '消费规划',
      module: '冲动防护',
      aliases: ['消费规划', '规划消费'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/impulse/confirm': PageConfig(
      route: '/impulse/confirm',
      name: '消费确认',
      module: '冲动防护',
      aliases: ['消费确认', '确认消费'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/impulse/history': PageConfig(
      route: '/impulse/history',
      name: '拦截历史',
      module: '冲动防护',
      aliases: ['拦截历史', '防护记录'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块15：家庭账本（16页）
    // ═══════════════════════════════════════════════════════════════
    '/family': PageConfig(
      route: '/family',
      name: '家庭账本',
      module: '家庭账本',
      aliases: ['家庭账本', '家庭', '共同记账'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/create': PageConfig(
      route: '/family/create',
      name: '创建家庭',
      module: '家庭账本',
      aliases: ['创建家庭', '新建家庭'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/members': PageConfig(
      route: '/family/members',
      name: '成员管理',
      module: '家庭账本',
      aliases: ['成员管理', '家庭成员', '管理成员'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/invite': PageConfig(
      route: '/family/invite',
      name: '邀请成员',
      module: '家庭账本',
      aliases: ['邀请成员', '邀请加入', '邀请家人'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/roles': PageConfig(
      route: '/family/roles',
      name: '角色权限',
      module: '家庭账本',
      aliases: ['角色权限', '权限设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/family/budget': PageConfig(
      route: '/family/budget',
      name: '家庭预算',
      module: '家庭账本',
      aliases: ['家庭预算', '共同预算'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/statistics': PageConfig(
      route: '/family/statistics',
      name: '家庭统计',
      module: '家庭账本',
      aliases: ['家庭统计', '家庭消费'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/split': PageConfig(
      route: '/family/split',
      name: 'AA分摊',
      module: '家庭账本',
      aliases: ['AA分摊', 'AA制', '分摊'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/settle': PageConfig(
      route: '/family/settle',
      name: '结算中心',
      module: '家庭账本',
      aliases: ['结算', '结算中心', '谁欠谁'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/comparison': PageConfig(
      route: '/family/comparison',
      name: '成员对比',
      module: '家庭账本',
      aliases: ['成员对比', '消费对比'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/family/leaderboard': PageConfig(
      route: '/family/leaderboard',
      name: '排行榜',
      module: '家庭账本',
      aliases: ['排行榜', '家庭排行'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/family/goals': PageConfig(
      route: '/family/goals',
      name: '共同目标',
      module: '家庭账本',
      aliases: ['共同目标', '家庭目标', '储蓄目标'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/family/privacy': PageConfig(
      route: '/family/privacy',
      name: '隐私控制',
      module: '家庭账本',
      aliases: ['隐私控制', '可见性'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/family/sync': PageConfig(
      route: '/family/sync',
      name: '数据同步',
      module: '家庭账本',
      aliases: ['数据同步', '同步状态'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/family/conflict': PageConfig(
      route: '/family/conflict',
      name: '冲突解决',
      module: '家庭账本',
      aliases: ['冲突解决', '数据冲突'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/family/settings': PageConfig(
      route: '/family/settings',
      name: '家庭设置',
      module: '家庭账本',
      aliases: ['家庭设置'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块16：增长与分享（12页）
    // ═══════════════════════════════════════════════════════════════
    '/growth': PageConfig(
      route: '/growth',
      name: '成长中心',
      module: '增长与分享',
      aliases: ['成长中心', '我的成长'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/nps': PageConfig(
      route: '/nps',
      name: 'NPS调查',
      module: '增长与分享',
      aliases: ['评价', '给个评价', '满意度'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/share': PageConfig(
      route: '/share',
      name: '分享中心',
      module: '增长与分享',
      aliases: ['分享', '分享中心', '分享账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/share/card': PageConfig(
      route: '/share/card',
      name: '分享卡片',
      module: '增长与分享',
      aliases: ['分享卡片', '生成卡片'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/invite': PageConfig(
      route: '/invite',
      name: '邀请好友',
      module: '增长与分享',
      aliases: ['邀请好友', '邀请', '推荐给朋友'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/invite/code': PageConfig(
      route: '/invite/code',
      name: '邀请码',
      module: '增长与分享',
      aliases: ['邀请码', '我的邀请码'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/invite/rewards': PageConfig(
      route: '/invite/rewards',
      name: '邀请奖励',
      module: '增长与分享',
      aliases: ['邀请奖励', '奖励'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/achievements': PageConfig(
      route: '/achievements',
      name: '成就徽章',
      module: '增长与分享',
      aliases: ['成就', '成就徽章', '我的成就'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/milestones': PageConfig(
      route: '/milestones',
      name: '里程碑',
      module: '增长与分享',
      aliases: ['里程碑', '我的里程碑'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/tips': PageConfig(
      route: '/tips',
      name: '理财技巧',
      module: '增长与分享',
      aliases: ['理财技巧', '小贴士', '技巧'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/stories': PageConfig(
      route: '/stories',
      name: '用户故事',
      module: '增长与分享',
      aliases: ['用户故事', '故事'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/review': PageConfig(
      route: '/review',
      name: '应用评价',
      module: '增长与分享',
      aliases: ['应用评价', '去评价', '给好评'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块17：数据联动（5页）
    // ═══════════════════════════════════════════════════════════════
    '/drill-down': PageConfig(
      route: '/drill-down',
      name: '数据下钻',
      module: '数据联动',
      aliases: ['数据下钻', '下钻分析', '详细分析'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/drill-down/category': PageConfig(
      route: '/drill-down/category',
      name: '分类详情',
      module: '数据联动',
      aliases: ['分类详情', '分类明细'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/drill-down/merchant': PageConfig(
      route: '/drill-down/merchant',
      name: '商家详情',
      module: '数据联动',
      aliases: ['商家详情', '商家明细'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/advanced-search': PageConfig(
      route: '/advanced-search',
      name: '高级搜索',
      module: '数据联动',
      aliases: ['高级搜索', '筛选', '高级筛选'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/filter': PageConfig(
      route: '/filter',
      name: '筛选条件',
      module: '数据联动',
      aliases: ['筛选条件', '过滤', '条件筛选'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块18：异常处理（10页）
    // ═══════════════════════════════════════════════════════════════
    '/error': PageConfig(
      route: '/error',
      name: '错误页面',
      module: '异常处理',
      aliases: ['错误', '出错了'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/error/network': PageConfig(
      route: '/error/network',
      name: '网络错误',
      module: '异常处理',
      aliases: ['网络错误', '没网了', '断网'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/error/sync': PageConfig(
      route: '/error/sync',
      name: '同步失败',
      module: '异常处理',
      aliases: ['同步失败', '同步出错'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/error/recognition': PageConfig(
      route: '/error/recognition',
      name: '识别失败',
      module: '异常处理',
      aliases: ['识别失败', '识别出错'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/conflict': PageConfig(
      route: '/conflict',
      name: '冲突处理',
      module: '异常处理',
      aliases: ['冲突处理', '数据冲突', '解决冲突'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/conflict/list': PageConfig(
      route: '/conflict/list',
      name: '冲突列表',
      module: '异常处理',
      aliases: ['冲突列表', '所有冲突'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/confirm/delete': PageConfig(
      route: '/confirm/delete',
      name: '删除确认',
      module: '异常处理',
      aliases: ['删除确认', '确认删除'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/confirm/overwrite': PageConfig(
      route: '/confirm/overwrite',
      name: '覆盖确认',
      module: '异常处理',
      aliases: ['覆盖确认', '确认覆盖'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/retry': PageConfig(
      route: '/retry',
      name: '重试操作',
      module: '异常处理',
      aliases: ['重试', '再试一次'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/fallback': PageConfig(
      route: '/fallback',
      name: '降级模式',
      module: '异常处理',
      aliases: ['降级模式', '离线模式'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块19：系统监控（6页）
    // ═══════════════════════════════════════════════════════════════
    '/monitor': PageConfig(
      route: '/monitor',
      name: '系统监控',
      module: '系统监控',
      aliases: ['系统监控', '监控', '系统状态'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/monitor/health': PageConfig(
      route: '/monitor/health',
      name: '健康检查',
      module: '系统监控',
      aliases: ['健康检查', '应用健康'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/monitor/performance': PageConfig(
      route: '/monitor/performance',
      name: '性能监控',
      module: '系统监控',
      aliases: ['性能监控', '性能'],
      voiceAdaptation: VoiceAdaptation.low,
    ),
    '/monitor/storage': PageConfig(
      route: '/monitor/storage',
      name: '存储状态',
      module: '系统监控',
      aliases: ['存储状态', '存储空间', '缓存'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/monitor/network': PageConfig(
      route: '/monitor/network',
      name: '网络状态',
      module: '系统监控',
      aliases: ['网络状态', '网络监控'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/monitor/report': PageConfig(
      route: '/monitor/report',
      name: '诊断报告',
      module: '系统监控',
      aliases: ['诊断报告', '系统诊断'],
      voiceAdaptation: VoiceAdaptation.low,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 模块20：账单提醒（8页）
    // ═══════════════════════════════════════════════════════════════
    '/bills': PageConfig(
      route: '/bills',
      name: '账单中心',
      module: '账单提醒',
      aliases: ['账单', '账单中心', '待付账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/upcoming': PageConfig(
      route: '/bills/upcoming',
      name: '即将到期',
      module: '账单提醒',
      aliases: ['即将到期', '快到期的'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/overdue': PageConfig(
      route: '/bills/overdue',
      name: '已逾期',
      module: '账单提醒',
      aliases: ['已逾期', '逾期账单', '过期了'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/credit-card': PageConfig(
      route: '/bills/credit-card',
      name: '信用卡还款',
      module: '账单提醒',
      aliases: ['信用卡还款', '还信用卡', '信用卡账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/subscription': PageConfig(
      route: '/bills/subscription',
      name: '订阅续费',
      module: '账单提醒',
      aliases: ['订阅续费', '订阅提醒'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/calendar': PageConfig(
      route: '/bills/calendar',
      name: '账单日历',
      module: '账单提醒',
      aliases: ['账单日历', '日历视图'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
    '/bills/create': PageConfig(
      route: '/bills/create',
      name: '添加账单',
      module: '账单提醒',
      aliases: ['添加账单', '新建账单', '记账单'],
      voiceAdaptation: VoiceAdaptation.high,
    ),
    '/bills/settings': PageConfig(
      route: '/bills/settings',
      name: '提醒设置',
      module: '账单提醒',
      aliases: ['提醒设置', '账单提醒设置'],
      voiceAdaptation: VoiceAdaptation.medium,
    ),
  };

  /// 导航指令模式
  static final List<RegExp> _navigationPatterns = [
    RegExp(r'(打开|进入|去|看看|显示|跳转到?|切换到?)\s*(.+)'),
    RegExp(r'(.+)\s*(在哪|怎么找|怎么打开)'),
    RegExp(r'(返回|回到)\s*(.+)'),
  ];

  /// 解析导航指令
  NavigationResult parseNavigation(String text) {
    if (text.trim().isEmpty) {
      return NavigationResult.failure('请说出您想去的页面');
    }

    final normalizedText = text.trim().toLowerCase();

    // 1. 尝试直接匹配别名
    for (final config in _pageConfigs.values) {
      for (final alias in config.aliases) {
        if (normalizedText.contains(alias.toLowerCase())) {
          _addToHistory(config);
          return NavigationResult.success(config);
        }
      }
    }

    // 2. 尝试模式匹配
    for (final pattern in _navigationPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        final target = match.group(2)?.trim() ?? match.group(1)?.trim();
        if (target != null) {
          final config = _findPageByTarget(target);
          if (config != null) {
            _addToHistory(config);
            return NavigationResult.success(config);
          }
        }
      }
    }

    // 3. 模糊匹配
    final fuzzyMatch = _fuzzyMatch(normalizedText);
    if (fuzzyMatch != null) {
      _addToHistory(fuzzyMatch);
      return NavigationResult.success(fuzzyMatch, confidence: 0.7);
    }

    return NavigationResult.failure('未找到"$text"对应的页面');
  }

  /// 根据目标查找页面
  PageConfig? _findPageByTarget(String target) {
    final lowerTarget = target.toLowerCase();
    for (final config in _pageConfigs.values) {
      // 检查页面名称
      if (config.name.toLowerCase().contains(lowerTarget)) {
        return config;
      }
      // 检查别名
      for (final alias in config.aliases) {
        if (alias.toLowerCase().contains(lowerTarget) ||
            lowerTarget.contains(alias.toLowerCase())) {
          return config;
        }
      }
    }
    return null;
  }

  /// 模糊匹配
  PageConfig? _fuzzyMatch(String text) {
    double bestScore = 0;
    PageConfig? bestMatch;

    for (final config in _pageConfigs.values) {
      // 计算相似度
      final nameScore = _calculateSimilarity(text, config.name);
      double aliasScore = 0;
      for (final alias in config.aliases) {
        final score = _calculateSimilarity(text, alias);
        if (score > aliasScore) aliasScore = score;
      }

      final score = nameScore > aliasScore ? nameScore : aliasScore;
      if (score > bestScore && score > 0.5) {
        bestScore = score;
        bestMatch = config;
      }
    }

    return bestMatch;
  }

  /// 计算字符串相似度（简化的Jaccard相似度）
  double _calculateSimilarity(String a, String b) {
    final setA = a.toLowerCase().split('').toSet();
    final setB = b.toLowerCase().split('').toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union > 0 ? intersection / union : 0;
  }

  /// 添加到历史
  void _addToHistory(PageConfig config) {
    _history.add(NavigationRecord(
      config: config,
      timestamp: DateTime.now(),
    ));
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
    notifyListeners();
  }

  /// 获取导航历史
  List<NavigationRecord> get history => List.unmodifiable(_history);

  /// 获取最近访问的页面
  List<PageConfig> getRecentPages({int limit = 5}) {
    final seen = <String>{};
    final recent = <PageConfig>[];
    for (var i = _history.length - 1; i >= 0 && recent.length < limit; i--) {
      final config = _history[i].config;
      if (!seen.contains(config.route)) {
        seen.add(config.route);
        recent.add(config);
      }
    }
    return recent;
  }

  /// 获取常用页面
  List<PageConfig> getFrequentPages({int limit = 5}) {
    final frequency = <String, int>{};
    for (final record in _history) {
      frequency[record.config.route] =
          (frequency[record.config.route] ?? 0) + 1;
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((e) => _pageConfigs[e.key]!)
        .toList();
  }

  /// 获取模块内的所有页面
  List<PageConfig> getPagesByModule(String module) {
    return _pageConfigs.values
        .where((c) => c.module == module)
        .toList();
  }

  /// 获取所有模块
  List<String> get modules {
    final moduleSet = <String>{};
    for (final config in _pageConfigs.values) {
      moduleSet.add(config.module);
    }
    return moduleSet.toList();
  }

  /// 获取所有页面配置
  Map<String, PageConfig> get allPages => Map.unmodifiable(_pageConfigs);

  /// 获取高适配语音导航的页面
  List<PageConfig> get highAdaptationPages {
    return _pageConfigs.values
        .where((c) => c.voiceAdaptation == VoiceAdaptation.high)
        .toList();
  }

  /// 获取页面总数
  int get totalPageCount => _pageConfigs.length;

  /// 清除历史
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}

/// 语音适配等级
enum VoiceAdaptation {
  /// 高适配：常用功能，语音指令简单明确
  high,

  /// 中适配：偶尔使用，需要具体参数
  medium,

  /// 低适配：复杂操作，建议手动操作
  low,
}

/// 页面配置
class PageConfig {
  /// 路由路径
  final String route;

  /// 页面名称
  final String name;

  /// 所属模块
  final String module;

  /// 语音别名
  final List<String> aliases;

  /// 语音适配等级
  final VoiceAdaptation voiceAdaptation;

  const PageConfig({
    required this.route,
    required this.name,
    required this.module,
    required this.aliases,
    required this.voiceAdaptation,
  });

  @override
  String toString() => 'PageConfig($name, $route)';
}

/// 导航结果
class NavigationResult {
  /// 是否成功
  final bool success;

  /// 页面配置
  final PageConfig? config;

  /// 错误信息
  final String? errorMessage;

  /// 置信度
  final double confidence;

  /// 路由路径
  String? get route => config?.route;

  /// 页面名称
  String? get pageName => config?.name;

  const NavigationResult({
    required this.success,
    this.config,
    this.errorMessage,
    this.confidence = 1.0,
  });

  factory NavigationResult.success(PageConfig config, {double confidence = 1.0}) {
    return NavigationResult(
      success: true,
      config: config,
      confidence: confidence,
    );
  }

  factory NavigationResult.failure(String message) {
    return NavigationResult(
      success: false,
      errorMessage: message,
    );
  }
}

/// 导航记录
class NavigationRecord {
  /// 页面配置
  final PageConfig config;

  /// 时间戳
  final DateTime timestamp;

  const NavigationRecord({
    required this.config,
    required this.timestamp,
  });
}
