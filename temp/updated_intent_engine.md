#### 15.12.1 意图识别引擎

```dart
/// 语音意图类型枚举 - 完整版（覆盖200+配置项、48页面、60+直接操作）
enum VoiceIntentType {
  // ==================== 记账相关（5类） ====================
  addExpense,           // 添加支出：记一笔、花了、买了
  addIncome,            // 添加收入：收到、入账、工资到了
  addTransfer,          // 转账：从...转到...
  batchRecord,          // 批量记账：记多笔、连续记账
  useTemplate,          // 使用模板：按模板记、常用记账

  // ==================== 配置相关（13大类） ====================
  // 一、预算配置
  setBudget,            // 设置预算：把餐饮预算改成2000
  setBudgetAlert,       // 预算预警：预算用到80%时提醒我
  setBudgetCycle,       // 预算周期：预算周期改成按周
  setBudgetRollover,    // 预算结转：开启预算结转

  // 二、账户配置
  setAccount,           // 账户设置：把微信设为默认账户
  setCreditCard,        // 信用卡设置：信用卡账单日改成5号
  setInvestment,        // 投资账户：添加投资账户

  // 三、账本与成员配置
  setLedger,            // 账本管理：创建家庭账本、切换账本
  setMember,            // 成员管理：邀请老婆加入账本
  setPermission,        // 权限设置：给XX编辑权限

  // 四、分类配置
  setCategory,          // 分类设置：添加宠物分类
  setSubCategory,       // 子分类：给餐饮添加外卖子分类
  setTag,               // 标签管理：创建标签

  // 五、目标与债务配置
  setSavingsGoal,       // 储蓄目标：创建买车目标15万
  setExpenseTarget,     // 开支目标：设置月度限额
  setDebt,              // 债务管理：添加房贷120万

  // 六、提醒配置
  setReminder,          // 提醒设置：每天8点提醒记账
  setBillReminder,      // 账单提醒：信用卡还款提前3天提醒
  setSubscription,      // 订阅提醒：添加Netflix续费提醒

  // 七、模板与定时配置
  setTemplate,          // 模板管理：把刚才那笔保存为模板
  setRecurring,         // 定时记账：每月15号自动记房租

  // 八、外观与显示配置
  setTheme,             // 主题设置：切换深色模式、换成绿色主题
  setHomeLayout,        // 首页布局：隐藏预算卡片
  setDisplay,           // 显示偏好：金额显示两位小数

  // 九、国际化配置
  setLanguage,          // 语言设置：切换到英文
  setCurrency,          // 货币设置：默认货币改成美元
  setDateFormat,        // 日期格式：日期格式改成年月日

  // 十、AI与智能配置
  setAI,                // AI设置：关闭智能分类
  setVoice,             // 语音设置：开启语音播报
  setRecognition,       // 识别设置：重复检测时间改成30分钟

  // 十一、数据与同步配置
  setSync,              // 同步设置：开启自动同步、只在WiFi下同步
  setBackup,            // 备份设置：设置每天自动备份
  setStorage,           // 存储设置：来源数据保留30天

  // 十二、安全与隐私配置
  setSecurity,          // 安全设置：开启应用锁、指纹解锁
  setPrivacy,           // 隐私设置：开启隐私模式

  // 十三、网络与更新配置
  setNetwork,           // 网络设置：连接超时改成60秒
  setUpdate,            // 更新设置：开启自动更新

  // ==================== 导航相关（页面导航） ====================
  navigateTo,           // 页面导航：打开预算管理、去信用卡页面
  navigateToBookkeeping,// 记账导航：打开快速记账、语音记账
  navigateToLedger,     // 账本导航：打开账本管理、成员管理
  navigateToAccount,    // 账户导航：打开账户管理、信用卡
  navigateToBudget,     // 预算导航：打开预算、储蓄目标、债务
  navigateToStats,      // 统计导航：打开年度报告、资产总览
  navigateToData,       // 数据导航：打开导入导出、备份
  navigateToSettings,   // 设置导航：打开设置、语言、货币
  navigateToUser,       // 用户导航：打开登录、关于、帮助
  searchFunction,       // 功能搜索：找功能、哪里可以

  // ==================== 直接操作（无需进入页面） ====================
  // 记账操作
  deleteLastTransaction,// 删除最后一笔
  undoOperation,        // 撤销操作
  editLastTransaction,  // 修改刚才那笔
  copyAsTemplate,       // 复制为模板

  // 账本切换
  switchLedger,         // 切换账本
  switchToPersonal,     // 切换到个人账本
  switchToFamily,       // 切换到家庭账本

  // 账户操作
  switchDefaultAccount, // 切换默认账户
  correctBalance,       // 校正余额
  viewBalance,          // 查看余额

  // 预算操作
  resetBudget,          // 重置预算
  rolloverBudget,       // 预算结转

  // 主题切换
  toggleDarkMode,       // 切换深色模式
  enableDarkMode,       // 开启深色模式
  disableDarkMode,      // 关闭深色模式
  setThemeBlue,         // 蓝色主题
  setThemeGreen,        // 绿色主题
  setThemeRed,          // 红色主题
  setThemePurple,       // 紫色主题
  setThemeOrange,       // 橙色主题

  // 语言切换
  setLanguageZhCN,      // 切换中文
  setLanguageEnUS,      // 切换英文
  setLanguageJaJP,      // 切换日文
  setLanguageZhTW,      // 切换繁体

  // 货币切换
  setCurrencyCNY,       // 切换人民币
  setCurrencyUSD,       // 切换美元
  setCurrencyEUR,       // 切换欧元
  setCurrencyJPY,       // 切换日元

  // 开关操作
  enableAutoSync,       // 开启自动同步
  disableAutoSync,      // 关闭自动同步
  enablePrivacyMode,    // 开启隐私模式
  disablePrivacyMode,   // 关闭隐私模式
  enableAppLock,        // 开启应用锁
  disableAppLock,       // 关闭应用锁
  enableVoiceRecognition,   // 开启语音识别
  disableVoiceRecognition,  // 关闭语音识别
  enableImageRecognition,   // 开启图片识别
  disableImageRecognition,  // 关闭图片识别
  enableSmartCategory,      // 开启智能分类
  disableSmartCategory,     // 关闭智能分类
  enableDuplicateDetection, // 开启重复检测
  disableDuplicateDetection,// 关闭重复检测
  enableBookkeepingReminder,// 开启记账提醒
  disableBookkeepingReminder,// 关闭记账提醒
  enableBudgetReminder,     // 开启预算提醒
  disableBudgetReminder,    // 关闭预算提醒
  enableOfflineMode,        // 开启离线模式
  disableOfflineMode,       // 关闭离线模式

  // 数据操作
  backupNow,            // 立即备份
  syncNow,              // 立即同步
  forceRefresh,         // 强制刷新
  refresh,              // 刷新
  clearCache,           // 清除缓存
  emptyTrash,           // 清空回收站
  exportMonthData,      // 导出本月数据
  exportYearData,       // 导出本年数据
  exportAllData,        // 导出全部数据

  // 快捷操作
  openCamera,           // 打开相机
  openScanner,          // 扫一扫
  goHome,               // 返回首页

  // 习惯操作
  habitCheckIn,         // 打卡
  viewCheckInHistory,   // 查看打卡记录

  // 分享操作
  shareMonthlyReport,   // 分享月报
  shareAnnualReport,    // 分享年报
  shareTransaction,     // 分享账单
  inviteFriend,         // 邀请好友

  // 系统操作
  checkUpdate,          // 检查更新
  openFeedback,         // 提交反馈
  contactSupport,       // 联系客服
  logout,               // 退出登录
  deleteAccount,        // 注销账号

  // ==================== 查询相关 ====================
  queryExpense,         // 查询消费：花了多少、消费情况
  queryIncome,          // 查询收入：收入多少、赚了多少
  queryBudget,          // 查询预算：预算还剩、超支没
  queryMoneyAge,        // 查询钱龄：资金年龄、持有多久
  queryTrend,           // 查询趋势：趋势如何、变化
  queryReport,          // 查询报告：月报、年报、分析
  queryBalance,         // 查询余额：还剩多少、账户余额
  queryStats,           // 查询统计：本月统计、分类占比
  queryGoal,            // 查询目标：目标进度、还差多少
  queryDebt,            // 查询债务：还款进度、剩余本金

  // ==================== 其他 ====================
  chat,                 // 闲聊对话
  help,                 // 帮助引导
  cancel,               // 取消操作
  confirm,              // 确认操作
  feedback,             // 反馈问题
  unknown,              // 未识别意图
}

/// 意图识别引擎 - 双层策略：规则优先 + LLM兜底
class IntentRecognitionEngine {
  final LLMService _llmService;
  final RuleBasedMatcher _ruleMatcher;

  /// ========== 意图识别规则库（优先匹配，零成本） ==========
  /// 覆盖所有常见语音指令模式

  static const Map<VoiceIntentType, List<String>> _intentPatterns = {

    // ==================== 记账意图 ====================
    VoiceIntentType.addExpense: [
      r'(记一笔|记账|花了|买了|支出|消费了|付了|花费)',
      r'(吃饭|打车|购物|买菜|缴费).*([\d\.]+)',
      r'[\d\.]+.*(元|块|块钱).*(餐饮|交通|购物)',
    ],
    VoiceIntentType.addIncome: [
      r'(收到|入账|收入|工资|奖金|到账|发工资)',
      r'(收款|转入|进账).*([\d\.]+)',
    ],
    VoiceIntentType.addTransfer: [
      r'(从|把).*(转|转到|转入|划).*(到|给)',
      r'(转账).*([\d\.]+)',
    ],
    VoiceIntentType.batchRecord: [
      r'(记多笔|批量记|连续记|一起记)',
      r'(早餐|午餐|晚餐).*(,|，).*([\d\.]+)',
    ],
    VoiceIntentType.useTemplate: [
      r'(按模板|用模板|模板记账|常用记账)',
      r'(按照|使用).*(模板)',
    ],

    // ==================== 预算配置意图 ====================
    VoiceIntentType.setBudget: [
      r'(设置|修改|调整|把).*(预算).*(改成|设为|调到|设置成)',
      r'(餐饮|交通|购物|娱乐|居住|医疗|教育|通讯|服饰|美妆|数码).*(预算)',
      r'(月度|总|本月).*(预算).*([\d\.]+)',
    ],
    VoiceIntentType.setBudgetAlert: [
      r'(预算).*(预警|提醒|警告).*([\d]+%?)',
      r'(用到|超过|达到).*([\d]+%).*(提醒)',
    ],
    VoiceIntentType.setBudgetCycle: [
      r'(预算).*(周期|起始|开始)',
      r'(按周|按月|按年).*(预算)',
    ],
    VoiceIntentType.setBudgetRollover: [
      r'(开启|关闭|启用|禁用).*(预算).*(结转)',
      r'(预算).*(结转).*(开|关)',
    ],

    // ==================== 账户配置意图 ====================
    VoiceIntentType.setAccount: [
      r'(设为|设置|改成|切换).*(默认账户)',
      r'(添加|新增|创建).*(账户|银行卡|储蓄卡)',
      r'(微信|支付宝|现金|银行卡).*(设为|作为).*(默认)',
      r'(校正|调整).*(余额)',
    ],
    VoiceIntentType.setCreditCard: [
      r'(添加|新增).*(信用卡)',
      r'(信用卡).*(账单日|还款日).*(改成|设为|[\d]+号)',
      r'(额度|信用额度).*(设为|改成|[\d]+)',
    ],

    // ==================== 账本与成员意图 ====================
    VoiceIntentType.setLedger: [
      r'(创建|新建|添加).*(账本)',
      r'(切换|打开|进入).*(账本)',
      r'(设为|设置).*(默认账本)',
    ],
    VoiceIntentType.setMember: [
      r'(邀请|添加).*(成员|家人|朋友)',
      r'(移除|删除).*(成员)',
    ],

    // ==================== 分类配置意图 ====================
    VoiceIntentType.setCategory: [
      r'(添加|新增|创建|删除|修改).*(分类|类别)',
      r'(分类).*(添加|删除|改名)',
    ],
    VoiceIntentType.setSubCategory: [
      r'(给|在).*(添加|新增).*(子分类)',
      r'(添加).*(子分类).*(到|给)',
    ],
    VoiceIntentType.setTag: [
      r'(创建|添加|删除).*(标签)',
    ],

    // ==================== 目标与债务意图 ====================
    VoiceIntentType.setSavingsGoal: [
      r'(创建|设置|添加).*(储蓄目标|攒钱目标|存钱目标)',
      r'(目标).*(金额|日期|截止)',
      r'(自动存入|每月存入)',
    ],
    VoiceIntentType.setExpenseTarget: [
      r'(创建|设置).*(开支目标|消费目标|花钱目标)',
      r'(月度限额|每月限额)',
    ],
    VoiceIntentType.setDebt: [
      r'(添加|记录).*(债务|欠款|贷款|房贷|车贷)',
      r'(利率|还款).*(设置|调整)',
    ],

    // ==================== 提醒配置意图 ====================
    VoiceIntentType.setReminder: [
      r'(设置|添加|取消|关闭).*(提醒|通知)',
      r'(每天|每周|每月).*([\d]+点).*(提醒)',
      r'(提醒我|通知我)',
    ],
    VoiceIntentType.setBillReminder: [
      r'(信用卡|还款).*(提醒)',
      r'(提前).*([\d]+天).*(提醒)',
    ],

    // ==================== 模板与定时意图 ====================
    VoiceIntentType.setTemplate: [
      r'(保存|创建|删除).*(模板)',
      r'(刚才|这笔).*(保存为|存为).*(模板)',
    ],
    VoiceIntentType.setRecurring: [
      r'(每月|每周|每天).*([\d]+号?).*(自动|定时).*(记)',
      r'(定时记账|周期记账|自动记账)',
    ],

    // ==================== 外观配置意图 ====================
    VoiceIntentType.setTheme: [
      r'(切换|换成|改成).*(深色|浅色|暗色|亮色).*(模式)?',
      r'(主题).*(改成|换成|切换).*(蓝色|绿色|红色|紫色|橙色)',
    ],
    VoiceIntentType.setHomeLayout: [
      r'(隐藏|显示|调整).*(卡片|首页)',
      r'(首页).*(布局|排序)',
    ],

    // ==================== 国际化配置意图 ====================
    VoiceIntentType.setLanguage: [
      r'(切换|改成|换成).*(中文|英文|日文|韩文|繁体)',
      r'(语言).*(设置|切换|改成)',
    ],
    VoiceIntentType.setCurrency: [
      r'(切换|改成).*(人民币|美元|欧元|日元|港币|英镑)',
      r'(货币|默认货币).*(设置|切换|改成)',
    ],

    // ==================== AI配置意图 ====================
    VoiceIntentType.setAI: [
      r'(开启|关闭|启用|禁用).*(智能分类|AI分类)',
      r'(智能建议|消费洞察).*(开|关)',
    ],
    VoiceIntentType.setVoice: [
      r'(开启|关闭).*(语音播报|语音识别)',
      r'(语音).*(唤醒词|语言)',
    ],
    VoiceIntentType.setRecognition: [
      r'(重复检测).*(时间|时间窗口)',
      r'(金额容差).*(设置|改成)',
    ],

    // ==================== 同步与备份意图 ====================
    VoiceIntentType.setSync: [
      r'(开启|关闭).*(自动同步|云同步)',
      r'(只在|仅在).*(WiFi).*(同步)',
    ],
    VoiceIntentType.setBackup: [
      r'(设置|开启|关闭).*(自动备份)',
      r'(备份).*(频率|保留)',
    ],

    // ==================== 安全配置意图 ====================
    VoiceIntentType.setSecurity: [
      r'(开启|关闭).*(应用锁|指纹|面容|PIN)',
      r'(自动锁定).*(时间)',
    ],
    VoiceIntentType.setPrivacy: [
      r'(开启|关闭).*(隐私模式|截图保护)',
      r'(金额).*(模糊|隐藏)',
    ],

    // ==================== 页面导航意图 ====================
    VoiceIntentType.navigateTo: [
      r'(打开|去|进入|跳转|看看|查看).*(页面|功能)',
    ],
    VoiceIntentType.navigateToBookkeeping: [
      r'(打开|去).*(记账|快速记账|语音记账|图片记账|拍照记账)',
      r'(我要|我想).*(记一笔|记账)',
    ],
    VoiceIntentType.navigateToLedger: [
      r'(打开|去|进入).*(账本|成员|邀请)',
    ],
    VoiceIntentType.navigateToAccount: [
      r'(打开|去|查看).*(账户|信用卡|投资)',
    ],
    VoiceIntentType.navigateToBudget: [
      r'(打开|去|查看).*(预算|储蓄目标|开支目标|债务|还款)',
    ],
    VoiceIntentType.navigateToStats: [
      r'(打开|去|查看).*(统计|报表|年度报告|月报|资产|趋势)',
    ],
    VoiceIntentType.navigateToData: [
      r'(打开|去).*(导入|导出|备份|恢复|智能导入)',
    ],
    VoiceIntentType.navigateToSettings: [
      r'(打开|去|进入).*(设置|语言设置|货币设置|主题设置)',
    ],
    VoiceIntentType.navigateToUser: [
      r'(打开|去).*(登录|注册|关于|帮助|用户协议)',
    ],
    VoiceIntentType.searchFunction: [
      r'(怎么|如何|哪里).*(设置|修改|查看|导出)',
      r'(找|搜索).*(功能|页面)',
    ],

    // ==================== 直接操作意图 - 记账 ====================
    VoiceIntentType.deleteLastTransaction: [
      r'(删除|删掉).*(最后一笔|刚才那笔|上一笔)',
    ],
    VoiceIntentType.undoOperation: [
      r'(撤销|撤回|取消).*(上次|刚才)?(操作)?',
    ],
    VoiceIntentType.editLastTransaction: [
      r'(修改|编辑).*(刚才|最后|上一笔)',
    ],
    VoiceIntentType.copyAsTemplate: [
      r'(复制|保存).*(为|成).*(模板)',
    ],

    // ==================== 直接操作意图 - 账本切换 ====================
    VoiceIntentType.switchLedger: [
      r'(切换|换到|打开).*(账本)',
    ],
    VoiceIntentType.switchToPersonal: [
      r'(切换|换到).*(个人|我的).*(账本)',
    ],
    VoiceIntentType.switchToFamily: [
      r'(切换|换到).*(家庭|共享).*(账本)',
    ],

    // ==================== 直接操作意图 - 主题 ====================
    VoiceIntentType.toggleDarkMode: [
      r'(切换).*(深色|暗色).*(模式)',
    ],
    VoiceIntentType.enableDarkMode: [
      r'(开启|打开|启用).*(深色|暗色).*(模式)',
    ],
    VoiceIntentType.disableDarkMode: [
      r'(关闭|关掉|禁用).*(深色|暗色).*(模式)',
      r'(切换|换成).*(浅色|亮色).*(模式)',
    ],
    VoiceIntentType.setThemeBlue: [
      r'(切换|换成).*(蓝色).*(主题)',
    ],
    VoiceIntentType.setThemeGreen: [
      r'(切换|换成).*(绿色).*(主题)',
    ],
    VoiceIntentType.setThemeRed: [
      r'(切换|换成).*(红色).*(主题)',
    ],
    VoiceIntentType.setThemePurple: [
      r'(切换|换成).*(紫色).*(主题)',
    ],
    VoiceIntentType.setThemeOrange: [
      r'(切换|换成).*(橙色).*(主题)',
    ],

    // ==================== 直接操作意图 - 语言 ====================
    VoiceIntentType.setLanguageZhCN: [
      r'(切换|换成).*(中文|简体)',
    ],
    VoiceIntentType.setLanguageEnUS: [
      r'(切换|换成).*(英文|英语)',
    ],
    VoiceIntentType.setLanguageJaJP: [
      r'(切换|换成).*(日文|日语)',
    ],
    VoiceIntentType.setLanguageZhTW: [
      r'(切换|换成).*(繁体)',
    ],

    // ==================== 直接操作意图 - 货币 ====================
    VoiceIntentType.setCurrencyCNY: [
      r'(切换|换成).*(人民币|CNY|元)',
    ],
    VoiceIntentType.setCurrencyUSD: [
      r'(切换|换成).*(美元|美金|USD)',
    ],
    VoiceIntentType.setCurrencyEUR: [
      r'(切换|换成).*(欧元|EUR)',
    ],
    VoiceIntentType.setCurrencyJPY: [
      r'(切换|换成).*(日元|日币|JPY)',
    ],

    // ==================== 直接操作意图 - 开关 ====================
    VoiceIntentType.enableAutoSync: [
      r'(开启|打开|启用).*(自动同步)',
    ],
    VoiceIntentType.disableAutoSync: [
      r'(关闭|关掉|禁用).*(自动同步)',
    ],
    VoiceIntentType.enablePrivacyMode: [
      r'(开启|打开).*(隐私模式)',
      r'(隐藏|遮住).*(金额)',
    ],
    VoiceIntentType.disablePrivacyMode: [
      r'(关闭|关掉).*(隐私模式)',
      r'(显示|展示).*(金额)',
    ],
    VoiceIntentType.enableAppLock: [
      r'(开启|打开).*(应用锁)',
    ],
    VoiceIntentType.disableAppLock: [
      r'(关闭|关掉).*(应用锁)',
    ],
    VoiceIntentType.enableSmartCategory: [
      r'(开启|打开).*(智能分类)',
    ],
    VoiceIntentType.disableSmartCategory: [
      r'(关闭|关掉).*(智能分类)',
    ],
    VoiceIntentType.enableBookkeepingReminder: [
      r'(开启|打开).*(记账提醒)',
    ],
    VoiceIntentType.disableBookkeepingReminder: [
      r'(关闭|关掉).*(记账提醒)',
    ],

    // ==================== 直接操作意图 - 数据 ====================
    VoiceIntentType.backupNow: [
      r'(立即|马上|现在).*(备份)',
      r'(备份).*(数据)',
    ],
    VoiceIntentType.syncNow: [
      r'(立即|马上|现在).*(同步)',
      r'(同步).*(数据)',
    ],
    VoiceIntentType.refresh: [
      r'(刷新).*(数据)?',
    ],
    VoiceIntentType.forceRefresh: [
      r'(强制|强行).*(刷新)',
    ],
    VoiceIntentType.clearCache: [
      r'(清除|清理|清空).*(缓存)',
    ],
    VoiceIntentType.emptyTrash: [
      r'(清空|清理).*(回收站)',
    ],
    VoiceIntentType.exportMonthData: [
      r'(导出).*(本月|这个月).*(数据)',
    ],
    VoiceIntentType.exportYearData: [
      r'(导出).*(本年|今年|全年).*(数据)',
    ],
    VoiceIntentType.exportAllData: [
      r'(导出).*(全部|所有).*(数据)',
    ],

    // ==================== 直接操作意图 - 快捷 ====================
    VoiceIntentType.openCamera: [
      r'(打开|开启).*(相机|摄像头)',
    ],
    VoiceIntentType.openScanner: [
      r'(扫一扫|扫码|开始扫码)',
    ],
    VoiceIntentType.goHome: [
      r'(返回|回到|去).*(首页|主页)',
    ],

    // ==================== 直接操作意图 - 习惯 ====================
    VoiceIntentType.habitCheckIn: [
      r'(打卡|记账打卡|今天打卡)',
    ],
    VoiceIntentType.viewCheckInHistory: [
      r'(查看|看看).*(打卡|打卡记录)',
    ],

    // ==================== 直接操作意图 - 分享 ====================
    VoiceIntentType.shareMonthlyReport: [
      r'(分享).*(月报|月度报告)',
    ],
    VoiceIntentType.shareAnnualReport: [
      r'(分享).*(年报|年度报告)',
    ],
    VoiceIntentType.shareTransaction: [
      r'(分享).*(账单|这笔)',
    ],
    VoiceIntentType.inviteFriend: [
      r'(邀请).*(好友|朋友)',
    ],

    // ==================== 直接操作意图 - 系统 ====================
    VoiceIntentType.checkUpdate: [
      r'(检查|查看).*(更新)',
    ],
    VoiceIntentType.openFeedback: [
      r'(提交|发送).*(反馈|建议)',
    ],
    VoiceIntentType.contactSupport: [
      r'(联系|找).*(客服)',
    ],
    VoiceIntentType.logout: [
      r'(退出|注销).*(登录)',
    ],
    VoiceIntentType.deleteAccount: [
      r'(注销|删除).*(账号|账户)',
    ],

    // ==================== 查询意图 ====================
    VoiceIntentType.queryExpense: [
      r'(这个月|今天|上周|本周|昨天).*(花了|消费|支出)',
      r'(花了多少|消费情况|支出统计)',
      r'(餐饮|交通|购物).*(花了|消费)',
    ],
    VoiceIntentType.queryIncome: [
      r'(这个月|今天|上周).*(收入|入账|赚了)',
      r'(收入多少|赚了多少)',
    ],
    VoiceIntentType.queryBudget: [
      r'(预算).*(还剩|剩余|超支|够不够)',
      r'(.*预算).*(情况|多少)',
    ],
    VoiceIntentType.queryMoneyAge: [
      r'(钱龄|资金年龄|持有多久|存了多久)',
      r'(资金).*(结构|分布|健康)',
    ],
    VoiceIntentType.queryTrend: [
      r'(趋势|变化|对比|环比|同比)',
    ],
    VoiceIntentType.queryBalance: [
      r'(还剩|余额|账户).*(多少|情况)',
    ],
    VoiceIntentType.queryStats: [
      r'(本月|这个月).*(统计|分析)',
      r'(分类).*(占比|比例)',
    ],
    VoiceIntentType.queryGoal: [
      r'(目标).*(进度|完成|还差)',
      r'(储蓄|攒钱).*(进度)',
    ],
    VoiceIntentType.queryDebt: [
      r'(债务|欠款|贷款).*(进度|剩余|还欠)',
    ],

    // ==================== 反馈意图 ====================
    VoiceIntentType.feedback: [
      r'(反馈|建议|问题|投诉)',
      r'(我要|我想).*(反馈|吐槽)',
    ],

    // ==================== 帮助意图 ====================
    VoiceIntentType.help: [
      r'(帮助|怎么用|使用说明)',
      r'(教我|告诉我).*(怎么|如何)',
    ],

    // ==================== 取消/确认 ====================
    VoiceIntentType.cancel: [
      r'(取消|算了|不要了|不用了)',
    ],
    VoiceIntentType.confirm: [
      r'(确认|确定|是的|好的|可以|没问题)',
    ],
  };

  /// 识别用户意图
  Future<VoiceIntent> recognizeIntent(String voiceText) async {
    // ===== 第一层：规则匹配（快速、确定性高、零成本） =====
    final ruleResult = _ruleMatcher.match(voiceText, _intentPatterns);
    if (ruleResult != null && ruleResult.confidence > 0.8) {
      return VoiceIntent(
        type: ruleResult.intentType,
        confidence: ruleResult.confidence,
        entities: ruleResult.entities,
        source: IntentSource.rule,
        rawText: voiceText,
      );
    }

    // ===== 第二层：大模型语义理解（处理复杂表达） =====
    try {
      final llmResult = await _llmService.recognizeVoiceIntent(
        text: voiceText,
        availableIntents: VoiceIntentType.values.map((e) => e.name).toList(),
        intentDescriptions: _getIntentDescriptions(),
      );

      if (llmResult.confidence > 0.6) {
        return VoiceIntent(
          type: _parseIntentType(llmResult.intentName),
          confidence: llmResult.confidence,
          entities: llmResult.entities,
          source: IntentSource.llm,
          rawText: voiceText,
        );
      }
    } catch (e) {
      debugPrint('LLM intent recognition failed: $e');
    }

    // ===== 兜底：返回未知意图 =====
    return VoiceIntent(
      type: VoiceIntentType.unknown,
      confidence: 0.0,
      entities: {},
      source: IntentSource.fallback,
      rawText: voiceText,
    );
  }

  /// 获取意图描述（用于LLM理解）
  Map<String, String> _getIntentDescriptions() {
    return {
      'addExpense': '记录一笔支出/消费',
      'addIncome': '记录一笔收入',
      'setBudget': '设置或修改预算金额',
      'navigateTo': '打开某个页面或功能',
      'toggleDarkMode': '切换深色/浅色模式',
      'setLanguageZhCN': '切换到中文',
      'setLanguageEnUS': '切换到英文',
      'enableAutoSync': '开启自动同步',
      'disableAutoSync': '关闭自动同步',
      'backupNow': '立即备份数据',
      'syncNow': '立即同步数据',
      'habitCheckIn': '记账打卡',
      'queryExpense': '查询消费/支出情况',
      'queryBudget': '查询预算剩余情况',
      'feedback': '用户想要反馈问题或建议',
      // ... 其他意图描述
    };
  }
}

/// 语音意图数据类
class VoiceIntent {
  final VoiceIntentType type;
  final double confidence;
  final Map<String, dynamic> entities;  // 提取的实体：金额、分类、日期等
  final IntentSource source;
  final String rawText;

  VoiceIntent({
    required this.type,
    required this.confidence,
    required this.entities,
    required this.source,
    required this.rawText,
  });

  /// 是否为直接操作意图（无需进入页面即可执行）
  bool get isDirectAction => _directActionIntents.contains(type);

  /// 是否为导航意图
  bool get isNavigation => type.name.startsWith('navigateTo');

  /// 是否为配置意图
  bool get isConfiguration => type.name.startsWith('set');

  /// 是否为查询意图
  bool get isQuery => type.name.startsWith('query');

  /// 是否需要确认
  bool get needsConfirmation => _confirmationRequiredIntents.contains(type);

  static const Set<VoiceIntentType> _directActionIntents = {
    VoiceIntentType.deleteLastTransaction,
    VoiceIntentType.undoOperation,
    VoiceIntentType.toggleDarkMode,
    VoiceIntentType.enableDarkMode,
    VoiceIntentType.disableDarkMode,
    VoiceIntentType.setThemeBlue,
    VoiceIntentType.setThemeGreen,
    VoiceIntentType.setThemeRed,
    VoiceIntentType.setThemePurple,
    VoiceIntentType.setThemeOrange,
    VoiceIntentType.setLanguageZhCN,
    VoiceIntentType.setLanguageEnUS,
    VoiceIntentType.setLanguageJaJP,
    VoiceIntentType.setLanguageZhTW,
    VoiceIntentType.setCurrencyCNY,
    VoiceIntentType.setCurrencyUSD,
    VoiceIntentType.setCurrencyEUR,
    VoiceIntentType.setCurrencyJPY,
    VoiceIntentType.enableAutoSync,
    VoiceIntentType.disableAutoSync,
    VoiceIntentType.enablePrivacyMode,
    VoiceIntentType.disablePrivacyMode,
    VoiceIntentType.backupNow,
    VoiceIntentType.syncNow,
    VoiceIntentType.refresh,
    VoiceIntentType.habitCheckIn,
    VoiceIntentType.openCamera,
    VoiceIntentType.openScanner,
    VoiceIntentType.goHome,
  };

  static const Set<VoiceIntentType> _confirmationRequiredIntents = {
    VoiceIntentType.deleteLastTransaction,
    VoiceIntentType.emptyTrash,
    VoiceIntentType.logout,
    VoiceIntentType.deleteAccount,
    VoiceIntentType.resetBudget,
    VoiceIntentType.exportAllData,
    VoiceIntentType.enableAppLock,
    VoiceIntentType.disableAppLock,
  };
}

enum IntentSource { rule, llm, fallback }
```
