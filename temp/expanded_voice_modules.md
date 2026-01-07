#### 15.12.3 智能语音配置模块

本模块支持通过语音修改系统中几乎所有的配置项，实现"动口不动手"的配置体验。

##### 15.12.3.1 可配置项全景图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      语音可配置项全景图                                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           预算与财务配置                                  │   │
│  ├───────────────────┬───────────────────┬──────────────────────────────��┤   │
│  │ 分类预算设置       │ 总预算设置         │ 预算周期设置                    │   │
│  │ • 餐饮/交通/购物   │ • 月度总预算       │ • 周预算/月预算                 │   │
│  │ • 娱乐/居住/医疗   │ • 预算预警阈值     │ • 预算起始日                   │   │
│  │ • 教育/通讯/其他   │ • 超支处理策略     │ • 自动结转设置                 │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           账户与资产配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 账户管理           │ 小金库管理         │ 储蓄目标                       │   │
│  │ • 添加/删除账户    │ • 创建/调整小金库   │ • 创建储蓄目标                 │   │
│  │ • 设置默认账户     │ • 设置每月存入额    │ • 调整目标金额                 │   │
│  │ • 账户余额校正     │ • 小金库优先级     │ • 修改目标日期                 │   │
│  │ • 账户图标/颜色    │ • 自动划转规则     │ • 暂停/恢复目标                │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           分类与标签配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 分类管理           │ 标签管理           │ 商户绑定                       │   │
│  │ • 添加/删除分类    │ • 创建/删除标签    │ • 商户→分类绑定               │   │
│  │ • 修改分类名称     │ • 标签颜色设置     │ • 商户→账户绑定               │   │
│  │ • 分类图标设置     │ • 常用标签排序     │ • 商户别名设置                 │   │
│  │ • 分类���序调整     │                   │                               │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           提醒与通知配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 记账提醒           │ 预算提醒           │ 账单提醒                       │   │
│  │ • 每日记账提醒时间  │ • 预算预警阈值     │ • 信用卡还款提醒               │   │
│  │ • 提醒频率         │ • 超支实时通知     │ • 周期账单提醒                 │   │
│  │ • 提醒方式         │ • 周/月预算总结    │ • 订阅续费提醒                 │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌────────────────��────────────────────────────────────────────────────────┐   │
│  │                           显示与体验配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 外观设置           │ 首页布局           │ 数据显示                       │   │
│  │ • 主题切换         │ • 卡片显示/隐藏    │ • 默认时间范围                 │   │
│  │ • 深色/浅色模式    │ • 卡片排序         │ • 金额显示格式                 │   │
│  │ • 强调色设置       │ • 快捷入口配置     │ • 图表默认类型                 │   │
│  │ • 字体大小         │ • 底部导航配置     │ • 隐私模式                    │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           AI与智能配置                                    │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ AI识别设置         │ 语音设置           │ 智能建议                       │   │
│  │ • 自动分类开关     │ • 语音识别引擎     │ • 智能建议开关                 │   │
│  │ • 分类确认阈值     │ • 语音唤醒词       │ • 消费洞察通知                 │   │
│  │ • 商户识别开关     │ • 语音播报开关     │ • 习惯培养提醒                 │   │
│  │ • 图片识别质量     │ • 语音语言         │ • 财务健康报告                 │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           系统与安全配置                                  │   │
│  ├───────────────────┬───────────────────┬───────────────────────────────┤   │
│  │ 安全设置           │ 数据设置           │ 国际化                        │   │
│  │ • 应用锁开关       │ • 自动备份频率     │ • 语言切换                    │   │
│  │ • 生物识别         │ • 云同步开关       │ • 货币设置                    │   │
│  │ • 隐私模式         │ • 数据保留期限     │ • 日期格式                    │   │
│  │ • 截图保护         │ • 缓存清理         │ • 数字格式                    │   │
│  └───────────────────┴───────────────────┴───────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.3.2 配置服务实现

```dart
/// 语音配置服务 - 通过语音修改系统中的各项配置
class VoiceConfigurationService {
  final BudgetRepository _budgetRepo;
  final CategoryRepository _categoryRepo;
  final AccountRepository _accountRepo;
  final VaultRepository _vaultRepo;
  final SavingsGoalRepository _savingsGoalRepo;
  final ReminderRepository _reminderRepo;
  final SettingsRepository _settingsRepo;
  final MerchantRepository _merchantRepo;
  final EntityExtractor _entityExtractor;
  final LLMService _llmService;

  /// ========== 完整配置项映射表 ==========
  /// 覆盖系统中所有可通过语音配置的项目

  static const Map<String, ConfigurableItem> _configurableItems = {
    // ===== 预算配置 =====
    '餐饮预算': ConfigurableItem(type: ConfigType.budget, key: 'food', category: '预算'),
    '交通预算': ConfigurableItem(type: ConfigType.budget, key: 'transport', category: '预算'),
    '购物预算': ConfigurableItem(type: ConfigType.budget, key: 'shopping', category: '预算'),
    '娱乐预算': ConfigurableItem(type: ConfigType.budget, key: 'entertainment', category: '预算'),
    '居住预算': ConfigurableItem(type: ConfigType.budget, key: 'housing', category: '预算'),
    '医疗预算': ConfigurableItem(type: ConfigType.budget, key: 'medical', category: '预算'),
    '教育预算': ConfigurableItem(type: ConfigType.budget, key: 'education', category: '预算'),
    '通讯预算': ConfigurableItem(type: ConfigType.budget, key: 'communication', category: '预算'),
    '总预算': ConfigurableItem(type: ConfigType.budget, key: 'total', category: '预算'),
    '预算预警': ConfigurableItem(type: ConfigType.budgetAlert, key: 'threshold', category: '预算'),
    '预算周期': ConfigurableItem(type: ConfigType.budgetCycle, key: 'cycle', category: '预算'),

    // ===== 账户配置 =====
    '默认账户': ConfigurableItem(type: ConfigType.account, key: 'default', category: '账户'),
    '现金账户': ConfigurableItem(type: ConfigType.account, key: 'cash', category: '账户'),
    '银行卡': ConfigurableItem(type: ConfigType.account, key: 'bank', category: '账户'),
    '支付宝': ConfigurableItem(type: ConfigType.account, key: 'alipay', category: '账户'),
    '微信': ConfigurableItem(type: ConfigType.account, key: 'wechat', category: '账户'),
    '信用卡': ConfigurableItem(type: ConfigType.account, key: 'credit', category: '账户'),

    // ===== 小金库配置 =====
    '小金库': ConfigurableItem(type: ConfigType.vault, key: 'vault', category: '小金库'),
    '自动划转': ConfigurableItem(type: ConfigType.vaultTransfer, key: 'auto_transfer', category: '小金库'),

    // ===== 储蓄目标配置 =====
    '储蓄目标': ConfigurableItem(type: ConfigType.savingsGoal, key: 'goal', category: '储蓄'),

    // ===== 分类配置 =====
    '分类': ConfigurableItem(type: ConfigType.category, key: 'category', category: '分类'),
    '子分类': ConfigurableItem(type: ConfigType.subCategory, key: 'sub_category', category: '分类'),

    // ===== 提醒配置 =====
    '记账提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bookkeeping', category: '提醒'),
    '预算提醒': ConfigurableItem(type: ConfigType.reminder, key: 'budget_alert', category: '提醒'),
    '账单提醒': ConfigurableItem(type: ConfigType.reminder, key: 'bill', category: '提醒'),
    '还款提醒': ConfigurableItem(type: ConfigType.reminder, key: 'repayment', category: '提醒'),
    '订阅提醒': ConfigurableItem(type: ConfigType.reminder, key: 'subscription', category: '提醒'),
    '周报提醒': ConfigurableItem(type: ConfigType.reminder, key: 'weekly_report', category: '提醒'),
    '月报提醒': ConfigurableItem(type: ConfigType.reminder, key: 'monthly_report', category: '提醒'),

    // ===== 外观配置 =====
    '主题': ConfigurableItem(type: ConfigType.appearance, key: 'theme', category: '外观'),
    '深色模式': ConfigurableItem(type: ConfigType.appearance, key: 'dark_mode', category: '外观'),
    '强调色': ConfigurableItem(type: ConfigType.appearance, key: 'accent_color', category: '外观'),
    '字体大小': ConfigurableItem(type: ConfigType.appearance, key: 'font_size', category: '外观'),

    // ===== 首页配置 =====
    '首页卡片': ConfigurableItem(type: ConfigType.homeLayout, key: 'cards', category: '首页'),
    '快捷入口': ConfigurableItem(type: ConfigType.homeLayout, key: 'shortcuts', category: '首页'),
    '底部导航': ConfigurableItem(type: ConfigType.homeLayout, key: 'bottom_nav', category: '首页'),

    // ===== AI配置 =====
    '自动分类': ConfigurableItem(type: ConfigType.ai, key: 'auto_category', category: 'AI'),
    '智能建议': ConfigurableItem(type: ConfigType.ai, key: 'smart_suggestion', category: 'AI'),
    '消费洞察': ConfigurableItem(type: ConfigType.ai, key: 'spending_insight', category: 'AI'),
    '语音识别': ConfigurableItem(type: ConfigType.ai, key: 'voice_recognition', category: 'AI'),
    '语音唤醒': ConfigurableItem(type: ConfigType.ai, key: 'voice_wakeup', category: 'AI'),
    '语音播报': ConfigurableItem(type: ConfigType.ai, key: 'voice_broadcast', category: 'AI'),

    // ===== 安全配置 =====
    '应用锁': ConfigurableItem(type: ConfigType.security, key: 'app_lock', category: '安全'),
    '指纹解锁': ConfigurableItem(type: ConfigType.security, key: 'fingerprint', category: '安全'),
    '面容解锁': ConfigurableItem(type: ConfigType.security, key: 'face_id', category: '安全'),
    '隐私模式': ConfigurableItem(type: ConfigType.security, key: 'privacy_mode', category: '安全'),
    '截图保护': ConfigurableItem(type: ConfigType.security, key: 'screenshot_protection', category: '安全'),

    // ===== 数据配置 =====
    '自动备份': ConfigurableItem(type: ConfigType.data, key: 'auto_backup', category: '数据'),
    '云同步': ConfigurableItem(type: ConfigType.data, key: 'cloud_sync', category: '数据'),
    '备份频率': ConfigurableItem(type: ConfigType.data, key: 'backup_frequency', category: '数据'),

    // ===== 国际化配置 =====
    '语言': ConfigurableItem(type: ConfigType.i18n, key: 'language', category: '国际化'),
    '货币': ConfigurableItem(type: ConfigType.i18n, key: 'currency', category: '国际化'),
    '日期格式': ConfigurableItem(type: ConfigType.i18n, key: 'date_format', category: '国际化'),

    // ===== 商户绑定 =====
    '商户分类': ConfigurableItem(type: ConfigType.merchant, key: 'category_binding', category: '商户'),
    '商户账户': ConfigurableItem(type: ConfigType.merchant, key: 'account_binding', category: '商户'),
  };

  /// 配置值选项映射（用于有限选项的配置项）
  static const Map<String, Map<String, dynamic>> _configValueOptions = {
    'theme': {
      '浅色': 'light', '亮色': 'light', '白色': 'light',
      '深色': 'dark', '暗色': 'dark', '黑色': 'dark',
      '跟随系统': 'system', '自动': 'system',
    },
    'language': {
      '中文': 'zh_CN', '简体中文': 'zh_CN',
      '英文': 'en_US', '英语': 'en_US',
      '日文': 'ja_JP', '日语': 'ja_JP',
    },
    'currency': {
      '人民币': 'CNY', '元': 'CNY',
      '美元': 'USD', '刀': 'USD',
      '欧元': 'EUR',
      '日元': 'JPY', '円': 'JPY',
      '港币': 'HKD',
    },
    'font_size': {
      '小': 'small', '正常': 'medium', '默认': 'medium',
      '大': 'large', '特大': 'xlarge',
    },
    'backup_frequency': {
      '每天': 'daily', '每日': 'daily',
      '每周': 'weekly',
      '每月': 'monthly',
      '从不': 'never', '关闭': 'never',
    },
    'budget_cycle': {
      '周': 'weekly', '每周': 'weekly',
      '月': 'monthly', '每月': 'monthly',
      '年': 'yearly', '每年': 'yearly',
    },
    'accent_color': {
      '蓝色': 'blue', '绿色': 'green', '红色': 'red',
      '橙色': 'orange', '紫色': 'purple', '粉色': 'pink',
      '青色': 'teal', '黄色': 'yellow',
    },
  };

  /// 处理语音配置请求
  Future<VoiceConfigResult> processVoiceConfig({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    // 1. 使用LLM进行复杂语义理解
    final configIntent = await _parseConfigIntent(voiceText);

    // 2. 根据配置类型分发处理
    switch (configIntent.configType) {
      case ConfigType.budget:
      case ConfigType.budgetAlert:
      case ConfigType.budgetCycle:
        return await _processBudgetConfig(voiceText, configIntent);

      case ConfigType.account:
        return await _processAccountConfig(voiceText, configIntent);

      case ConfigType.vault:
      case ConfigType.vaultTransfer:
        return await _processVaultConfig(voiceText, configIntent);

      case ConfigType.savingsGoal:
        return await _processSavingsGoalConfig(voiceText, configIntent);

      case ConfigType.category:
      case ConfigType.subCategory:
        return await _processCategoryConfig(voiceText, configIntent);

      case ConfigType.reminder:
        return await _processReminderConfig(voiceText, configIntent);

      case ConfigType.appearance:
      case ConfigType.homeLayout:
        return await _processAppearanceConfig(voiceText, configIntent);

      case ConfigType.ai:
        return await _processAIConfig(voiceText, configIntent);

      case ConfigType.security:
        return await _processSecurityConfig(voiceText, configIntent);

      case ConfigType.data:
        return await _processDataConfig(voiceText, configIntent);

      case ConfigType.i18n:
        return await _processI18nConfig(voiceText, configIntent);

      case ConfigType.merchant:
        return await _processMerchantConfig(voiceText, configIntent);

      default:
        return VoiceConfigResult.error('不支持的配置类型');
    }
  }

  /// 使用LLM解析配置意图
  Future<ConfigIntent> _parseConfigIntent(String voiceText) async {
    // 首先尝试规则匹配
    for (final entry in _configurableItems.entries) {
      if (voiceText.contains(entry.key)) {
        return ConfigIntent(
          configType: entry.value.type,
          targetKey: entry.value.key,
          operation: _parseOperation(voiceText),
          rawText: voiceText,
        );
      }
    }

    // 规则匹配失败，使用LLM
    final llmResult = await _llmService.parseConfigIntent(
      text: voiceText,
      availableConfigs: _configurableItems.keys.toList(),
    );

    return ConfigIntent(
      configType: _parseConfigType(llmResult.configType),
      targetKey: llmResult.targetKey,
      targetValue: llmResult.targetValue,
      operation: llmResult.operation,
      rawText: voiceText,
    );
  }

  /// 处理预算配置
  Future<VoiceConfigResult> _processBudgetConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    // 提取金额
    final entities = await _entityExtractor.extractFromText(voiceText);
    final amount = entities.amount;

    // 提取百分比（用于预警阈值）
    final percentMatch = RegExp(r'(\d+)\s*[%％]').firstMatch(voiceText);
    final percentage = percentMatch != null
        ? int.tryParse(percentMatch.group(1)!)
        : null;

    if (configIntent.configType == ConfigType.budgetAlert) {
      // 设置预算预警阈值
      if (percentage == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问预算用到百分之多少时提醒您？',
          options: ['70%', '80%', '90%'],
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.budgetAlert,
        targetKey: 'threshold',
        newValue: percentage,
        summary: '设置预算预警阈值为$percentage%',
      );
    }

    if (configIntent.configType == ConfigType.budgetCycle) {
      // 设置预算周期
      String? cycle;
      for (final entry in _configValueOptions['budget_cycle']!.entries) {
        if (voiceText.contains(entry.key)) {
          cycle = entry.value;
          break;
        }
      }

      if (cycle == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您要设置什么周期的预算？',
          options: ['周预算', '月预算', '年预算'],
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.budgetCycle,
        targetKey: 'cycle',
        newValue: cycle,
        summary: '设置预算周期为${_getCycleDisplayName(cycle)}',
      );
    }

    // 普通预算设置
    if (amount == null || amount <= 0) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请问您要将预算设为多少？',
        expectingType: ExpectingType.amount,
      );
    }

    final categoryKey = configIntent.targetKey;
    final currentBudget = await _budgetRepo.getBudgetByCategory(categoryKey);

    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.budget,
      targetKey: categoryKey,
      oldValue: currentBudget?.amount ?? 0,
      newValue: amount,
      summary: '将${_getCategoryDisplayName(categoryKey)}预算从${currentBudget?.amount ?? 0}元修改为${amount}元',
    );
  }

  /// 处理账户配置
  Future<VoiceConfigResult> _processAccountConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    final operation = configIntent.operation;

    if (operation == ConfigOperation.setDefault) {
      // 设置默认账户
      final accountName = await _extractAccountName(voiceText);
      if (accountName == null) {
        final accounts = await _accountRepo.getAll();
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您要将哪个账户设为默认？',
          options: accounts.map((a) => a.name).take(5).toList(),
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.account,
        operation: ConfigOperation.setDefault,
        targetKey: accountName,
        summary: '将"$accountName"设为默认账户',
      );
    }

    if (operation == ConfigOperation.add) {
      // 添加账户
      final accountName = await _extractAccountName(voiceText);
      final entities = await _entityExtractor.extractFromText(voiceText);

      if (accountName == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请告诉我账户的名称',
          expectingType: ExpectingType.text,
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.account,
        operation: ConfigOperation.add,
        targetKey: accountName,
        newValue: {'name': accountName, 'balance': entities.amount ?? 0},
        summary: '创建账户"$accountName"${entities.amount != null ? "，初始余额${entities.amount}元" : ""}',
      );
    }

    if (operation == ConfigOperation.modify) {
      // 修改账户余额
      final accountName = await _extractAccountName(voiceText);
      final entities = await _entityExtractor.extractFromText(voiceText);

      if (accountName == null || entities.amount == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请告诉我要修改哪个账户的余额为多少',
          expectingType: ExpectingType.text,
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.account,
        operation: ConfigOperation.modify,
        targetKey: accountName,
        newValue: entities.amount,
        summary: '将"$accountName"的余额修改为${entities.amount}元',
      );
    }

    return VoiceConfigResult.error('不支持的账户操作');
  }

  /// 处理外观配置
  Future<VoiceConfigResult> _processAppearanceConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    final key = configIntent.targetKey;

    // 主题设置
    if (key == 'theme' || key == 'dark_mode') {
      String? theme;
      for (final entry in _configValueOptions['theme']!.entries) {
        if (voiceText.contains(entry.key)) {
          theme = entry.value;
          break;
        }
      }

      if (theme == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您想切换到什么主题？',
          options: ['浅色模式', '深色模式', '跟随系统'],
        );
      }

      return VoiceConfigResult.executeDirectly(
        configType: ConfigType.appearance,
        targetKey: 'theme',
        newValue: theme,
        summary: '已切换到${_getThemeDisplayName(theme)}',
        action: () => _settingsRepo.setTheme(theme!),
      );
    }

    // 强调色设置
    if (key == 'accent_color') {
      String? color;
      for (final entry in _configValueOptions['accent_color']!.entries) {
        if (voiceText.contains(entry.key)) {
          color = entry.value;
          break;
        }
      }

      if (color == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您想使用什么颜色？',
          options: ['蓝色', '绿色', '紫色', '橙色'],
        );
      }

      return VoiceConfigResult.executeDirectly(
        configType: ConfigType.appearance,
        targetKey: 'accent_color',
        newValue: color,
        summary: '已将强调色切换为$color',
        action: () => _settingsRepo.setAccentColor(color!),
      );
    }

    // 字体大小
    if (key == 'font_size') {
      String? size;
      for (final entry in _configValueOptions['font_size']!.entries) {
        if (voiceText.contains(entry.key)) {
          size = entry.value;
          break;
        }
      }

      if (size == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您想要多大的字体？',
          options: ['小', '正常', '大', '特大'],
        );
      }

      return VoiceConfigResult.executeDirectly(
        configType: ConfigType.appearance,
        targetKey: 'font_size',
        newValue: size,
        summary: '已将字体大小调整为${_getFontSizeDisplayName(size)}',
        action: () => _settingsRepo.setFontSize(size!),
      );
    }

    return VoiceConfigResult.error('不支持的外观设置');
  }

  /// 处理AI配置
  Future<VoiceConfigResult> _processAIConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    final key = configIntent.targetKey;
    final operation = configIntent.operation;

    // 判断是开启还是关闭
    bool? enabled;
    if (voiceText.contains('开启') || voiceText.contains('打开') || voiceText.contains('启用')) {
      enabled = true;
    } else if (voiceText.contains('关闭') || voiceText.contains('禁用') || voiceText.contains('停用')) {
      enabled = false;
    }

    final featureNames = {
      'auto_category': '自动分类',
      'smart_suggestion': '智能建议',
      'spending_insight': '消费洞察',
      'voice_recognition': '语音识别',
      'voice_wakeup': '语音唤醒',
      'voice_broadcast': '语音播报',
    };

    final featureName = featureNames[key] ?? key;

    if (enabled == null) {
      final currentValue = await _settingsRepo.getAISetting(key);
      return VoiceConfigResult.needMoreInfo(
        prompt: '$featureName当前${currentValue ? "已开启" : "已关闭"}，您想${currentValue ? "关闭" : "开启"}吗？',
        options: ['开启', '关闭'],
      );
    }

    return VoiceConfigResult.executeDirectly(
      configType: ConfigType.ai,
      targetKey: key,
      newValue: enabled,
      summary: '已${enabled ? "开启" : "关闭"}$featureName',
      action: () => _settingsRepo.setAISetting(key, enabled!),
    );
  }

  /// 处理安全配置
  Future<VoiceConfigResult> _processSecurityConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    final key = configIntent.targetKey;

    bool? enabled;
    if (voiceText.contains('开启') || voiceText.contains('打开') || voiceText.contains('启用')) {
      enabled = true;
    } else if (voiceText.contains('关闭') || voiceText.contains('禁用') || voiceText.contains('取消')) {
      enabled = false;
    }

    final featureNames = {
      'app_lock': '应用锁',
      'fingerprint': '指纹解锁',
      'face_id': '面容解锁',
      'privacy_mode': '隐私模式',
      'screenshot_protection': '截图保护',
    };

    final featureName = featureNames[key] ?? key;

    if (enabled == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请问您要开��还是关闭$featureName？',
        options: ['开启', '关闭'],
      );
    }

    // 安全设置需要确认
    return VoiceConfigResult.needConfirmation(
      configType: ConfigType.security,
      targetKey: key,
      newValue: enabled,
      summary: '${enabled ? "开启" : "关闭"}$featureName',
    );
  }

  /// 处理国际化配置
  Future<VoiceConfigResult> _processI18nConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    final key = configIntent.targetKey;

    if (key == 'language') {
      String? language;
      for (final entry in _configValueOptions['language']!.entries) {
        if (voiceText.contains(entry.key)) {
          language = entry.value;
          break;
        }
      }

      if (language == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您想切换到什么语言？',
          options: ['中文', '英文', '日文'],
        );
      }

      return VoiceConfigResult.executeDirectly(
        configType: ConfigType.i18n,
        targetKey: 'language',
        newValue: language,
        summary: '已将语言切换为${_getLanguageDisplayName(language)}',
        action: () => _settingsRepo.setLanguage(language!),
      );
    }

    if (key == 'currency') {
      String? currency;
      for (final entry in _configValueOptions['currency']!.entries) {
        if (voiceText.contains(entry.key)) {
          currency = entry.value;
          break;
        }
      }

      if (currency == null) {
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问您想使用什么货币？',
          options: ['人民币', '美元', '欧元', '日元'],
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.i18n,
        targetKey: 'currency',
        newValue: currency,
        summary: '将默认货币切换为${_getCurrencyDisplayName(currency)}',
      );
    }

    return VoiceConfigResult.error('不支持的国际化设置');
  }

  /// 处理商户绑定配置
  Future<VoiceConfigResult> _processMerchantConfig(
    String voiceText,
    ConfigIntent configIntent,
  ) async {
    // 示例："把肯德基绑定到餐饮分类"、"星巴克从现金账户扣款"
    final merchantName = await _extractMerchantName(voiceText);
    final categoryName = await _extractCategoryName(voiceText);
    final accountName = await _extractAccountName(voiceText);

    if (merchantName == null) {
      return VoiceConfigResult.needMoreInfo(
        prompt: '请告诉我商户名称',
        expectingType: ExpectingType.text,
      );
    }

    if (configIntent.targetKey == 'category_binding') {
      if (categoryName == null) {
        final categories = await _categoryRepo.getAll();
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问要将"$merchantName"绑定到哪个分类？',
          options: categories.map((c) => c.name).take(5).toList(),
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.merchant,
        targetKey: merchantName,
        newValue: {'type': 'category', 'value': categoryName},
        summary: '将商户"$merchantName"绑定到"$categoryName"分类',
      );
    }

    if (configIntent.targetKey == 'account_binding') {
      if (accountName == null) {
        final accounts = await _accountRepo.getAll();
        return VoiceConfigResult.needMoreInfo(
          prompt: '请问"$merchantName"的消费从哪个账户扣款？',
          options: accounts.map((a) => a.name).take(5).toList(),
        );
      }

      return VoiceConfigResult.needConfirmation(
        configType: ConfigType.merchant,
        targetKey: merchantName,
        newValue: {'type': 'account', 'value': accountName},
        summary: '将商户"$merchantName"绑定到"$accountName"账户',
      );
    }

    return VoiceConfigResult.error('不支持的商户设置');
  }

  /// 确认并执行配置修改
  Future<VoiceConfigResult> confirmAndApply(VoiceConfigResult pendingConfig) async {
    try {
      switch (pendingConfig.configType) {
        case ConfigType.budget:
          await _budgetRepo.setBudget(
            pendingConfig.targetKey!,
            pendingConfig.newValue as double,
          );
          break;

        case ConfigType.account:
          if (pendingConfig.operation == ConfigOperation.setDefault) {
            await _accountRepo.setDefaultAccount(pendingConfig.targetKey!);
          } else if (pendingConfig.operation == ConfigOperation.add) {
            final data = pendingConfig.newValue as Map<String, dynamic>;
            await _accountRepo.create(name: data['name'], balance: data['balance']);
          }
          break;

        case ConfigType.reminder:
          final data = pendingConfig.newValue as Map<String, dynamic>;
          await _reminderRepo.setReminder(
            pendingConfig.targetKey!,
            enabled: data['enabled'],
            time: data['time'],
          );
          break;

        case ConfigType.security:
          await _settingsRepo.setSecuritySetting(
            pendingConfig.targetKey!,
            pendingConfig.newValue as bool,
          );
          break;

        // ... 其他配置类型
      }

      return VoiceConfigResult.success(
        message: '${pendingConfig.summary}，设置成功！',
      );
    } catch (e) {
      return VoiceConfigResult.error('设置失败：$e');
    }
  }

  ConfigOperation _parseOperation(String text) {
    if (text.contains('添加') || text.contains('新增') || text.contains('创建')) {
      return ConfigOperation.add;
    }
    if (text.contains('删除') || text.contains('移除')) {
      return ConfigOperation.delete;
    }
    if (text.contains('设为默认') || text.contains('默认')) {
      return ConfigOperation.setDefault;
    }
    return ConfigOperation.modify;
  }
}

/// 配置类型枚举（扩展版）
enum ConfigType {
  budget, budgetAlert, budgetCycle,
  account,
  vault, vaultTransfer,
  savingsGoal,
  category, subCategory,
  reminder,
  appearance, homeLayout,
  ai,
  security,
  data,
  i18n,
  merchant,
}

/// 配置操作枚举
enum ConfigOperation {
  add, delete, modify, setDefault, enable, disable, toggle;

  String get displayName => switch (this) {
    add => '添加',
    delete => '删除',
    modify => '修改',
    setDefault => '设为默认',
    enable => '开启',
    disable => '关闭',
    toggle => '切换',
  };
}

/// 配置意图
class ConfigIntent {
  final ConfigType configType;
  final String targetKey;
  final dynamic targetValue;
  final ConfigOperation operation;
  final String rawText;

  ConfigIntent({
    required this.configType,
    required this.targetKey,
    this.targetValue,
    this.operation = ConfigOperation.modify,
    required this.rawText,
  });
}
```

##### 15.12.3.3 语音配置示例库

| 配置类别 | 语音指令示例 | 系统响应 |
|---------|-------------|---------|
| **预算设置** | "把餐饮预算改成2000" | 将餐饮预算从1500元修改为2000元，确认吗？ |
| **预算设置** | "交通预算减少200" | 将交通预算从500元调整为300元，确认吗？ |
| **预算预警** | "预算用到80%时提醒我" | 设置预算预警阈值为80%，确认吗？ |
| **账户管理** | "把微信设为默认账户" | 已将微信设为默认支付账户 |
| **账户管理** | "添加一个招商银行卡" | 已创建账户"招商银行卡" |
| **账户余额** | "支付宝余额改成1500" | 将支付宝余额校正为1500元，确认吗？ |
| **小金库** | "创建一个旅游小金库，每月存500" | 创建"旅游"小金库，每月自动存入500元 |
| **储蓄目标** | "把买车目标改成15万" | 将储蓄目标"买车"金额从10万调整为15万 |
| **分类管理** | "添加一个宠物分类" | 已添加支出分类"宠物" |
| **提醒设置** | "每天晚上8点提醒我记账" | 设置每日记账提醒，时间：20:00 |
| **提醒设置** | "关闭预算提醒" | 已关闭预算预警通知 |
| **主题设置** | "切换到深色模式" | 已切换到深色模式 |
| **主题设置** | "把强调色改成绿色" | 已将强调色切换为绿色 |
| **字体设置** | "字体调大一点" | 已将字体大小调整为"大" |
| **AI设置** | "关闭自动分类" | 已关闭自动分类功能 |
| **AI设置** | "开启语音播报" | 已开启语音播报，记账成功后将语音提示 |
| **安全设置** | "开启应用锁" | 开启应用锁需要设置密码，确认吗？ |
| **安全设置** | "打开隐私模式" | 已��启隐私模式，金额将显示为*** |
| **备份设置** | "设置每天自动备份" | 已设置每日自动备份，时间：凌晨3:00 |
| **语言设置** | "切换到英文" | 已将语言切换为English |
| **货币设置** | "默认货币改成美元" | 将默认货币从CNY切换为USD，确认吗？ |
| **商户绑定** | "把美团绑定到餐饮" | 已将商户"美团"绑定到"餐饮"分类 |
| **商户绑定** | "滴滴出行从微信���款" | 已设置"滴滴出行"消费从微信账户扣款 |

#### 15.12.4 智能语音导航与操作模块

本模块不仅支持页面导航，更重要的是支持**直接执行操作**，实现"说一句话，直接完成"的极致体验。

##### 15.12.4.1 导航与操作能力全景图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      语音导航与操作能力全景图                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────���───────────────────────────────────────────────────┐   │
│  │                        第一层：页面导航                                   │   │
│  │  用户说"打开xxx" → 直接跳转到目标页面                                     │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │   首页    账单列表   预算管理   小金库   统计分析   钱龄   设置   我的    │   │
│  │   收入    支出      转账      账户    分类管理   标签   提醒   备份     │   │
│  │   储蓄目标  习惯打卡  月报     年报    导入      导出   关于   帮助     │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                     ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        第二层：功能入口                                   │   │
│  │  用户说"我要xxx" → 打开功能入口并预填信息                                 │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │   记一笔   语音记账   拍照记账   扫码记账   批量记账   模板记账           │   │
│  │   创建预算  调整预算   创建小金库  添加账户   添加分类   创建目标          │   │
│  │   设置提醒  导出数据   生成报告   数据备份   分享账单                     │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                     ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        第三层：直接操作                                   │   │
│  │  用户说具体指令 → 直接执行操作，无需进入页面                               │   │
│  ├─────────────────────────────────────────────────────────────────���───────┤   │
│  │                                                                         │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │   │
│  │  │    记账操作       │  │    配置操作       │  │    数据操作       │      │   │
│  │  ├──────────────────┤  ├──────────────────┤  ├─────────────────��┤      │   │
│  │  │ • 记一笔支出/收入 │  │ • 切换主题        │  │ • 立即备份        │      │   │
│  │  │ • 删除最后一笔   │  │ • 开关隐私模式    │  │ • 导出本月数据    │      │   │
│  │  │ • 修改刚才那笔   │  │ • 调整预算        │  │ • 清除缓存        │      │   │
│  │  │ • 撤销上次操作   │  │ • 设置提醒        │  │ • 同步数据        │      │   │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘      │   │
│  │                                                                         │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │   │
│  │  │    快捷操作       │  │    社交操作       │  │    系统操作       │      │   │
│  │  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤      │   │
│  │  │ • 打开相机        │  │ • 分享月度报告    │  │ • 检查更新        │      │   │
│  │  │ • 开始扫码        │  │ • 分享账单截图    │  │ • 提交反馈        │      │   │
│  │  │ • 习惯打卡        │  │ • 邀请好友        │  │ • 联系客服        │      │   │
│  │  │ • 刷新数据        │  │                  │  │ • 注销账号        │      │   │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘      │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.4.2 导航与操作服务实现

```dart
/// 语音导航与操作服务
/// 支持三层能力：页面导航 → 功能入口 → 直接操作
class VoiceNavigationService {
  final NavigationService _navigationService;
  final TransactionRepository _transactionRepo;
  final SettingsRepository _settingsRepo;
  final BackupService _backupService;
  final ExportService _exportService;
  final ShareService _shareService;
  final HabitService _habitService;

  // ========== 第一层：页面路由映射 ==========

  static const Map<String, NavigationTarget> _navigationTargets = {
    // 主Tab页面
    '首页': NavigationTarget(route: '/home', displayName: '首页'),
    '主页': NavigationTarget(route: '/home', displayName: '首页'),
    '账单': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '流水': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '明细': NavigationTarget(route: '/transactions', displayName: '账单列表'),
    '交易记录': NavigationTarget(route: '/transactions', displayName: '账单列表'),

    // 预算相关
    '预算': NavigationTarget(route: '/budget', displayName: '预算管理'),
    '预算管理': NavigationTarget(route: '/budget', displayName: '预算管理'),
    '小金库': NavigationTarget(route: '/vaults', displayName: '小金库'),
    '零基预算': NavigationTarget(route: '/zero-budget', displayName: '零基预算'),

    // 分析报告
    '统计': NavigationTarget(route: '/stats', displayName: '统计分析'),
    '统计分析': NavigationTarget(route: '/stats', displayName: '统计分析'),
    '报表': NavigationTarget(route: '/reports', displayName: '报表'),
    '分析报告': NavigationTarget(route: '/analysis', displayName: '分析报告'),
    '月报': NavigationTarget(route: '/reports/monthly', displayName: '月度报告'),
    '年报': NavigationTarget(route: '/reports/yearly', displayName: '年度报告'),
    '钱龄': NavigationTarget(route: '/money-age', displayName: '钱龄分析'),
    '钱龄分析': NavigationTarget(route: '/money-age', displayName: '钱龄分析'),
    '资金健康': NavigationTarget(route: '/money-age', displayName: '钱龄分析'),
    '趋势': NavigationTarget(route: '/trends', displayName: '趋势分析'),
    '消费趋势': NavigationTarget(route: '/trends', displayName: '趋势分析'),

    // 设置相关
    '设置': NavigationTarget(route: '/settings', displayName: '设置'),
    '系统设置': NavigationTarget(route: '/settings', displayName: '设置'),
    '我的': NavigationTarget(route: '/profile', displayName: '我的'),
    '个人中心': NavigationTarget(route: '/profile', displayName: '我的'),
    '账户管理': NavigationTarget(route: '/accounts', displayName: '账户管理'),
    '账户': NavigationTarget(route: '/accounts', displayName: '账户管理'),
    '分类管理': NavigationTarget(route: '/categories', displayName: '分类管理'),
    '分类': NavigationTarget(route: '/categories', displayName: '分类管理'),
    '标签管理': NavigationTarget(route: '/tags', displayName: '标签管理'),
    '标签': NavigationTarget(route: '/tags', displayName: '标签管理'),

    // 数据相关
    '数据备份': NavigationTarget(route: '/backup', displayName: '数据备份'),
    '备份': NavigationTarget(route: '/backup', displayName: '数据备份'),
    '导出': NavigationTarget(route: '/export', displayName: '数据导出'),
    '数据导出': NavigationTarget(route: '/export', displayName: '数据导出'),
    '导入': NavigationTarget(route: '/import', displayName: '数据导入'),
    '数据导入': NavigationTarget(route: '/import', displayName: '数据导入'),

    // 习惯与目标
    '习惯': NavigationTarget(route: '/habits', displayName: '习惯培养'),
    '习惯打卡': NavigationTarget(route: '/habits', displayName: '习惯培养'),
    '打卡': NavigationTarget(route: '/habits', displayName: '习惯培养'),
    '储蓄目标': NavigationTarget(route: '/savings-goals', displayName: '储蓄目标'),
    '攒钱目标': NavigationTarget(route: '/savings-goals', displayName: '储蓄目标'),

    // 提醒相关
    '提醒设置': NavigationTarget(route: '/reminders', displayName: '提醒设置'),
    '账单提醒': NavigationTarget(route: '/bill-reminders', displayName: '账单提醒'),

    // 其他
    '关于': NavigationTarget(route: '/about', displayName: '关于'),
    '帮助': NavigationTarget(route: '/help', displayName: '帮助中心'),
    '反馈': NavigationTarget(route: '/feedback', displayName: '意见反馈'),
  };

  // ========== 第二层：功能入口映射 ==========

  static const Map<String, FunctionEntry> _functionEntries = {
    // 记账入口
    '记一笔': FunctionEntry(route: '/add-transaction', displayName: '记一笔'),
    '记账': FunctionEntry(route: '/add-transaction', displayName: '快速记账'),
    '添加记录': FunctionEntry(route: '/add-transaction', displayName: '添加记录'),
    '语音记账': FunctionEntry(route: '/voice-entry', displayName: '语音记账'),
    '拍照记账': FunctionEntry(route: '/camera-entry', displayName: '拍照记账'),
    '扫码记账': FunctionEntry(route: '/scan-entry', displayName: '扫码记账'),
    '批量记账': FunctionEntry(route: '/batch-entry', displayName: '批量记账'),

    // 预算入口
    '创建预算': FunctionEntry(route: '/budget/create', displayName: '创建预算'),
    '调整预算': FunctionEntry(route: '/budget/edit', displayName: '调整预算'),

    // 小金库入口
    '创建小金库': FunctionEntry(route: '/vaults/create', displayName: '创建小金库'),
    '新建小金库': FunctionEntry(route: '/vaults/create', displayName: '创建小金库'),

    // 账户入口
    '添加账户': FunctionEntry(route: '/accounts/create', displayName: '添加账户'),
    '新建账户': FunctionEntry(route: '/accounts/create', displayName: '添加账户'),

    // 分类入口
    '添加分类': FunctionEntry(route: '/categories/create', displayName: '添加分类'),
    '新建分类': FunctionEntry(route: '/categories/create', displayName: '添加分类'),

    // 目标入口
    '创建储蓄目标': FunctionEntry(route: '/savings-goals/create', displayName: '创建储蓄目标'),
    '新建目标': FunctionEntry(route: '/savings-goals/create', displayName: '创建储蓄目标'),

    // 提醒入口
    '添加提醒': FunctionEntry(route: '/reminders/create', displayName: '添加提醒'),
    '设置提醒': FunctionEntry(route: '/reminders/create', displayName: '设置提醒'),

    // 导出入口
    '导出数据': FunctionEntry(route: '/export', displayName: '导出数据'),
    '生成报告': FunctionEntry(route: '/reports/generate', displayName: '生成报告'),
  };

  // ========== 第三层：直接操作映射 ==========

  static final Map<String, DirectAction> _directActions = {
    // === 记账操作 ===
    '删除最后一笔': DirectAction(
      type: ActionType.deleteLastTransaction,
      displayName: '删除最后一笔记录',
      needConfirm: true,
    ),
    '撤销': DirectAction(
      type: ActionType.undo,
      displayName: '撤销上次操作',
      needConfirm: false,
    ),
    '撤销上次操作': DirectAction(
      type: ActionType.undo,
      displayName: '撤销上次操作',
      needConfirm: false,
    ),

    // === 快捷操作 ===
    '打开相机': DirectAction(
      type: ActionType.openCamera,
      displayName: '打开相机',
      needConfirm: false,
    ),
    '开始扫码': DirectAction(
      type: ActionType.openScanner,
      displayName: '打开扫码',
      needConfirm: false,
    ),
    '扫一扫': DirectAction(
      type: ActionType.openScanner,
      displayName: '打开扫码',
      needConfirm: false,
    ),
    '刷新': DirectAction(
      type: ActionType.refresh,
      displayName: '刷新数据',
      needConfirm: false,
    ),
    '刷新数据': DirectAction(
      type: ActionType.refresh,
      displayName: '刷新数据',
      needConfirm: false,
    ),

    // === 习惯操作 ===
    '打卡': DirectAction(
      type: ActionType.habitCheckIn,
      displayName: '习惯打卡',
      needConfirm: false,
    ),
    '今天打卡': DirectAction(
      type: ActionType.habitCheckIn,
      displayName: '今日打卡',
      needConfirm: false,
    ),
    '记账打卡': DirectAction(
      type: ActionType.habitCheckIn,
      displayName: '记账打卡',
      needConfirm: false,
    ),

    // === 主题操作 ===
    '切换深色模式': DirectAction(
      type: ActionType.toggleDarkMode,
      displayName: '切换深色模式',
      needConfirm: false,
    ),
    '开启深色模式': DirectAction(
      type: ActionType.enableDarkMode,
      displayName: '开启深色模式',
      needConfirm: false,
    ),
    '关闭深色模式': DirectAction(
      type: ActionType.disableDarkMode,
      displayName: '关闭深色模式',
      needConfirm: false,
    ),
    '切换浅色模式': DirectAction(
      type: ActionType.disableDarkMode,
      displayName: '切换浅色模式',
      needConfirm: false,
    ),

    // === 隐私操作 ===
    '开启隐私模式': DirectAction(
      type: ActionType.enablePrivacyMode,
      displayName: '开启隐私模式',
      needConfirm: false,
    ),
    '关闭隐私模式': DirectAction(
      type: ActionType.disablePrivacyMode,
      displayName: '关闭隐私模式',
      needConfirm: false,
    ),
    '隐藏金额': DirectAction(
      type: ActionType.enablePrivacyMode,
      displayName: '隐藏金额',
      needConfirm: false,
    ),
    '显示金额': DirectAction(
      type: ActionType.disablePrivacyMode,
      displayName: '显示金额',
      needConfirm: false,
    ),

    // === 数据操作 ===
    '立即备份': DirectAction(
      type: ActionType.backupNow,
      displayName: '立即备份数据',
      needConfirm: true,
    ),
    '备份数据': DirectAction(
      type: ActionType.backupNow,
      displayName: '立即备份数据',
      needConfirm: true,
    ),
    '同步数据': DirectAction(
      type: ActionType.syncNow,
      displayName: '同步数据',
      needConfirm: false,
    ),
    '立即同步': DirectAction(
      type: ActionType.syncNow,
      displayName: '立即同步',
      needConfirm: false,
    ),
    '清除缓存': DirectAction(
      type: ActionType.clearCache,
      displayName: '清除缓存',
      needConfirm: true,
    ),

    // === 导出操作 ===
    '导出本月数据': DirectAction(
      type: ActionType.exportMonthData,
      displayName: '导出本月数据',
      needConfirm: false,
    ),
    '导出本年数据': DirectAction(
      type: ActionType.exportYearData,
      displayName: '导出本年数据',
      needConfirm: false,
    ),

    // === 分享操作 ===
    '分享月报': DirectAction(
      type: ActionType.shareMonthlyReport,
      displayName: '分享月度报告',
      needConfirm: false,
    ),
    '分享账单': DirectAction(
      type: ActionType.shareTransaction,
      displayName: '分享账单',
      needConfirm: false,
    ),

    // === 系统操作 ===
    '检查更新': DirectAction(
      type: ActionType.checkUpdate,
      displayName: '检查更新',
      needConfirm: false,
    ),
    '提交反馈': DirectAction(
      type: ActionType.openFeedback,
      displayName: '提交反馈',
      needConfirm: false,
    ),
    '联系客服': DirectAction(
      type: ActionType.contactSupport,
      displayName: '联系客服',
      needConfirm: false,
    ),
  };

  /// 处理语音导航/操作请求
  Future<VoiceNavigationResult> processVoiceNavigation({
    required String voiceText,
    required VoiceIntent intent,
  }) async {
    // 优先匹配直接操作（最高效）
    final directAction = await _matchDirectAction(voiceText);
    if (directAction != null) {
      return await _executeDirectAction(directAction, voiceText);
    }

    // 其次匹配功能入口（带预填信息）
    final functionEntry = await _matchFunctionEntry(voiceText);
    if (functionEntry != null) {
      return await _openFunctionWithContext(functionEntry, voiceText);
    }

    // 最后匹配页面导航
    final navigationTarget = await _matchNavigationTarget(voiceText);
    if (navigationTarget != null) {
      return VoiceNavigationResult.navigate(
        target: navigationTarget,
        message: '��在打开${navigationTarget.displayName}',
      );
    }

    // 使用LLM进行模糊匹配
    return await _fuzzyMatch(voiceText);
  }

  /// 匹配直接操作
  DirectAction? _matchDirectAction(String voiceText) {
    for (final entry in _directActions.entries) {
      if (voiceText.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 执行直接操作
  Future<VoiceNavigationResult> _executeDirectAction(
    DirectAction action,
    String voiceText,
  ) async {
    // 需要确认的操作
    if (action.needConfirm) {
      return VoiceNavigationResult.needConfirmation(
        action: action,
        message: '确定要${action.displayName}吗？',
      );
    }

    // 立即执行
    try {
      final result = await _performAction(action.type, voiceText);
      return VoiceNavigationResult.actionComplete(
        action: action,
        message: result.message,
        success: result.success,
      );
    } catch (e) {
      return VoiceNavigationResult.error('操作失败：$e');
    }
  }

  /// 执行具体操作
  Future<ActionResult> _performAction(ActionType type, String voiceText) async {
    switch (type) {
      case ActionType.deleteLastTransaction:
        final lastTx = await _transactionRepo.getLastTransaction();
        if (lastTx == null) {
          return ActionResult(success: false, message: '没有找到可删除的记录');
        }
        await _transactionRepo.delete(lastTx.id);
        return ActionResult(
          success: true,
          message: '已删除：${lastTx.categoryName} ${lastTx.amount}元',
        );

      case ActionType.undo:
        final undone = await _transactionRepo.undoLastAction();
        return ActionResult(
          success: undone,
          message: undone ? '已撤销上次操作' : '没有可撤销的操作',
        );

      case ActionType.openCamera:
        await _navigationService.push('/camera-entry');
        return ActionResult(success: true, message: '已打开相机');

      case ActionType.openScanner:
        await _navigationService.push('/scan-entry');
        return ActionResult(success: true, message: '已打开扫码');

      case ActionType.habitCheckIn:
        final result = await _habitService.checkInToday();
        return ActionResult(
          success: result.success,
          message: result.success ? '打卡成功！${result.message}' : result.message,
        );

      case ActionType.toggleDarkMode:
        final current = await _settingsRepo.getTheme();
        final newTheme = current == 'dark' ? 'light' : 'dark';
        await _settingsRepo.setTheme(newTheme);
        return ActionResult(
          success: true,
          message: '已切换到${newTheme == "dark" ? "深色" : "浅色"}模式',
        );

      case ActionType.enableDarkMode:
        await _settingsRepo.setTheme('dark');
        return ActionResult(success: true, message: '已开启深色模式');

      case ActionType.disableDarkMode:
        await _settingsRepo.setTheme('light');
        return ActionResult(success: true, message: '已切换到浅色模式');

      case ActionType.enablePrivacyMode:
        await _settingsRepo.setPrivacyMode(true);
        return ActionResult(success: true, message: '已开启隐私模式，金额已隐藏');

      case ActionType.disablePrivacyMode:
        await _settingsRepo.setPrivacyMode(false);
        return ActionResult(success: true, message: '已关闭隐私模式');

      case ActionType.backupNow:
        await _backupService.backupNow();
        return ActionResult(success: true, message: '数据备份完成');

      case ActionType.syncNow:
        await _backupService.syncNow();
        return ActionResult(success: true, message: '数据同步完成');

      case ActionType.clearCache:
        await _settingsRepo.clearCache();
        return ActionResult(success: true, message: '缓存已清除');

      case ActionType.exportMonthData:
        final path = await _exportService.exportCurrentMonth();
        return ActionResult(success: true, message: '本月数据已导出到：$path');

      case ActionType.exportYearData:
        final path = await _exportService.exportCurrentYear();
        return ActionResult(success: true, message: '本年数据已导出到：$path');

      case ActionType.shareMonthlyReport:
        await _shareService.shareMonthlyReport();
        return ActionResult(success: true, message: '正在打开分享');

      case ActionType.refresh:
        await _navigationService.refreshCurrentPage();
        return ActionResult(success: true, message: '已刷新');

      case ActionType.checkUpdate:
        await _navigationService.push('/settings/update');
        return ActionResult(success: true, message: '正在检查更新');

      case ActionType.openFeedback:
        await _navigationService.push('/feedback');
        return ActionResult(success: true, message: '已打开反馈页面');

      case ActionType.contactSupport:
        await _navigationService.push('/support');
        return ActionResult(success: true, message: '正在连接客服');

      default:
        return ActionResult(success: false, message: '不支持的操作');
    }
  }

  /// 打开功能入口并携带上下文信息
  Future<VoiceNavigationResult> _openFunctionWithContext(
    FunctionEntry entry,
    String voiceText,
  ) async {
    // 从语音中提取预填信息
    final context = await _extractContextFromVoice(voiceText, entry);

    await _navigationService.push(entry.route, arguments: context);

    return VoiceNavigationResult.functionOpened(
      entry: entry,
      message: '已打开${entry.displayName}${context.isNotEmpty ? "，已预填部分信息" : ""}',
      prefillData: context,
    );
  }

  /// 从语音中提取上下文信息用于预填
  Future<Map<String, dynamic>> _extractContextFromVoice(
    String voiceText,
    FunctionEntry entry,
  ) async {
    final context = <String, dynamic>{};

    // 记账相关入口，提取金额、分类等
    if (entry.route.contains('transaction') || entry.route.contains('entry')) {
      final entities = await EntityExtractor().extractFromText(voiceText);
      if (entities.amount != null) context['amount'] = entities.amount;
      if (entities.description != null) context['description'] = entities.description;
      if (entities.categoryHint != null) context['categoryHint'] = entities.categoryHint;
    }

    // 预算相关入口，提取分类和金额
    if (entry.route.contains('budget')) {
      final entities = await EntityExtractor().extractFromText(voiceText);
      if (entities.amount != null) context['amount'] = entities.amount;
      if (entities.categoryHint != null) context['category'] = entities.categoryHint;
    }

    // 小金库入口，提取名称和金额
    if (entry.route.contains('vault')) {
      final vaultName = _extractVaultName(voiceText);
      if (vaultName != null) context['name'] = vaultName;
      final entities = await EntityExtractor().extractFromText(voiceText);
      if (entities.amount != null) context['monthlyAmount'] = entities.amount;
    }

    return context;
  }

  /// 模糊匹配（使用LLM）
  Future<VoiceNavigationResult> _fuzzyMatch(String voiceText) async {
    // 提供可能的匹配建议
    final suggestions = await _getSuggestions(voiceText);

    if (suggestions.isNotEmpty) {
      return VoiceNavigationResult.suggestions(
        message: '您是想要这些操作吗？',
        suggestions: suggestions,
      );
    }

    return VoiceNavigationResult.notFound(
      message: '没有找到匹配的页面或功能',
      helpText: '您可以说"帮助"了解我能做什么',
    );
  }
}

/// 直接操作类型
enum ActionType {
  // 记账操作
  deleteLastTransaction, undo, modifyLastTransaction,

  // 快捷操作
  openCamera, openScanner, refresh,

  // 习惯操作
  habitCheckIn,

  // 主题操作
  toggleDarkMode, enableDarkMode, disableDarkMode,

  // 隐私操作
  enablePrivacyMode, disablePrivacyMode,

  // 数据操作
  backupNow, syncNow, clearCache,

  // 导出操作
  exportMonthData, exportYearData,

  // 分享操作
  shareMonthlyReport, shareTransaction,

  // 系统操作
  checkUpdate, openFeedback, contactSupport,
}

/// 直接操作定义
class DirectAction {
  final ActionType type;
  final String displayName;
  final bool needConfirm;

  const DirectAction({
    required this.type,
    required this.displayName,
    this.needConfirm = false,
  });
}

/// 功能入口定义
class FunctionEntry {
  final String route;
  final String displayName;

  const FunctionEntry({
    required this.route,
    required this.displayName,
  });
}

/// 操作结果
class ActionResult {
  final bool success;
  final String message;

  ActionResult({required this.success, required this.message});
}
```

##### 15.12.4.3 语音导航与操作示例库

| 能力层级 | 语音指令示例 | 系统响应 |
|---------|-------------|---------|
| **页面导航** | "打开预算" | 正在打开预算管理页面 |
| **页面导航** | "去看看钱龄" | 正在打开钱龄分析页面 |
| **页面导航** | "进入设置" | 正在打开设置页面 |
| **页面导航** | "看看这个月的统计" | 正在打开本月统计分析 |
| **功能入口** | "我要记一笔" | 已打开记账页面 |
| **功能入口** | "创建一个旅游小金库" | 已打开创建小金库页面，已预填名称"旅游" |
| **功能入口** | "添加一个银行卡账户" | 已打开添加账户页面，类型已选"银行卡" |
| **功能入口** | "设置信用卡还款提醒" | 已打开提醒设置，类型已选"信用卡还款" |
| **直接操作** | "切换深色模式" | 已切换到深色模式 |
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
| **智能推断** | "怎么设置预算" | 您可以说"打开预算"进入预算管理页面 |
| **智能推断** | "小金库在哪" | 正在打开小金库页面 |

##### 15.12.4.4 操作确认与安全机制

```dart
/// 操作安全等级定义
class ActionSecurityPolicy {
  /// 高风险操作（需要二次确认 + 可能需要密码）
  static const highRiskActions = {
    ActionType.deleteLastTransaction,
    'clear_all_data',
    'delete_account',
    'logout',
  };

  /// 中风险操作（需要确认）
  static const mediumRiskActions = {
    ActionType.backupNow,
    ActionType.clearCache,
    'export_all_data',
  };

  /// 低风险操作（直接执行）
  static const lowRiskActions = {
    ActionType.toggleDarkMode,
    ActionType.enablePrivacyMode,
    ActionType.refresh,
    ActionType.habitCheckIn,
  };

  /// 检查操作是否需要确认
  static bool needsConfirmation(ActionType action) {
    return highRiskActions.contains(action) ||
           mediumRiskActions.contains(action);
  }

  /// 检查操作是否需要密码验证
  static bool needsAuthentication(ActionType action) {
    return highRiskActions.contains(action);
  }
}
```
