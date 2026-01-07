##### 15.12.3.1 可配置项全景图

基于1.x版本136项功能的完整配置项覆盖：

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      语音可配置项全景图（完整版）                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         一、预算与财务配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 月度预算设置       │ 分类预算设置       │ 预算高级设置                   │   │
│  │ • 总月度预算       │ • 餐饮/交通/购物   │ • 预算周期（周/月/年）         │   │
│  │ • 预算预警阈值     │ • 娱乐/居住/医疗   │ • 预算起始日期                │   │
│  │ • 超支策略设置     │ • 教育/通讯/服饰   │ • 预算结转规则                │   │
│  │ • 预算提醒开关     │ • 美妆/数码/其他   │ • 零基预算开关                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         二、账户与资产配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 账户管理           │ 信用卡管理         │ 投资账户                      │   │
│  │ • 现金账户         │ • 添加信用卡       │ • 添加投资账户                │   │
│  │ • 银行卡账户       │ • 账单日设置       │ • 投资类型设置                │   │
│  │ • 支付宝/微信      │ • 还款日设置       │ • 收益计算方式                │   │
│  │ • 默认账户设置     │ • 额度设置         │ • 风险等级标记                │   │
│  │ • 账户余额校正     │ • 免息期设置       │                              │   │
│  │ • 账户图标/颜色    │ • 还款提醒         │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         三、账本与成员配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 账本管理           │ 成员管理           │ 权限配置                      │   │
│  │ • 创建新账本       │ • 邀请成员         │ • 查看权限                    │   │
│  │ • 切换当前账本     │ • 移除成员         │ • 编辑权限                    │   │
│  │ • 设为默认账本     │ • 成员预算设置     │ • 审批权限                    │   │
│  │ • 账本名称修改     │ • 成员角色设置     │ • 管理员权限                  │   │
│  │ • 账本共享设置     │ • 消费审批开关     │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         四、分类与标签配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 支出分类管理       │ 收入分类管理       │ 标签管理                      │   │
│  │ • 添加支出分类     │ • 添加收入分类     │ • 创建标签                    │   │
│  │ • 删除分类         │ • 删除分类         │ • 删除标签                    │   │
│  │ • 修改分类名称     │ • 修改分类名称     │ • 标签颜色设置                │   │
│  │ • 分类图标设置     │ • 分类图标设置     │ • 常用标签排序                │   │
│  │ • 子分类管理       │ • 子分类管理       │                              │   │
│  │ • 分类排序调整     │ • 分类排序调整     │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         五、目标与债务配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 储蓄目标           │ 开支目标           │ 债务管理                      │   │
│  │ • 创建储蓄目标     │ • 创建开支目标     │ • 添加债务                    │   │
│  │ • 目标金额调整     │ • 月度限额设置     │ • 债务金额调整                │   │
│  │ • 目标日期设置     │ • 目标类型设置     │ • 利率设置                    │   │
│  │ • 自动存入设置     │ • 超支提醒开关     │ • 还款策略选择                │   │
│  │ • 目标暂停/恢复    │                   │ • 还款提醒设置                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         六、提醒与通知配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 记账提醒           │ 预算提醒           │ 账单提醒                      │   │
│  │ • 每日记账提醒     │ • 预算预警阈值     │ • 信用卡还款提醒              │   │
│  │ • 提醒时间设置     │ • 超支实时通知     │ • 定期账单提醒                │   │
│  │ • 提醒频率设置     │ • 周预算总结       │ • 订阅续费提醒                │   │
│  │ • 提醒方式设置     │ • 月预算总结       │ • 提醒提前天数                │   │
│  │ • 周末提醒开关     │ • 分类预算提醒     │ • 循环提醒设置                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         七、模板与定时配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 记账模板           │ 定时记账           │ 快捷入口                      │   │
│  │ • 创建模板         │ • 添加定时记账     │ • 首页快捷方式                │   │
│  │ • 删除模板         │ • 执行频率设置     │ • 常用模板排序                │   │
│  │ • 修改模板内容     │ • 执行时间设置     │ • 快捷入口显示                │   │
│  │ • 模板排序         │ • 暂停/启用定时    │                              │   │
│  │ • 默认模板设置     │ • 定时提醒开关     │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         八、外观与显示配置                                │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 主题设置           │ 首页布局           │ 显示偏好                      │   │
│  │ • 浅色/深色/跟随   │ • 卡片显示/隐藏    │ • 金额显示格式                │   │
│  │ • 主题色选择       │ • 卡片排序调整     │ • 默认时间范围                │   │
│  │  (蓝/绿/红/紫/橙)  │ • 统计图表类型     │ • 图表默认类型                │   │
│  │ • 自定义主题色     │ • 快捷入口配置     │ • 隐私模式开关                │   │
│  │ • 字体大小设置     │ • 底部导航配置     │ • 小数位数设置                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         九、国际化配置                                    │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 语言设置           │ 货币设置           │ 格式设置                      │   │
│  │ • 简体中文         │ • 人民币 CNY       │ • 日期格式                    │   │
│  │ • 繁体中文         │ • 美元 USD         │ • 时间格式                    │   │
│  │ • 英语             │ • 欧元 EUR         │ • 数字格式                    │   │
│  │ • 日语             │ • 英镑 GBP         │ • 周起始日                    │   │
│  │ • 韩语             │ • 日元 JPY         │ • 月起始日                    │   │
│  │ • 跟随系统语言     │ • 韩元/港币/台币   │                              │   │
│  │                   │ • 手动汇率设置     │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         十、AI与智能配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ AI识别设置         │ 语音设置           │ 智能功能                      │   │
│  │ • 语音识别开关     │ • 语音识别引擎     │ • 智能分类开关                │   │
│  │ • 图片识别开关     │ • 语音唤醒词       │ • 重复检测开关                │   │
│  │ • 邮箱解析开关     │ • 语音播报开关     │ • 重复检测时间窗口            │   │
│  │ • AI分类开关       │ • 语音语言设置     │ • 金额容差设置                │   │
│  │ • 分类确认阈值     │ • 语音反馈方式     │ • 智能建议开关                │   │
│  │ • 图片识别质量     │                   │ • 消费洞察通知                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         十一、数据与同步配置                              │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 数据同步           │ 备份设置           │ 存储管理                      │   │
│  │ • 自动同步开关     │ • 自动备份开关     │ • 来源数据保留                │   │
│  │ • 同步频率设置     │ • 备份频率设置     │ • 缓存自动清理                │   │
│  │ • WiFi下同步       │ • 备份保留数量     │ • 数据保留期限                │   │
│  │ • 私密数据同步     │ • 云端备份开关     │ • 图片质量设置                │   │
│  │ • 离线模式开关     │ • 备份加密开关     │ • 音频保留设置                │   │
│  │ • 冲突处理策略     │                   │                              │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         十二、安全与隐私配置                              │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 应用安全           │ 隐私设置           │ 账户安全                      │   │
│  │ • 应用锁开关       │ • 隐私模式开关     │ • 修改密码                    │   │
│  │ • 指纹解锁         │ • 金额模糊显示     │ • 绑定邮箱                    │   │
│  │ • 面容解锁         │ • 截图保护开关     │ • 绑定手机                    │   │
│  │ • PIN码设置        │ • 敏感操作确认     │ • 第三方账号绑定              │   │
│  │ • 自动锁定时间     │ • 数据脱敏等级     │ • 登录设备管理                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         十三、网络与性能配置                              │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 网络设置           │ 性能设置           │ 更新设置                      │   │
│  │ • 连接超时时间     │ • 动画效果开关     │ • 自动检查更新                │   │
│  │ • 接收超时时间     │ • 预加载数据       │ • WiFi下自动更新              │   │
│  │ • 重试次数设置     │ • 后台刷新开关     │ • 更新提醒方式                │   │
│  │ • 代理设置         │ • 低性能模式       │ • 参与Beta测试                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.3.2 完整配置项映射表

```dart
/// 语音配置服务 - 完整版配置项映射
/// 覆盖1.x版本136项功能的所有可配置项
class VoiceConfigurationService {

  /// ========== 完整配置项映射表（200+项） ==========

  static const Map<String, ConfigurableItem> _configurableItems = {

    // ==================== 一、预算配置（20项） ====================
    '总预算': ConfigurableItem(type: ConfigType.budget, key: 'total'),
    '月度预算': ConfigurableItem(type: ConfigType.budget, key: 'monthly_total'),
    '餐饮预算': ConfigurableItem(type: ConfigType.budget, key: 'food'),
    '交通预算': ConfigurableItem(type: ConfigType.budget, key: 'transport'),
    '购物预算': ConfigurableItem(type: ConfigType.budget, key: 'shopping'),
    '娱乐预算': ConfigurableItem(type: ConfigType.budget, key: 'entertainment'),
    '居住预算': ConfigurableItem(type: ConfigType.budget, key: 'housing'),
    '医疗预算': ConfigurableItem(type: ConfigType.budget, key: 'medical'),
    '教育预算': ConfigurableItem(type: ConfigType.budget, key: 'education'),
    '通讯预算': ConfigurableItem(type: ConfigType.budget, key: 'communication'),
    '服饰预算': ConfigurableItem(type: ConfigType.budget, key: 'clothing'),
    '美妆预算': ConfigurableItem(type: ConfigType.budget, key: 'beauty'),
    '数码预算': ConfigurableItem(type: ConfigType.budget, key: 'digital'),
    '预算预警': ConfigurableItem(type: ConfigType.budgetAlert, key: 'threshold'),
    '预算周期': ConfigurableItem(type: ConfigType.budgetCycle, key: 'cycle'),
    '预算起始日': ConfigurableItem(type: ConfigType.budgetCycle, key: 'start_day'),
    '预算结转': ConfigurableItem(type: ConfigType.budgetSetting, key: 'rollover'),
    '零基预算': ConfigurableItem(type: ConfigType.budgetSetting, key: 'zero_based'),
    '超支策略': ConfigurableItem(type: ConfigType.budgetSetting, key: 'overspend_policy'),
    '预算提醒': ConfigurableItem(type: ConfigType.reminder, key: 'budget_alert'),

    // ==================== 二、账户配置（15项） ====================
    '默认账户': ConfigurableItem(type: ConfigType.account, key: 'default'),
    '现金账户': ConfigurableItem(type: ConfigType.account, key: 'cash'),
    '银行卡': ConfigurableItem(type: ConfigType.account, key: 'bank_card'),
    '支付宝': ConfigurableItem(type: ConfigType.account, key: 'alipay'),
    '微信钱包': ConfigurableItem(type: ConfigType.account, key: 'wechat'),
    '信用卡': ConfigurableItem(type: ConfigType.creditCard, key: 'credit_card'),
    '账单日': ConfigurableItem(type: ConfigType.creditCard, key: 'bill_day'),
    '还款日': ConfigurableItem(type: ConfigType.creditCard, key: 'due_day'),
    '信用额度': ConfigurableItem(type: ConfigType.creditCard, key: 'credit_limit'),
    '免息期': ConfigurableItem(type: ConfigType.creditCard, key: 'grace_period'),
    '投资账户': ConfigurableItem(type: ConfigType.investment, key: 'investment'),
    '账户余额': ConfigurableItem(type: ConfigType.account, key: 'balance'),
    '账户图标': ConfigurableItem(type: ConfigType.account, key: 'icon'),
    '账户颜色': ConfigurableItem(type: ConfigType.account, key: 'color'),
    '账户排序': ConfigurableItem(type: ConfigType.account, key: 'order'),

    // ==================== 三、账本与成员配置（12项） ====================
    '当前账本': ConfigurableItem(type: ConfigType.ledger, key: 'current'),
    '默认账本': ConfigurableItem(type: ConfigType.ledger, key: 'default'),
    '账本名称': ConfigurableItem(type: ConfigType.ledger, key: 'name'),
    '账本共享': ConfigurableItem(type: ConfigType.ledger, key: 'sharing'),
    '成员邀请': ConfigurableItem(type: ConfigType.member, key: 'invite'),
    '成员权限': ConfigurableItem(type: ConfigType.member, key: 'permission'),
    '成员预算': ConfigurableItem(type: ConfigType.member, key: 'budget'),
    '成员角色': ConfigurableItem(type: ConfigType.member, key: 'role'),
    '消费审批': ConfigurableItem(type: ConfigType.member, key: 'approval'),
    '查看权限': ConfigurableItem(type: ConfigType.permission, key: 'view'),
    '编辑权限': ConfigurableItem(type: ConfigType.permission, key: 'edit'),
    '管理权限': ConfigurableItem(type: ConfigType.permission, key: 'admin'),

    // ==================== 四、分类配置（10项） ====================
    '支出分类': ConfigurableItem(type: ConfigType.category, key: 'expense'),
    '收入分类': ConfigurableItem(type: ConfigType.category, key: 'income'),
    '分类名称': ConfigurableItem(type: ConfigType.category, key: 'name'),
    '分类图标': ConfigurableItem(type: ConfigType.category, key: 'icon'),
    '分类颜色': ConfigurableItem(type: ConfigType.category, key: 'color'),
    '子分类': ConfigurableItem(type: ConfigType.subCategory, key: 'sub'),
    '分类排序': ConfigurableItem(type: ConfigType.category, key: 'order'),
    '标签': ConfigurableItem(type: ConfigType.tag, key: 'tag'),
    '标签颜色': ConfigurableItem(type: ConfigType.tag, key: 'color'),
    '常用标签': ConfigurableItem(type: ConfigType.tag, key: 'frequent'),

    // ==================== 五、目标与债务配置（15项） ====================
    '储蓄目标': ConfigurableItem(type: ConfigType.savingsGoal, key: 'goal'),
    '目标金额': ConfigurableItem(type: ConfigType.savingsGoal, key: 'amount'),
    '目标日期': ConfigurableItem(type: ConfigType.savingsGoal, key: 'date'),
    '自动存入': ConfigurableItem(type: ConfigType.savingsGoal, key: 'auto_save'),
    '开支目标': ConfigurableItem(type: ConfigType.expenseTarget, key: 'target'),
    '月度限额': ConfigurableItem(type: ConfigType.expenseTarget, key: 'limit'),
    '债务': ConfigurableItem(type: ConfigType.debt, key: 'debt'),
    '债务金额': ConfigurableItem(type: ConfigType.debt, key: 'amount'),
    '债务利率': ConfigurableItem(type: ConfigType.debt, key: 'interest_rate'),
    '还款策略': ConfigurableItem(type: ConfigType.debt, key: 'strategy'),
    '还款提醒': ConfigurableItem(type: ConfigType.debt, key: 'reminder'),
    '定期存款': ConfigurableItem(type: ConfigType.savings, key: 'fixed_deposit'),
    '存款期限': ConfigurableItem(type: ConfigType.savings, key: 'term'),
    '存款利率': ConfigurableItem(type: ConfigType.savings, key: 'rate'),
    '到期提醒': ConfigurableItem(type: ConfigType.savings, key: 'maturity_reminder'),

    // ==================== 六、提醒配置（18项） ====================
    '记账提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bookkeeping'),
    '提醒时间': ConfigurableItem(type: ConfigType.reminder, key: 'time'),
    '提醒频率': ConfigurableItem(type: ConfigType.reminder, key: 'frequency'),
    '周末提醒': ConfigurableItem(type: ConfigType.reminder, key: 'weekend'),
    '预算提醒': ConfigurableItem(type: ConfigType.reminder, key: 'budget'),
    '超支提醒': ConfigurableItem(type: ConfigType.reminder, key: 'overspend'),
    '周预算总结': ConfigurableItem(type: ConfigType.reminder, key: 'weekly_summary'),
    '月预算总结': ConfigurableItem(type: ConfigType.reminder, key: 'monthly_summary'),
    '账单提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bill'),
    '还款提醒': ConfigurableItem(type: ConfigType.reminder, key: 'repayment'),
    '订阅提醒': ConfigurableItem(type: ConfigType.reminder, key: 'subscription'),
    '提醒提前天数': ConfigurableItem(type: ConfigType.reminder, key: 'advance_days'),
    '定时记账提醒': ConfigurableItem(type: ConfigType.reminder, key: 'recurring'),
    '目标提醒': ConfigurableItem(type: ConfigType.reminder, key: 'goal'),
    '存款到期提醒': ConfigurableItem(type: ConfigType.reminder, key: 'deposit_maturity'),
    '同步提醒': ConfigurableItem(type: ConfigType.reminder, key: 'sync'),
    '备份提醒': ConfigurableItem(type: ConfigType.reminder, key: 'backup'),
    '更新提醒': ConfigurableItem(type: ConfigType.reminder, key: 'update'),

    // ==================== 七、模板与定时配置（10项） ====================
    '记账模板': ConfigurableItem(type: ConfigType.template, key: 'template'),
    '模板名称': ConfigurableItem(type: ConfigType.template, key: 'name'),
    '默认模板': ConfigurableItem(type: ConfigType.template, key: 'default'),
    '模板排序': ConfigurableItem(type: ConfigType.template, key: 'order'),
    '定时记账': ConfigurableItem(type: ConfigType.recurring, key: 'recurring'),
    '执行频率': ConfigurableItem(type: ConfigType.recurring, key: 'frequency'),
    '执行时间': ConfigurableItem(type: ConfigType.recurring, key: 'time'),
    '定时开关': ConfigurableItem(type: ConfigType.recurring, key: 'enabled'),
    '快捷入口': ConfigurableItem(type: ConfigType.shortcut, key: 'shortcut'),
    '首页快捷方式': ConfigurableItem(type: ConfigType.shortcut, key: 'home'),

    // ==================== 八、外观与显示配置（20项） ====================
    '主题': ConfigurableItem(type: ConfigType.appearance, key: 'theme'),
    '深色模式': ConfigurableItem(type: ConfigType.appearance, key: 'dark_mode'),
    '浅色模式': ConfigurableItem(type: ConfigType.appearance, key: 'light_mode'),
    '跟随系统': ConfigurableItem(type: ConfigType.appearance, key: 'system'),
    '主题色': ConfigurableItem(type: ConfigType.appearance, key: 'color_theme'),
    '蓝色主题': ConfigurableItem(type: ConfigType.appearance, key: 'blue'),
    '绿色主题': ConfigurableItem(type: ConfigType.appearance, key: 'green'),
    '红色主题': ConfigurableItem(type: ConfigType.appearance, key: 'red'),
    '紫色主题': ConfigurableItem(type: ConfigType.appearance, key: 'purple'),
    '橙色主题': ConfigurableItem(type: ConfigType.appearance, key: 'orange'),
    '自定义主题': ConfigurableItem(type: ConfigType.appearance, key: 'custom'),
    '字体大小': ConfigurableItem(type: ConfigType.appearance, key: 'font_size'),
    '首页卡片': ConfigurableItem(type: ConfigType.homeLayout, key: 'cards'),
    '卡片排序': ConfigurableItem(type: ConfigType.homeLayout, key: 'card_order'),
    '统计图表': ConfigurableItem(type: ConfigType.homeLayout, key: 'chart_type'),
    '快捷入口显示': ConfigurableItem(type: ConfigType.homeLayout, key: 'shortcuts'),
    '金额显示': ConfigurableItem(type: ConfigType.display, key: 'amount_format'),
    '小数位数': ConfigurableItem(type: ConfigType.display, key: 'decimal_places'),
    '默认时间范围': ConfigurableItem(type: ConfigType.display, key: 'default_range'),
    '隐私模式': ConfigurableItem(type: ConfigType.display, key: 'privacy_mode'),

    // ==================== 九、国际化配置（15项） ====================
    '语言': ConfigurableItem(type: ConfigType.i18n, key: 'language'),
    '简体中文': ConfigurableItem(type: ConfigType.i18n, key: 'zh_CN'),
    '繁体中文': ConfigurableItem(type: ConfigType.i18n, key: 'zh_TW'),
    '英语': ConfigurableItem(type: ConfigType.i18n, key: 'en_US'),
    '日语': ConfigurableItem(type: ConfigType.i18n, key: 'ja_JP'),
    '韩语': ConfigurableItem(type: ConfigType.i18n, key: 'ko_KR'),
    '跟随系统语言': ConfigurableItem(type: ConfigType.i18n, key: 'system_locale'),
    '货币': ConfigurableItem(type: ConfigType.i18n, key: 'currency'),
    '人民币': ConfigurableItem(type: ConfigType.i18n, key: 'CNY'),
    '美元': ConfigurableItem(type: ConfigType.i18n, key: 'USD'),
    '欧元': ConfigurableItem(type: ConfigType.i18n, key: 'EUR'),
    '日元': ConfigurableItem(type: ConfigType.i18n, key: 'JPY'),
    '手动汇率': ConfigurableItem(type: ConfigType.i18n, key: 'manual_rate'),
    '日期格式': ConfigurableItem(type: ConfigType.i18n, key: 'date_format'),
    '周起始日': ConfigurableItem(type: ConfigType.i18n, key: 'week_start'),

    // ==================== 十、AI与智能配置（18项） ====================
    '语音识别': ConfigurableItem(type: ConfigType.ai, key: 'voice_recognition'),
    '图片识别': ConfigurableItem(type: ConfigType.ai, key: 'image_recognition'),
    '邮箱解析': ConfigurableItem(type: ConfigType.ai, key: 'email_parsing'),
    'AI分类': ConfigurableItem(type: ConfigType.ai, key: 'ai_categorization'),
    '智能分类': ConfigurableItem(type: ConfigType.ai, key: 'smart_category'),
    '分类确认阈值': ConfigurableItem(type: ConfigType.ai, key: 'category_threshold'),
    '重复检测': ConfigurableItem(type: ConfigType.ai, key: 'duplicate_detection'),
    '重复检测时间': ConfigurableItem(type: ConfigType.ai, key: 'duplicate_time_window'),
    '金额容差': ConfigurableItem(type: ConfigType.ai, key: 'amount_tolerance'),
    '语音唤醒': ConfigurableItem(type: ConfigType.ai, key: 'voice_wakeup'),
    '语音播报': ConfigurableItem(type: ConfigType.ai, key: 'voice_broadcast'),
    '语音语言': ConfigurableItem(type: ConfigType.ai, key: 'voice_language'),
    '智能建议': ConfigurableItem(type: ConfigType.ai, key: 'smart_suggestion'),
    '消费洞察': ConfigurableItem(type: ConfigType.ai, key: 'spending_insight'),
    '图片质量': ConfigurableItem(type: ConfigType.ai, key: 'image_quality'),
    '识别模型': ConfigurableItem(type: ConfigType.ai, key: 'recognition_model'),
    '语音模型': ConfigurableItem(type: ConfigType.ai, key: 'voice_model'),
    '文本模型': ConfigurableItem(type: ConfigType.ai, key: 'text_model'),

    // ==================== 十一、数据与同步配置（18项） ====================
    '数据同步': ConfigurableItem(type: ConfigType.sync, key: 'sync'),
    '自动同步': ConfigurableItem(type: ConfigType.sync, key: 'auto_sync'),
    '同步频率': ConfigurableItem(type: ConfigType.sync, key: 'frequency'),
    'WiFi同步': ConfigurableItem(type: ConfigType.sync, key: 'wifi_only'),
    '私密数据同步': ConfigurableItem(type: ConfigType.sync, key: 'private_data'),
    '离线模式': ConfigurableItem(type: ConfigType.sync, key: 'offline_mode'),
    '冲突处理': ConfigurableItem(type: ConfigType.sync, key: 'conflict_resolution'),
    '自动备份': ConfigurableItem(type: ConfigType.backup, key: 'auto_backup'),
    '备份频率': ConfigurableItem(type: ConfigType.backup, key: 'frequency'),
    '备份保留数量': ConfigurableItem(type: ConfigType.backup, key: 'retention'),
    '云端备份': ConfigurableItem(type: ConfigType.backup, key: 'cloud'),
    '备份加密': ConfigurableItem(type: ConfigType.backup, key: 'encryption'),
    '来源数据保留': ConfigurableItem(type: ConfigType.storage, key: 'source_data'),
    '缓存清理': ConfigurableItem(type: ConfigType.storage, key: 'cache'),
    '数据保留期限': ConfigurableItem(type: ConfigType.storage, key: 'retention_period'),
    '图片保留': ConfigurableItem(type: ConfigType.storage, key: 'image_retention'),
    '音频保留': ConfigurableItem(type: ConfigType.storage, key: 'audio_retention'),
    '导出格式': ConfigurableItem(type: ConfigType.export, key: 'format'),

    // ==================== 十二、安全与隐私配置（15项） ====================
    '应用锁': ConfigurableItem(type: ConfigType.security, key: 'app_lock'),
    '指纹解锁': ConfigurableItem(type: ConfigType.security, key: 'fingerprint'),
    '面容解锁': ConfigurableItem(type: ConfigType.security, key: 'face_id'),
    'PIN码': ConfigurableItem(type: ConfigType.security, key: 'pin'),
    '自动锁定': ConfigurableItem(type: ConfigType.security, key: 'auto_lock'),
    '锁定时间': ConfigurableItem(type: ConfigType.security, key: 'lock_timeout'),
    '隐私模式': ConfigurableItem(type: ConfigType.privacy, key: 'privacy_mode'),
    '金额模糊': ConfigurableItem(type: ConfigType.privacy, key: 'blur_amount'),
    '截图保护': ConfigurableItem(type: ConfigType.privacy, key: 'screenshot_protection'),
    '敏感操作确认': ConfigurableItem(type: ConfigType.privacy, key: 'sensitive_confirm'),
    '修改密码': ConfigurableItem(type: ConfigType.account_security, key: 'password'),
    '绑定邮箱': ConfigurableItem(type: ConfigType.account_security, key: 'email'),
    '绑定手机': ConfigurableItem(type: ConfigType.account_security, key: 'phone'),
    '第三方绑定': ConfigurableItem(type: ConfigType.account_security, key: 'oauth'),
    '登录设备': ConfigurableItem(type: ConfigType.account_security, key: 'devices'),

    // ==================== 十三、网络与性能配置（12项） ====================
    '连接超时': ConfigurableItem(type: ConfigType.network, key: 'connect_timeout'),
    '接收超时': ConfigurableItem(type: ConfigType.network, key: 'receive_timeout'),
    '重试次数': ConfigurableItem(type: ConfigType.network, key: 'max_retries'),
    '代理设置': ConfigurableItem(type: ConfigType.network, key: 'proxy'),
    '动画效果': ConfigurableItem(type: ConfigType.performance, key: 'animation'),
    '预加载': ConfigurableItem(type: ConfigType.performance, key: 'preload'),
    '后台刷新': ConfigurableItem(type: ConfigType.performance, key: 'background_refresh'),
    '低性能模式': ConfigurableItem(type: ConfigType.performance, key: 'low_performance'),
    '自动更新': ConfigurableItem(type: ConfigType.update, key: 'auto_check'),
    'WiFi更新': ConfigurableItem(type: ConfigType.update, key: 'wifi_only'),
    '更新提醒': ConfigurableItem(type: ConfigType.update, key: 'notification'),
    'Beta测试': ConfigurableItem(type: ConfigType.update, key: 'beta'),

    // ==================== 十四、商户绑定配置（5项） ====================
    '商户分类绑定': ConfigurableItem(type: ConfigType.merchant, key: 'category'),
    '商户账户绑定': ConfigurableItem(type: ConfigType.merchant, key: 'account'),
    '商户别名': ConfigurableItem(type: ConfigType.merchant, key: 'alias'),
    '商户图标': ConfigurableItem(type: ConfigType.merchant, key: 'icon'),
    '智能商户识别': ConfigurableItem(type: ConfigType.merchant, key: 'auto_recognize'),
  };

  // 配置项总计：200+项
}
```

##### 15.12.4.1 导航与操作能力全景图（完整版）

覆盖1.x版本全部48个页面及所有可执行操作：

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    语音导航与操作能力全景图（完整版）                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                   第一层：页面导航（48个页面全覆盖）                       │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │  【主导航】                                                              │   │
│  │   首页    设置                                                          │   │
│  │                                                                         │   │
│  │  【记账相关】                                                            │   │
│  │   新增交易   快速记账   语音记账   图片记账   多笔确认                    │   │
│  │                                                                         │   │
│  │  【账本与成员】                                                          │   │
│  │   账本管理   成员管理   加入邀请   成员预算   成员对比                    │   │
│  │                                                                         │   │
│  │  【账户管理】                                                            │   │
│  │   账户管理   信用卡    投资账户                                          │   │
│  │                                                                         │   │
│  │  【分类与标签】                                                          │   │
│  │   分类管理   标签统计                                                    │   │
│  │                                                                         │   │
│  │  【预算与目标】                                                          │   │
│  │   预算管理   储蓄目标   开支目标   债务管理   债务模拟器                  │   │
│  │                                                                         │   │
│  │  【提醒与定时】                                                          │   │
│  │   账单提醒   模板管理   定时记账                                         │   │
│  │                                                                         │   │
│  │  【统计报表】                                                            │   │
│  │   资产总览   年度报告   自定义报表   多货币报表                          │   │
│  │                                                                         │   │
│  │  【数据管理】                                                            │   │
│  │   数据备份   数据导出   数据导入   智能导入   报销管理                   │   │
│  │                                                                         │   │
│  │  【系统设置】                                                            │   │
│  │   系统设置   语言设置   货币设置   来源数据   自定义主题                  │   │
│  │                                                                         │   │
│  │  【用户相关】                                                            │   │
│  │   登录     注册     找回密码   关于我们   帮助     用户协议              │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                   第二层：功能入口（带上下文预填）                         │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │  【记账入口】                                                            │   │
│  │   记一笔支出   记一笔收入   记一笔转账   语音记账   拍照记账             │   │
│  │   扫码记账    批量记账    按模板记账                                     │   │
│  │                                                                         │   │
│  │  【创建操作】                                                            │   │
│  │   创建账本   创建账户   创建信用卡   创建分类   创建子分类               │   │
│  │   创建标签   创建预算   创建储蓄目标  创建开支目标  创建债务             │   │
│  │   创建模板   创建定时记账  创建账单提醒                                  │   │
│  │                                                                         │   │
│  │  【管理操作】                                                            │   │
│  │   邀请成员   调整预算   调整目标   设置提醒                              │   │
│  │                                                                         │   │
│  │  【数据操作】                                                            │   │
│  │   导出数据   导入数据   生成报告   备份数据   恢复数据                   │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                   第三层：直接操作（无需进入页面）                         │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │  【记账操作】              【账户操作】              【预算操作】         │   │
│  │  • 删除最后一笔            • 切换默认账户            • 调整XX预算        │   │
│  │  • 撤销上次操作            • 校正账户余额            • 重置本月预算      │   │
│  │  • 修改刚才那笔            • 查看账户余额            • 预算结转          │   │
│  │  • 复制为模板                                                           │   │
│  │                                                                         │   │
│  │  【切换操作】              【开关操作】              【主题操作】         │   │
│  │  • 切换账本               • 开启/关闭自动同步        • 切换深色模式      │   │
│  │  • 切换语言               • 开启/关闭隐私模式        • 切换浅色模式      │   │
│  │  • 切换货币               • 开启/关闭应用锁          • 切换XX主题色      │   │
│  │                          • 开启/关闭语音识别                            │   │
│  │                          • 开启/关闭图片识别                            │   │
│  │                          • 开启/关闭智能分类                            │   │
│  │                          • 开启/关闭记账提醒                            │   │
│  │                                                                         │   │
│  │  【数据操作】              【同步操作】              【习惯操作】         │   │
│  │  • 立即备份               • 立即同步                • 今日打卡          │   │
│  │  • 导出本月数据           • 强制刷新                • 查看打卡记录      │   │
│  │  • 导出本年数据           • 清除缓存                                    │   │
│  │  • 清空回收站                                                           │   │
│  │                                                                         │   │
│  │  【快捷操作】              【分享操作】              【系统操作】         │   │
│  │  • 打开相机               • 分享月度报告            • 检查更新          │   │
│  │  • 打开扫码               • 分享年度报告            • 提交反馈          │   │
│  │  • 刷新数据               • 分享账单截图            • 联系客服          │   │
│  │  • 返回首页               • 邀请好友                • 退出登录          │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.4.2 完整页面路由映射表

```dart
/// 语音导航服务 - 完整版页面路由映射
/// 覆盖1.x版本全部48个页面
class VoiceNavigationService {

  // ==================== 完整页面路由映射（48个页面） ====================

  static const Map<String, NavigationTarget> _navigationTargets = {

    // ========== 主导航（2个） ==========
    '首页': NavigationTarget(route: '/home', displayName: '首页'),
    '主页': NavigationTarget(route: '/home', displayName: '首页'),
    '设置': NavigationTarget(route: '/settings', displayName: '设置'),
    '设置页': NavigationTarget(route: '/settings', displayName: '设置'),
    '系统设置': NavigationTarget(route: '/system-settings', displayName: '系统设置'),

    // ========== 记账页面（5个） ==========
    '记账': NavigationTarget(route: '/add-transaction', displayName: '新增交易'),
    '新增交易': NavigationTarget(route: '/add-transaction', displayName: '新增交易'),
    '记一笔': NavigationTarget(route: '/add-transaction', displayName: '新增交易'),
    '快速记账': NavigationTarget(route: '/quick-entry', displayName: '快速记账'),
    '语音记账': NavigationTarget(route: '/voice-recognition', displayName: '语音记账'),
    '图片记账': NavigationTarget(route: '/image-recognition', displayName: '图片识别记账'),
    '拍照记账': NavigationTarget(route: '/image-recognition', displayName: '图片识别记账'),
    '多笔确认': NavigationTarget(route: '/multi-transaction-confirm', displayName: '多笔交易确认'),

    // ========== 账本与成员（5个） ==========
    '账本': NavigationTarget(route: '/ledger-management', displayName: '账本管理'),
    '账本管理': NavigationTarget(route: '/ledger-management', displayName: '账本管理'),
    '成员': NavigationTarget(route: '/member-management', displayName: '成员管理'),
    '成员管理': NavigationTarget(route: '/member-management', displayName: '成员管理'),
    '邀请': NavigationTarget(route: '/join-invite', displayName: '加入/邀请'),
    '加入账本': NavigationTarget(route: '/join-invite', displayName: '加入/邀请'),
    '成员预算': NavigationTarget(route: '/member-budget', displayName: '成员预算'),
    '成员对比': NavigationTarget(route: '/member-comparison', displayName: '成员对比'),

    // ========== 账户管理（3个） ==========
    '账户': NavigationTarget(route: '/account-management', displayName: '账户管理'),
    '账户管理': NavigationTarget(route: '/account-management', displayName: '账户管理'),
    '信用卡': NavigationTarget(route: '/credit-card', displayName: '信用卡'),
    '信用卡管理': NavigationTarget(route: '/credit-card', displayName: '信用卡'),
    '投资': NavigationTarget(route: '/investment', displayName: '投资账户'),
    '投资账户': NavigationTarget(route: '/investment', displayName: '投资账户'),

    // ========== 分类与标签（2个） ==========
    '分类': NavigationTarget(route: '/category-management', displayName: '分类管理'),
    '分类管理': NavigationTarget(route: '/category-management', displayName: '分类管理'),
    '标签': NavigationTarget(route: '/tag-statistics', displayName: '标签统计'),
    '标签统计': NavigationTarget(route: '/tag-statistics', displayName: '标签统计'),

    // ========== 预算与目标（5个） ==========
    '预算': NavigationTarget(route: '/budget-management', displayName: '预算管理'),
    '预算管理': NavigationTarget(route: '/budget-management', displayName: '预算管理'),
    '储蓄目标': NavigationTarget(route: '/savings-goal', displayName: '储蓄目标'),
    '攒钱': NavigationTarget(route: '/savings-goal', displayName: '储蓄目标'),
    '开支目标': NavigationTarget(route: '/expense-target', displayName: '开支目标'),
    '债务': NavigationTarget(route: '/debt-management', displayName: '债务管理'),
    '债务管理': NavigationTarget(route: '/debt-management', displayName: '债务管理'),
    '还债': NavigationTarget(route: '/debt-management', displayName: '债务管理'),
    '债务模拟': NavigationTarget(route: '/debt-simulator', displayName: '债务模拟器'),
    '还款模拟': NavigationTarget(route: '/debt-simulator', displayName: '债务模拟器'),

    // ========== 提醒与定时（3个） ==========
    '账单提醒': NavigationTarget(route: '/bill-reminder', displayName: '账单提醒'),
    '提醒': NavigationTarget(route: '/bill-reminder', displayName: '账单提醒'),
    '模板': NavigationTarget(route: '/template-management', displayName: '模板管理'),
    '模板管理': NavigationTarget(route: '/template-management', displayName: '模板管理'),
    '定时记账': NavigationTarget(route: '/recurring-management', displayName: '定时记账'),
    '定时': NavigationTarget(route: '/recurring-management', displayName: '定时记账'),
    '周期记账': NavigationTarget(route: '/recurring-management', displayName: '定时记账'),

    // ========== 统计报表（4个） ==========
    '资产': NavigationTarget(route: '/asset-overview', displayName: '资产总览'),
    '资产总览': NavigationTarget(route: '/asset-overview', displayName: '资产总览'),
    '净资产': NavigationTarget(route: '/asset-overview', displayName: '资产总览'),
    '年度报告': NavigationTarget(route: '/annual-report', displayName: '年度报告'),
    '年报': NavigationTarget(route: '/annual-report', displayName: '年度报告'),
    '自定义报表': NavigationTarget(route: '/custom-report', displayName: '自定义报表'),
    '报表': NavigationTarget(route: '/custom-report', displayName: '自定义报表'),
    '多货币报表': NavigationTarget(route: '/multi-currency-report', displayName: '多货币报表'),
    '汇率报表': NavigationTarget(route: '/multi-currency-report', displayName: '多货币报表'),

    // ========== 数据管理（5个） ==========
    '备份': NavigationTarget(route: '/backup', displayName: '数据备份'),
    '数据备份': NavigationTarget(route: '/backup', displayName: '数据备份'),
    '导出': NavigationTarget(route: '/export', displayName: '数据导出'),
    '数据导出': NavigationTarget(route: '/export', displayName: '数据导出'),
    '导入': NavigationTarget(route: '/import', displayName: '数据导入'),
    '数据导入': NavigationTarget(route: '/import', displayName: '数据导入'),
    '智能导入': NavigationTarget(route: '/smart-import', displayName: '智能账单导入'),
    '账单导入': NavigationTarget(route: '/smart-import', displayName: '智能账单导入'),
    '报销': NavigationTarget(route: '/reimbursement', displayName: '报销管理'),
    '报销管理': NavigationTarget(route: '/reimbursement', displayName: '报销管理'),

    // ========== 系统设置（5个） ==========
    '语言': NavigationTarget(route: '/language-settings', displayName: '语言设置'),
    '语言设置': NavigationTarget(route: '/language-settings', displayName: '语言设置'),
    '货币': NavigationTarget(route: '/currency-settings', displayName: '货币设置'),
    '货币设置': NavigationTarget(route: '/currency-settings', displayName: '货币设置'),
    '来源数据': NavigationTarget(route: '/source-data-settings', displayName: '来源数据管理'),
    '来源管理': NavigationTarget(route: '/source-data-settings', displayName: '来源数据管理'),
    '自定义主题': NavigationTarget(route: '/custom-theme', displayName: '自定义主题'),
    '主题设置': NavigationTarget(route: '/custom-theme', displayName: '自定义主题'),

    // ========== 用户相关（6个） ==========
    '登录': NavigationTarget(route: '/login', displayName: '登录'),
    '注册': NavigationTarget(route: '/register', displayName: '注册'),
    '找回密码': NavigationTarget(route: '/forgot-password', displayName: '找回密码'),
    '忘记密码': NavigationTarget(route: '/forgot-password', displayName: '找回密码'),
    '关于': NavigationTarget(route: '/about', displayName: '关于我们'),
    '关于我们': NavigationTarget(route: '/about', displayName: '关于我们'),
    '帮助': NavigationTarget(route: '/help', displayName: '帮助'),
    '帮助中心': NavigationTarget(route: '/help', displayName: '帮助'),
    '协议': NavigationTarget(route: '/agreement', displayName: '用户协议'),
    '用户协议': NavigationTarget(route: '/agreement', displayName: '用户协议'),

    // ========== 交易列表相关 ==========
    '账单': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '流水': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '明细': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '交易记录': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '收支': NavigationTarget(route: '/transactions', displayName: '账单列表'),

    // ========== 统计分析 ==========
    '统计': NavigationTarget(route: '/statistics', displayName: '统计分析'),
    '分析': NavigationTarget(route: '/statistics', displayName: '统计分析'),
    '图表': NavigationTarget(route: '/statistics', displayName: '统计分析'),
    '趋势': NavigationTarget(route: '/trends', displayName: '趋势分析'),
    '消费趋势': NavigationTarget(route: '/trends', displayName: '趋势分析'),
  };

  // ==================== 直接操作映射（60+项） ====================

  static final Map<String, DirectAction> _directActions = {

    // ========== 记账操作 ==========
    '删除最后一笔': DirectAction(type: ActionType.deleteLastTransaction, needConfirm: true),
    '撤销': DirectAction(type: ActionType.undo, needConfirm: false),
    '撤销上次操作': DirectAction(type: ActionType.undo, needConfirm: false),
    '修改刚才那笔': DirectAction(type: ActionType.editLastTransaction, needConfirm: false),
    '复制为模板': DirectAction(type: ActionType.copyAsTemplate, needConfirm: false),

    // ========== 账本切换 ==========
    '切换账本': DirectAction(type: ActionType.switchLedger, needConfirm: false),
    '切换到个人账本': DirectAction(type: ActionType.switchToPersonalLedger, needConfirm: false),
    '切换到家庭账本': DirectAction(type: ActionType.switchToFamilyLedger, needConfirm: false),

    // ========== 账户操作 ==========
    '切换默认账户': DirectAction(type: ActionType.switchDefaultAccount, needConfirm: false),
    '校正余额': DirectAction(type: ActionType.correctBalance, needConfirm: true),
    '查看余额': DirectAction(type: ActionType.viewBalance, needConfirm: false),

    // ========== 预算操作 ==========
    '重置预算': DirectAction(type: ActionType.resetBudget, needConfirm: true),
    '预算结转': DirectAction(type: ActionType.rolloverBudget, needConfirm: true),

    // ========== 主题操作 ==========
    '切换深色模式': DirectAction(type: ActionType.toggleDarkMode, needConfirm: false),
    '开启深色模式': DirectAction(type: ActionType.enableDarkMode, needConfirm: false),
    '关闭深色模式': DirectAction(type: ActionType.disableDarkMode, needConfirm: false),
    '切换浅色模式': DirectAction(type: ActionType.disableDarkMode, needConfirm: false),
    '切换蓝色主题': DirectAction(type: ActionType.setThemeBlue, needConfirm: false),
    '切换绿色主题': DirectAction(type: ActionType.setThemeGreen, needConfirm: false),
    '切换红色主题': DirectAction(type: ActionType.setThemeRed, needConfirm: false),
    '切换紫色主题': DirectAction(type: ActionType.setThemePurple, needConfirm: false),
    '切换橙色主题': DirectAction(type: ActionType.setThemeOrange, needConfirm: false),

    // ========== 语言切换 ==========
    '切换中文': DirectAction(type: ActionType.setLanguageZhCN, needConfirm: false),
    '切换英文': DirectAction(type: ActionType.setLanguageEnUS, needConfirm: false),
    '切换日文': DirectAction(type: ActionType.setLanguageJaJP, needConfirm: false),
    '切换繁体': DirectAction(type: ActionType.setLanguageZhTW, needConfirm: false),

    // ========== 货币切换 ==========
    '切换人民币': DirectAction(type: ActionType.setCurrencyCNY, needConfirm: false),
    '切换美元': DirectAction(type: ActionType.setCurrencyUSD, needConfirm: false),
    '切换欧元': DirectAction(type: ActionType.setCurrencyEUR, needConfirm: false),
    '切换日元': DirectAction(type: ActionType.setCurrencyJPY, needConfirm: false),

    // ========== 开关操作 ==========
    '开启自动同步': DirectAction(type: ActionType.enableAutoSync, needConfirm: false),
    '关闭自动同步': DirectAction(type: ActionType.disableAutoSync, needConfirm: false),
    '开启隐私模式': DirectAction(type: ActionType.enablePrivacyMode, needConfirm: false),
    '关闭隐私模式': DirectAction(type: ActionType.disablePrivacyMode, needConfirm: false),
    '隐藏金额': DirectAction(type: ActionType.enablePrivacyMode, needConfirm: false),
    '显示金额': DirectAction(type: ActionType.disablePrivacyMode, needConfirm: false),
    '开启应用锁': DirectAction(type: ActionType.enableAppLock, needConfirm: true),
    '关闭应用锁': DirectAction(type: ActionType.disableAppLock, needConfirm: true),
    '开启语音识别': DirectAction(type: ActionType.enableVoiceRecognition, needConfirm: false),
    '关闭语音识别': DirectAction(type: ActionType.disableVoiceRecognition, needConfirm: false),
    '开启图片识别': DirectAction(type: ActionType.enableImageRecognition, needConfirm: false),
    '关闭图片识别': DirectAction(type: ActionType.disableImageRecognition, needConfirm: false),
    '开启智能分类': DirectAction(type: ActionType.enableSmartCategory, needConfirm: false),
    '关闭智能分类': DirectAction(type: ActionType.disableSmartCategory, needConfirm: false),
    '开启重复检测': DirectAction(type: ActionType.enableDuplicateDetection, needConfirm: false),
    '关闭重复检测': DirectAction(type: ActionType.disableDuplicateDetection, needConfirm: false),
    '开启记账提醒': DirectAction(type: ActionType.enableBookkeepingReminder, needConfirm: false),
    '关闭记账提醒': DirectAction(type: ActionType.disableBookkeepingReminder, needConfirm: false),
    '开启预算提醒': DirectAction(type: ActionType.enableBudgetReminder, needConfirm: false),
    '关闭预算提醒': DirectAction(type: ActionType.disableBudgetReminder, needConfirm: false),
    '开启离线模式': DirectAction(type: ActionType.enableOfflineMode, needConfirm: false),
    '关闭离线模式': DirectAction(type: ActionType.disableOfflineMode, needConfirm: false),

    // ========== 数据操作 ==========
    '立即备份': DirectAction(type: ActionType.backupNow, needConfirm: true),
    '备份数据': DirectAction(type: ActionType.backupNow, needConfirm: true),
    '同步数据': DirectAction(type: ActionType.syncNow, needConfirm: false),
    '立即同步': DirectAction(type: ActionType.syncNow, needConfirm: false),
    '强制刷新': DirectAction(type: ActionType.forceRefresh, needConfirm: false),
    '刷新': DirectAction(type: ActionType.refresh, needConfirm: false),
    '刷新数据': DirectAction(type: ActionType.refresh, needConfirm: false),
    '清除缓存': DirectAction(type: ActionType.clearCache, needConfirm: true),
    '清空回收站': DirectAction(type: ActionType.emptyTrash, needConfirm: true),
    '导出本月数据': DirectAction(type: ActionType.exportMonthData, needConfirm: false),
    '导出本年数据': DirectAction(type: ActionType.exportYearData, needConfirm: false),
    '导出全部数据': DirectAction(type: ActionType.exportAllData, needConfirm: true),

    // ========== 快捷操作 ==========
    '打开相机': DirectAction(type: ActionType.openCamera, needConfirm: false),
    '扫一扫': DirectAction(type: ActionType.openScanner, needConfirm: false),
    '开始扫码': DirectAction(type: ActionType.openScanner, needConfirm: false),
    '返回首页': DirectAction(type: ActionType.goHome, needConfirm: false),
    '回到首页': DirectAction(type: ActionType.goHome, needConfirm: false),

    // ========== 习惯操作 ==========
    '打卡': DirectAction(type: ActionType.habitCheckIn, needConfirm: false),
    '今天打卡': DirectAction(type: ActionType.habitCheckIn, needConfirm: false),
    '记账打卡': DirectAction(type: ActionType.habitCheckIn, needConfirm: false),
    '查看打卡': DirectAction(type: ActionType.viewCheckInHistory, needConfirm: false),

    // ========== 分享操作 ==========
    '分享月报': DirectAction(type: ActionType.shareMonthlyReport, needConfirm: false),
    '分享月度报告': DirectAction(type: ActionType.shareMonthlyReport, needConfirm: false),
    '分享年报': DirectAction(type: ActionType.shareAnnualReport, needConfirm: false),
    '分享年度报告': DirectAction(type: ActionType.shareAnnualReport, needConfirm: false),
    '分享账单': DirectAction(type: ActionType.shareTransaction, needConfirm: false),
    '邀请好友': DirectAction(type: ActionType.inviteFriend, needConfirm: false),

    // ========== 系统操作 ==========
    '检查更新': DirectAction(type: ActionType.checkUpdate, needConfirm: false),
    '提交反馈': DirectAction(type: ActionType.openFeedback, needConfirm: false),
    '联系客服': DirectAction(type: ActionType.contactSupport, needConfirm: false),
    '退出登录': DirectAction(type: ActionType.logout, needConfirm: true),
    '注销账号': DirectAction(type: ActionType.deleteAccount, needConfirm: true),
  };
}
```

##### 15.12.3.3 语音配置示例库（扩展版）

| 配置类别 | 语音指令示例 | 系统响应 |
|---------|-------------|---------|
| **预算设置** | "把餐饮预算改成2000" | 将餐饮预算从1500元修改为2000元，确认吗？ |
| **预算设置** | "设置本月总预算8000" | 已将本月总预算设为8000元 |
| **预算设置** | "预算用到80%时提醒我" | 已设置预算预警阈值为80% |
| **预算设置** | "开启预算结转" | 已开启预算结转功能，本月剩余预算将结转到下月 |
| **账户管理** | "把微信设为默认账户" | 已将微信设为默认支付账户 |
| **账户管理** | "添加一张招商银行信用卡" | 已创建信用卡账户"招商银行"，请设置账单日和还款日 |
| **账户管理** | "信用卡账单日改成5号" | 已将信用卡账单日设为每月5日 |
| **账户管理** | "校正支付宝余额为1500" | 已将支付宝余额校正为1500元 |
| **账本管理** | "创建一个家庭账本" | 已创建账本"家庭"，是否设为当前账本？ |
| **账本管理** | "切换到家庭账本" | 已切换到"家庭"账本 |
| **成员管理** | "邀请老婆加入账本" | 已生成邀请链接，有效期7天 |
| **分类管理** | "添加一个宠物分类" | 已添加支出分类"宠物" |
| **分类管理** | "给餐饮添加外卖子分类" | 已在餐饮分类下添加子分类"外卖" |
| **储蓄目标** | "创建一个买车目标，15万，明年底" | 已创建储蓄目标"买车"，目标金额15万，截止日期2027年12月 |
| **储蓄目标** | "每月自动存入500到旅游基金" | 已设置每月自动向"旅游"目标存入500元 |
| **债务管理** | "添加一笔房贷，120万，利率4.2%" | 已添加债务"房贷"，金额120万，年利率4.2% |
| **提醒设置** | "每天晚上8点提醒我记账" | 已设置每日记账提醒，时间：20:00 |
| **提醒设置** | "信用卡还款日提前3天提醒" | 已设置信用卡还款提醒，提前3天通知 |
| **模板设置** | "把刚才那笔保存为模板" | 已将"餐饮-35元"保存为快捷模板 |
| **定时记账** | "每月15号自动记一笔房租3000" | 已创建定时记账：每月15日，房租3000元 |
| **主题设置** | "切换到深色模式" | 已切换到深色模式 |
| **主题设置** | "把主题色改成绿色" | 已将主题色切换为绿色 |
| **语言设置** | "切换到英文" | 已将语言切换为English |
| **货币设置** | "默认货币改成美元" | 已将默认货币从CNY切换为USD |
| **AI设置** | "关闭智能分类" | 已关闭智能分类功能，将使用手动分类 |
| **AI设置** | "重复检测时间改成30分钟" | 已将重复检测时间窗口设为30分钟 |
| **同步设置** | "开启自动同步" | 已开启自动同步，数据将实时同步到云端 |
| **同步设置** | "只在WiFi下同步" | 已设置仅在WiFi环境下进行数据同步 |
| **备份设置** | "设置每天自动备份" | 已设置每日自动备份，时间：凌晨3:00 |
| **安全设置** | "开启应用锁" | 已开启应用锁，请设置解锁方式 |
| **安全设置** | "开启指纹解锁" | 已开启指纹解锁 |
| **隐私设置** | "开启隐私模式" | 已开启隐私模式，金额将显示为*** |
| **网络设置** | "连接超时改成60秒" | 已将连接超时时间设为60秒 |
| **更新设置** | "开启自动更新检查" | 已开启自动更新检查 |

##### 15.12.4.3 语音导航与操作示例库（扩展版）

| 能力层级 | 语音指令示例 | 系统响应 |
|---------|-------------|---------|
| **页面导航** | "打开预算管理" | 正在打开预算管理页面 |
| **页面导航** | "去信用卡页面" | 正在打开信用卡管理页面 |
| **页面导航** | "看看我的债务" | 正在打开债务管理页面 |
| **页面导航** | "打开年度报告" | 正在打开年度报告页面 |
| **页面导航** | "去智能导入" | 正在打开智能账单导入页面 |
| **页面导航** | "打开语言设置" | 正在打开语言设置页面 |
| **页面导航** | "查看成员对比" | 正在打开成员对比页面 |
| **页面导航** | "打开债务模拟器" | 正在打开债务模拟器页面 |
| **功能入口** | "记一笔支出" | 已打开新增交易页面，类型已选"支出" |
| **功能入口** | "创建一个旅游储蓄目标" | 已打开储蓄目标创建页面，名称已预填"旅游" |
| **功能入口** | "添加一张工商银行卡" | 已打开添加账户页面，类型已选银行卡，名称已预填 |
| **功能入口** | "设置房租提醒" | 已打开账单提醒页面，类型已选"房租" |
| **功能入口** | "创建家庭账本" | 已打开账本创建页面，名称已预填"家庭" |
| **直接操作** | "切换深色模式" | 已切换到深色模式 |
| **直接操作** | "切换到家庭账本" | 已切换到"家庭"账本 |
| **直接操作** | "切换英文" | 已将语言切换为English |
| **直接操作** | "切换美元" | 已将货币切换为USD |
| **直接操作** | "开启自动同步" | 已开启自动同步 |
| **直接操作** | "关闭智能分类" | 已关闭智能分类功能 |
| **直接操作** | "隐藏金额" | 已开启隐私模式，金额已隐藏 |
| **直接操作** | "删除最后一笔" | 确定要删除最后一笔记录吗？（餐饮 35元） |
| **直接操作** | "撤销" | 已撤销上次操作 |
| **直接操作** | "立即备份" | 数据备份完成 |
| **直接操作** | "同步数据" | 数据同步完成 |
| **直接操作** | "导出本月数据" | 本月数据已导出到：/Documents/export_202601.xlsx |
| **直接操作** | "打卡" | 打卡成功！已连续记账15天 |
| **直接操作** | "扫一扫" | 已打开扫码功能 |
| **直接操作** | "分享月报" | 正在生成并分享月度报告 |
| **直接操作** | "检查更新" | 当前已是最新版本 |
| **直接操作** | "退出登录" | 确定要退出登录吗？ |
