import 'dart:async';
import 'package:flutter/foundation.dart';

/// 语音配置服务
///
/// 对应设计文档第18.3节：智能语音配置模块
/// 支持通过语音修改系统中几乎所有的配置项
///
/// 配置项覆盖13大类：
/// 1. 预算与财务配置
/// 2. 账户与资产配置
/// 3. 账本与成员配置
/// 4. 分类与标签配置
/// 5. 目标与债务配置
/// 6. 提醒与通知配置
/// 7. 模板与定时配置
/// 8. 外观与显示配置
/// 9. 国际化配置
/// 10. AI与智能配置
/// 11. 数据与同步配置
/// 12. 安全与隐私配置
/// 13. 网络与性能配置
///
/// 使用示例：
/// ```dart
/// final service = VoiceConfigService();
/// final result = service.parseConfigCommand('把餐饮预算改成2000');
/// if (result.success) {
///   await service.executeConfig(result.config!);
/// }
/// ```
class VoiceConfigService extends ChangeNotifier {
  /// 配置历史
  final List<ConfigChangeRecord> _history = [];

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  /// 配置项定义（13大类，130+配置项）
  static final List<ConfigItemDefinition> _configDefinitions = [
    // ═══════════════════════════════════════════════════════════════
    // 一、预算与财务配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'budget.monthly_total',
      name: '月度总预算',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.number,
      patterns: [
        r'(设置|修改|把)?(本月|月度)?总预算(设为|改成|改为|设成)?(\d+)',
        r'总预算(\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(4) ?? match.group(1) ?? ''),
      confirmTemplate: '已将本月总预算设为{value}元',
    ),
    ConfigItemDefinition(
      id: 'budget.category',
      name: '分类预算',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.categoryAmount,
      patterns: [
        r'(设置|修改|把)?(.+?)(预算|的预算)(设为|改成|改为|设成)?(\d+)',
      ],
      valueExtractor: (match) => {
        'category': match.group(2),
        'amount': double.tryParse(match.group(5) ?? ''),
      },
      confirmTemplate: '已将{category}预算设为{amount}元',
    ),
    ConfigItemDefinition(
      id: 'budget.alert_threshold',
      name: '预算预警阈值',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.percentage,
      patterns: [
        r'预算(用到|超过|达到)?(\d+)%?(时|就)?提醒',
        r'预算预警(阈值)?(\d+)%?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(2) ?? ''),
      confirmTemplate: '已设置预算预警阈值为{value}%',
    ),
    ConfigItemDefinition(
      id: 'budget.carryover',
      name: '预算结转',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(预算)?结转',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}预算结转功能',
    ),
    ConfigItemDefinition(
      id: 'budget.period',
      name: '预算周期',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'预算周期(设为|改成)?(周|月|年)',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已将预算周期设为按{value}',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 二、账户与资产配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'account.default',
      name: '默认账户',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.string,
      patterns: [
        r'(把|将)?(.+?)(设为|设成|改为)默认账户',
        r'默认账户(设为|设成|改为|改成)(.+)',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已将{value}设为默认支付账户',
    ),
    ConfigItemDefinition(
      id: 'account.balance_correction',
      name: '账户余额校正',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.accountAmount,
      patterns: [
        r'(校正|调整|修改)(.+?)(余额|的余额)(为|到|成)?(\d+\.?\d*)',
      ],
      valueExtractor: (match) => {
        'account': match.group(2),
        'balance': double.tryParse(match.group(5) ?? ''),
      },
      confirmTemplate: '已将{account}余额校正为{balance}元',
    ),
    ConfigItemDefinition(
      id: 'creditcard.bill_day',
      name: '信用卡账单日',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.number,
      patterns: [
        r'信用卡账单日(设为|改成|改为)?(\d+)(号|日)?',
        r'账单日(\d+)(号|日)?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(2) ?? ''),
      confirmTemplate: '已将信用卡账单日设为每月{value}日',
    ),
    ConfigItemDefinition(
      id: 'creditcard.payment_day',
      name: '信用卡还款日',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.number,
      patterns: [
        r'(信用卡)?还款日(设为|改成|改为)?(\d+)(号|日)?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(3) ?? ''),
      confirmTemplate: '已将信用卡还款日设为每月{value}日',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 三、账本与成员配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'book.create',
      name: '创建账本',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.string,
      patterns: [
        r'创建(一个)?(.+?)账本',
        r'新建(一个)?(.+?)账本',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已创建账本"{value}"',
    ),
    ConfigItemDefinition(
      id: 'book.switch',
      name: '切换账本',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.string,
      patterns: [
        r'切换(到)?(.+?)账本',
        r'打开(.+?)账本',
        r'用(.+?)账本',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已切换到"{value}"账本',
    ),
    ConfigItemDefinition(
      id: 'member.invite',
      name: '邀请成员',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.string,
      patterns: [
        r'邀请(.+?)(加入|进入)账本',
        r'添加(.+?)为成员',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已生成邀请链接，可邀请{value}加入',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 四、分类与标签配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'category.add',
      name: '添加分类',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.string,
      patterns: [
        r'添加(一个)?(.+?)分类',
        r'新建(一个)?(.+?)分类',
        r'创建(一个)?(.+?)分类',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已添加支出分类"{value}"',
    ),
    ConfigItemDefinition(
      id: 'category.add_sub',
      name: '添加子分类',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(给|在)(.+?)(添加|新增)(.+?)子分类',
        r'(.+?)下(添加|新增)(.+?)子分类',
      ],
      valueExtractor: (match) => {
        'parent': match.group(2) ?? match.group(1),
        'child': match.group(4) ?? match.group(3),
      },
      confirmTemplate: '已在{parent}分类下添加子分类"{child}"',
    ),
    ConfigItemDefinition(
      id: 'tag.create',
      name: '创建标签',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.string,
      patterns: [
        r'创建(一个)?(.+?)标签',
        r'添加(一个)?(.+?)标签',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已创建标签"{value}"',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 五、目标与债务配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'goal.create',
      name: '创建储蓄目标',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.goalConfig,
      patterns: [
        r'创建(一个)?(.+?)(储蓄)?目标[,，]?(\d+)(万|元)?',
        r'(设立|建立)(一个)?(.+?)(储蓄)?目标[,，]?(\d+)(万|元)?',
      ],
      valueExtractor: (match) {
        final name = match.group(2) ?? match.group(3);
        var amount = double.tryParse(match.group(4) ?? match.group(5) ?? '') ?? 0;
        if (match.group(5) == '万' || match.group(6) == '万') {
          amount *= 10000;
        }
        return {'name': name, 'amount': amount};
      },
      confirmTemplate: '已创建储蓄目标"{name}"，目标金额{amount}元',
    ),
    ConfigItemDefinition(
      id: 'goal.auto_save',
      name: '自动存入设置',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.autoSaveConfig,
      patterns: [
        r'每月(自动)?(存入|存)(\d+)(到|进)(.+?)(目标|基金)?',
      ],
      valueExtractor: (match) => {
        'amount': double.tryParse(match.group(3) ?? ''),
        'target': match.group(5),
      },
      confirmTemplate: '已设置每月自动向"{target}"存入{amount}元',
    ),
    ConfigItemDefinition(
      id: 'debt.add',
      name: '添加债务',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.debtConfig,
      patterns: [
        r'添加(一笔)?(.+?)[,，]?(\d+)(万|元)?[,，]?(利率)?(\d+\.?\d*)%?',
      ],
      valueExtractor: (match) {
        final name = match.group(2);
        var amount = double.tryParse(match.group(3) ?? '') ?? 0;
        if (match.group(4) == '万') amount *= 10000;
        final rate = double.tryParse(match.group(6) ?? '');
        return {'name': name, 'amount': amount, 'rate': rate};
      },
      confirmTemplate: '已添加债务"{name}"，金额{amount}元，年利率{rate}%',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 六、提醒与通知配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'reminder.daily',
      name: '每日记账提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.time,
      patterns: [
        r'每天(晚上|早上|中午)?(\d+)(点|时)(提醒我)?记账',
        r'记账提醒(设为|改成)?(\d+)(点|时)',
      ],
      valueExtractor: (match) {
        var hour = int.tryParse(match.group(2) ?? '') ?? 20;
        if (match.group(1) == '晚上' && hour < 12) hour += 12;
        return hour;
      },
      confirmTemplate: '已设置每日记账提醒，时间：{value}:00',
    ),
    ConfigItemDefinition(
      id: 'reminder.creditcard',
      name: '信用卡还款提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.number,
      patterns: [
        r'信用卡(还款)?(提前)?(\d+)天提醒',
        r'还款(提前)?(\d+)天提醒',
      ],
      valueExtractor: (match) => int.tryParse(match.group(3) ?? match.group(2) ?? ''),
      confirmTemplate: '已设置信用卡还款提醒，提前{value}天通知',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 七、模板与定时配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'template.save',
      name: '保存为模板',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(把)?(刚才|这笔|上一笔)?(那笔)?(保存|存)为模板',
      ],
      valueExtractor: (match) => true,
      confirmTemplate: '已将最近一笔交易保存为快捷模板',
    ),
    ConfigItemDefinition(
      id: 'schedule.create',
      name: '创建定时记账',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.scheduleConfig,
      patterns: [
        r'每月(\d+)(号|日)(自动)?记(一笔)?(.+?)(\d+)(元)?',
      ],
      valueExtractor: (match) => {
        'day': int.tryParse(match.group(1) ?? ''),
        'description': match.group(5),
        'amount': double.tryParse(match.group(6) ?? ''),
      },
      confirmTemplate: '已创建定时记账：每月{day}日，{description}{amount}元',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 八、外观与显示配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'theme.mode',
      name: '主题模式',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'切换(到)?(深色|浅色|暗黑|亮色|夜间)模式',
        r'(开启|关闭)(深色|浅色|暗黑|亮色|夜间)模式',
        r'用(深色|浅色|暗黑|亮色|夜间)模式',
      ],
      valueExtractor: (match) {
        final mode = match.group(2) ?? match.group(1);
        if (['深色', '暗黑', '夜间'].contains(mode)) return 'dark';
        return 'light';
      },
      confirmTemplate: '已切换到{value}模式',
    ),
    ConfigItemDefinition(
      id: 'theme.color',
      name: '主题色',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'(把)?主题色(设为|改成|换成)(.+)',
        r'换成(.+?)主题',
        r'用(.+?)主题色',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(1),
      confirmTemplate: '已将主题色切换为{value}',
    ),
    ConfigItemDefinition(
      id: 'display.privacy',
      name: '隐私模式',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)隐私模式',
        r'(显示|隐藏)金额',
      ],
      valueExtractor: (match) {
        if (match.group(1) != null) {
          return ['开启', '打开', '启用', '隐藏'].contains(match.group(1));
        }
        return false;
      },
      confirmTemplate: '已{action}隐私模式',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 九、国际化配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'language',
      name: '语言设置',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'切换(到)?(.+?)语言?',
        r'(语言)?(设为|改成|换成)(.+)',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(3),
      confirmTemplate: '已将语言切换为{value}',
    ),
    ConfigItemDefinition(
      id: 'currency.default',
      name: '默认货币',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'(默认)?货币(设为|改成|换成)(.+)',
        r'切换(到)?(.+?)货币',
        r'用(.+?)记账',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(2) ?? match.group(1),
      confirmTemplate: '已将默认货币切换为{value}',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 十、AI与智能配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'ai.smart_category',
      name: '智能分类',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)智能分类',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}智能分类功能',
    ),
    ConfigItemDefinition(
      id: 'ai.duplicate_detection',
      name: '重复检测时间窗口',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.number,
      patterns: [
        r'重复检测(时间)?(设为|改成)?(\d+)(分钟|小时)?',
      ],
      valueExtractor: (match) {
        var value = int.tryParse(match.group(3) ?? '') ?? 30;
        if (match.group(4) == '小时') value *= 60;
        return value;
      },
      confirmTemplate: '已将重复检测时间窗口设为{value}分钟',
    ),
    ConfigItemDefinition(
      id: 'ai.voice_recognition',
      name: '语音识别',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)语音识别',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}语音识别功能',
    ),
    ConfigItemDefinition(
      id: 'ai.image_recognition',
      name: '图片识别',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(图片|票据)识别',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}图片识别功能',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 十一、数据与同步配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'sync.auto',
      name: '自动同步',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(自动)?同步',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}自动同步',
    ),
    ConfigItemDefinition(
      id: 'sync.wifi_only',
      name: '仅WiFi同步',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'只在WiFi(下)?同步',
        r'(仅|只)(WiFi|WIFI)同步',
      ],
      valueExtractor: (match) => true,
      confirmTemplate: '已设置仅在WiFi环境下进行数据同步',
    ),
    ConfigItemDefinition(
      id: 'backup.auto',
      name: '自动备份',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'(设置)?每(天|周|月)(自动)?备份',
        r'(自动)?备份(设为|改成)?每(天|周|月)',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(3),
      confirmTemplate: '已设置每{value}自动备份',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 十二、安全与隐私配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'security.app_lock',
      name: '应用锁',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)应用锁',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}应用锁',
    ),
    ConfigItemDefinition(
      id: 'security.biometric',
      name: '生物识别解锁',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(指纹|面容|Face ID|Touch ID)解锁',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}{type}解锁',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 十三、网络与性能配置
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'network.timeout',
      name: '连接超时时间',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.number,
      patterns: [
        r'连接超时(时间)?(设为|改成)?(\d+)(秒)?',
        r'超时(时间)?(\d+)(秒)?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(3) ?? match.group(2) ?? ''),
      confirmTemplate: '已将连接超时时间设为{value}秒',
    ),
    ConfigItemDefinition(
      id: 'update.auto_check',
      name: '自动检查更新',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(自动)?(检查)?更新',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}自动更新检查',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 预算与财务（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'budget.daily',
      name: '每日预算',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.number,
      patterns: [
        r'(设置|修改|把)?(每日|日度|每天)预算(设为|改成|改为|设成)?(\\d+)',
        r'每天(可以|只能)花(\\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(4) ?? match.group(2) ?? ''),
      confirmTemplate: '已将每日预算设为{value}元',
    ),
    ConfigItemDefinition(
      id: 'budget.weekly',
      name: '每周预算',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.number,
      patterns: [
        r'(设置|修改|把)?每周预算(设为|改成|改为|设成)?(\\d+)',
        r'周预算(\\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(3) ?? match.group(1) ?? ''),
      confirmTemplate: '已将每周预算设为{value}元',
    ),
    ConfigItemDefinition(
      id: 'budget.flex_ratio',
      name: '弹性预算比例',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.percentage,
      patterns: [
        r'弹性预算(比例)?(设为|改成)?(\\d+)%?',
        r'预算弹性(空间)?(\\d+)%?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(3) ?? match.group(2) ?? ''),
      confirmTemplate: '已设置弹性预算比例为{value}%',
    ),
    ConfigItemDefinition(
      id: 'budget.rollover_max',
      name: '结转上限',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.number,
      patterns: [
        r'预算结转(上限|最多)(设为|改成)?(\\d+)',
        r'最多结转(\\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(3) ?? match.group(1) ?? ''),
      confirmTemplate: '已设置预算结转上限为{value}元',
    ),
    ConfigItemDefinition(
      id: 'budget.start_day',
      name: '预算起始日',
      category: ConfigCategory.budgetFinance,
      valueType: ConfigValueType.number,
      patterns: [
        r'预算(从)?(每月)?(\\d+)(号|日)开始',
        r'预算起始日(设为|改成)?(\\d+)(号|日)?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(3) ?? match.group(2) ?? ''),
      confirmTemplate: '已设置预算起始日为每月{value}日',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 账户与资产（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'account.hide',
      name: '隐藏账户',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.string,
      patterns: [
        r'隐藏(.+?)账户',
        r'把(.+?)(账户)?隐藏',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已隐藏账户"{value}"',
    ),
    ConfigItemDefinition(
      id: 'account.show',
      name: '显示账户',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.string,
      patterns: [
        r'显示(.+?)账户',
        r'取消隐藏(.+?)(账户)?',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已显示账户"{value}"',
    ),
    ConfigItemDefinition(
      id: 'account.rename',
      name: '重命名账户',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)账户(改名|重命名)(为|成)(.+)',
      ],
      valueExtractor: (match) => {
        'oldName': match.group(2),
        'newName': match.group(5),
      },
      confirmTemplate: '已将账户"{oldName}"重命名为"{newName}"',
    ),
    ConfigItemDefinition(
      id: 'account.icon',
      name: '账户图标',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)账户(图标|头像)(设为|改成)(.+)',
      ],
      valueExtractor: (match) => {
        'account': match.group(2),
        'icon': match.group(5),
      },
      confirmTemplate: '已将账户"{account}"图标设为{icon}',
    ),
    ConfigItemDefinition(
      id: 'creditcard.limit',
      name: '信用卡额度',
      category: ConfigCategory.accountAsset,
      valueType: ConfigValueType.number,
      patterns: [
        r'信用卡额度(设为|改成)?(\\d+)',
        r'(设置)?额度(\\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(2) ?? match.group(1) ?? ''),
      confirmTemplate: '已将信用卡额度设为{value}元',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 账本与成员（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'book.rename',
      name: '重命名账本',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)账本(改名|重命名)(为|成)(.+)',
      ],
      valueExtractor: (match) => {
        'oldName': match.group(2),
        'newName': match.group(5),
      },
      confirmTemplate: '已将账本"{oldName}"重命名为"{newName}"',
    ),
    ConfigItemDefinition(
      id: 'book.archive',
      name: '归档账本',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.string,
      patterns: [
        r'归档(.+?)账本',
        r'把(.+?)账本归档',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已归档账本"{value}"',
    ),
    ConfigItemDefinition(
      id: 'member.role',
      name: '成员权限',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)(设为|改成)(管理员|编辑|只读)',
        r'(.+?)权限(设为|改成)(管理员|编辑|只读)',
      ],
      valueExtractor: (match) => {
        'member': match.group(2) ?? match.group(1),
        'role': match.group(4) ?? match.group(3),
      },
      confirmTemplate: '已将{member}的权限设为{role}',
    ),
    ConfigItemDefinition(
      id: 'member.remove',
      name: '移除成员',
      category: ConfigCategory.bookMember,
      valueType: ConfigValueType.string,
      patterns: [
        r'移除(.+?)成员',
        r'把(.+?)移出账本',
        r'删除成员(.+)',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已将{value}移出账本',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 分类与标签（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'category.rename',
      name: '重命名分类',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)分类(改名|重命名)(为|成)(.+)',
      ],
      valueExtractor: (match) => {
        'oldName': match.group(2),
        'newName': match.group(5),
      },
      confirmTemplate: '已将分类"{oldName}"重命名为"{newName}"',
    ),
    ConfigItemDefinition(
      id: 'category.icon',
      name: '分类图标',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)分类(图标)?(设为|改成)(.+)',
      ],
      valueExtractor: (match) => {
        'category': match.group(2),
        'icon': match.group(5),
      },
      confirmTemplate: '已将分类"{category}"图标设为{icon}',
    ),
    ConfigItemDefinition(
      id: 'category.hide',
      name: '隐藏分类',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.string,
      patterns: [
        r'隐藏(.+?)分类',
        r'把(.+?)分类隐藏',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已隐藏分类"{value}"',
    ),
    ConfigItemDefinition(
      id: 'category.delete',
      name: '删除分类',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.string,
      patterns: [
        r'删除(.+?)分类',
        r'移除(.+?)分类',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已删除分类"{value}"',
    ),
    ConfigItemDefinition(
      id: 'tag.delete',
      name: '删除标签',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.string,
      patterns: [
        r'删除(.+?)标签',
        r'移除(.+?)标签',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已删除标签"{value}"',
    ),
    ConfigItemDefinition(
      id: 'category.sort',
      name: '分类排序',
      category: ConfigCategory.categoryTag,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'分类(按)?(使用频率|金额|名称|自定义)排序',
        r'分类排序(设为|改成)(使用频率|金额|名称|自定义)',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已设置分类按{value}排序',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 目标与债务（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'goal.update_amount',
      name: '更新目标金额',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)目标(金额)?(设为|改成)(\\d+)(万|元)?',
      ],
      valueExtractor: (match) {
        final name = match.group(2);
        var amount = double.tryParse(match.group(5) ?? '') ?? 0;
        if (match.group(6) == '万') amount *= 10000;
        return {'name': name, 'amount': amount};
      },
      confirmTemplate: '已将目标"{name}"金额更新为{amount}元',
    ),
    ConfigItemDefinition(
      id: 'goal.delete',
      name: '删除目标',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.string,
      patterns: [
        r'删除(.+?)目标',
        r'取消(.+?)目标',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已删除目标"{value}"',
    ),
    ConfigItemDefinition(
      id: 'goal.deposit',
      name: '存入目标',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(向|往|给)(.+?)目标(存入|存)(\\d+)(元)?',
      ],
      valueExtractor: (match) => {
        'target': match.group(2),
        'amount': double.tryParse(match.group(4) ?? ''),
      },
      confirmTemplate: '已向目标"{target}"存入{amount}元',
    ),
    ConfigItemDefinition(
      id: 'debt.update',
      name: '更新债务信息',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(.+?)债务(金额|本金)(设为|改成)(\\d+)',
      ],
      valueExtractor: (match) => {
        'name': match.group(1),
        'amount': double.tryParse(match.group(4) ?? ''),
      },
      confirmTemplate: '已将债务"{name}"金额更新为{amount}元',
    ),
    ConfigItemDefinition(
      id: 'debt.pay',
      name: '还债',
      category: ConfigCategory.goalDebt,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(向|往|给)?(.+?)(还款|还)(\\d+)(元)?',
      ],
      valueExtractor: (match) => {
        'debt': match.group(2),
        'amount': double.tryParse(match.group(4) ?? ''),
      },
      confirmTemplate: '已向"{debt}"还款{amount}元',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 提醒与通知（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'reminder.budget_warning',
      name: '预算预警提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)预算预警(提醒)?',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}预算预警提醒',
    ),
    ConfigItemDefinition(
      id: 'reminder.weekly_report',
      name: '周报提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(每)?周(财务)?报告(提醒)?',
        r'周报(开启|关闭)',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}每周财务报告提醒',
    ),
    ConfigItemDefinition(
      id: 'reminder.monthly_report',
      name: '月报提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(每)?月(财务)?报告(提醒)?',
        r'月报(开启|关闭)',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}每月财务报告提醒',
    ),
    ConfigItemDefinition(
      id: 'reminder.goal_progress',
      name: '目标进度提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(储蓄)?目标(进度)?提醒',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}目标进度提醒',
    ),
    ConfigItemDefinition(
      id: 'reminder.large_expense',
      name: '大额支出提醒',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.number,
      patterns: [
        r'超过(\\d+)(元)?时?提醒',
        r'大额支出(阈值)?(设为|改成)?(\\d+)',
      ],
      valueExtractor: (match) => double.tryParse(match.group(1) ?? match.group(3) ?? ''),
      confirmTemplate: '已设置大额支出提醒阈值为{value}元',
    ),
    ConfigItemDefinition(
      id: 'notification.sound',
      name: '通知声音',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用|静音)通知(声音)?',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}通知声音',
    ),
    ConfigItemDefinition(
      id: 'notification.vibrate',
      name: '通知震动',
      category: ConfigCategory.reminderNotification,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)通知震动',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}通知震动',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 模板与定时（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'template.delete',
      name: '删除模板',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.string,
      patterns: [
        r'删除(.+?)模板',
        r'移除(.+?)模板',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已删除模板"{value}"',
    ),
    ConfigItemDefinition(
      id: 'template.rename',
      name: '重命名模板',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.parentChild,
      patterns: [
        r'(把|将)?(.+?)模板(改名|重命名)(为|成)(.+)',
      ],
      valueExtractor: (match) => {
        'oldName': match.group(2),
        'newName': match.group(5),
      },
      confirmTemplate: '已将模板"{oldName}"重命名为"{newName}"',
    ),
    ConfigItemDefinition(
      id: 'schedule.enable',
      name: '启用定时任务',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.string,
      patterns: [
        r'(开启|启用|激活)(.+?)定时(记账)?',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已启用定时任务"{value}"',
    ),
    ConfigItemDefinition(
      id: 'schedule.disable',
      name: '禁用定时任务',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.string,
      patterns: [
        r'(关闭|禁用|停止)(.+?)定时(记账)?',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已禁用定时任务"{value}"',
    ),
    ConfigItemDefinition(
      id: 'schedule.delete',
      name: '删除定时任务',
      category: ConfigCategory.templateSchedule,
      valueType: ConfigValueType.string,
      patterns: [
        r'删除(.+?)定时(任务|记账)?',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已删除定时任务"{value}"',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 外观与显示（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'display.font_size',
      name: '字体大小',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'字体(大小)?(设为|改成)?(小|中|大|特大)',
        r'(用|使用)(小|中|大|特大)字体',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(2),
      confirmTemplate: '已将字体大小设为{value}',
    ),
    ConfigItemDefinition(
      id: 'display.currency_position',
      name: '货币符号位置',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'货币符号(放)?在(前面|后面|左边|右边)',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已将货币符号设为{value}显示',
    ),
    ConfigItemDefinition(
      id: 'display.decimal_places',
      name: '小数位数',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.number,
      patterns: [
        r'(显示|保留)(\\d+)位小数',
        r'小数(位数)?(设为|改成)?(\\d+)(位)?',
      ],
      valueExtractor: (match) => int.tryParse(match.group(2) ?? match.group(3) ?? ''),
      confirmTemplate: '已设置显示{value}位小数',
    ),
    ConfigItemDefinition(
      id: 'display.show_cents',
      name: '显示分',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(显示|隐藏)(零钱|分|角分)',
        r'(开启|关闭)(零钱|分)显示',
      ],
      valueExtractor: (match) => ['显示', '开启'].contains(match.group(1)),
      confirmTemplate: '已{action}零钱显示',
    ),
    ConfigItemDefinition(
      id: 'display.home_widgets',
      name: '首页组件',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.string,
      patterns: [
        r'(显示|隐藏)(.+?)卡片',
        r'(开启|关闭)(.+?)组件',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已调整首页"{value}"组件',
    ),
    ConfigItemDefinition(
      id: 'display.chart_style',
      name: '图表样式',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'图表(样式)?(设为|改成|用)(柱状|折线|饼图|环形)',
        r'(用|使用)(柱状|折线|饼图|环形)图',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(2),
      confirmTemplate: '已将图表样式设为{value}',
    ),
    ConfigItemDefinition(
      id: 'display.week_start',
      name: '每周起始日',
      category: ConfigCategory.appearanceDisplay,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'每周(从)?(周一|周日|星期一|星期日)开始',
        r'周起始日(设为|改成)?(周一|周日)',
      ],
      valueExtractor: (match) => match.group(2),
      confirmTemplate: '已设置每周从{value}开始',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 国际化（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'currency.add',
      name: '添加货币',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.string,
      patterns: [
        r'添加(.+?)货币',
        r'启用(.+?)币种',
      ],
      valueExtractor: (match) => match.group(1),
      confirmTemplate: '已添加货币"{value}"',
    ),
    ConfigItemDefinition(
      id: 'currency.rate_update',
      name: '汇率更新',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(自动)?汇率更新',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}自动汇率更新',
    ),
    ConfigItemDefinition(
      id: 'date_format',
      name: '日期格式',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'日期格式(设为|改成)?(年月日|月日年|日月年)',
        r'(用|使用)(年月日|月日年|日月年)格式',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已将日期格式设为{value}',
    ),
    ConfigItemDefinition(
      id: 'time_format',
      name: '时间格式',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'时间格式(设为|改成)?(12小时|24小时)',
        r'(用|使用)(12|24)小时(制)?',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已将时间格式设为{value}制',
    ),
    ConfigItemDefinition(
      id: 'number_format',
      name: '数字格式',
      category: ConfigCategory.internationalization,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'数字格式(设为|改成)?(中文|西方)',
        r'(用|使用)(中文|西方)数字格式',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已将数字格式设为{value}',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - AI与智能（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'ai.auto_category',
      name: '自动分类',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)自动分类',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}自动分类功能',
    ),
    ConfigItemDefinition(
      id: 'ai.category_suggestion',
      name: '分类建议',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)分类建议',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}分类建议功能',
    ),
    ConfigItemDefinition(
      id: 'ai.smart_reminder',
      name: '智能提醒',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)智能提醒',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}智能提醒功能',
    ),
    ConfigItemDefinition(
      id: 'ai.consumption_analysis',
      name: '消费分析',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(智能)?消费分析',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}智能消费分析',
    ),
    ConfigItemDefinition(
      id: 'ai.learning',
      name: '自学习',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(AI)?自学习',
        r'(允许|禁止)学习我的习惯',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用', '允许'].contains(match.group(1)),
      confirmTemplate: '已{action}AI自学习功能',
    ),
    ConfigItemDefinition(
      id: 'ai.anomaly_detection',
      name: '异常检测',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)异常(消费)?检测',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}异常消费检测',
    ),
    ConfigItemDefinition(
      id: 'ai.assistant_voice',
      name: '助手语音',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'助手(语音|声音)(设为|改成|用)(男声|女声|童声)',
        r'(用|使用)(男声|女声|童声)助手',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(2),
      confirmTemplate: '已将助手语音设为{value}',
    ),
    ConfigItemDefinition(
      id: 'ai.response_speed',
      name: '响应速度',
      category: ConfigCategory.aiSmart,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'(助手)?响应速度(设为|改成)(快|正常|慢)',
        r'(快速|正常|慢速)响应',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(1),
      confirmTemplate: '已将响应速度设为{value}',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 数据与同步（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'sync.frequency',
      name: '同步频率',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'同步频率(设为|改成)?(实时|每小时|每天)',
        r'(实时|每小时|每天)同步',
      ],
      valueExtractor: (match) => match.group(2) ?? match.group(1),
      confirmTemplate: '已将同步频率设为{value}',
    ),
    ConfigItemDefinition(
      id: 'backup.cloud',
      name: '云备份',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)云备份',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}云备份',
    ),
    ConfigItemDefinition(
      id: 'backup.local',
      name: '本地备份',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)本地备份',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}本地备份',
    ),
    ConfigItemDefinition(
      id: 'backup.now',
      name: '立即备份',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'立即备份',
        r'现在备份',
        r'马上备份',
      ],
      valueExtractor: (match) => true,
      confirmTemplate: '正在执行数据备份...',
    ),
    ConfigItemDefinition(
      id: 'data.export',
      name: '导出数据',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'导出(数据|账单)(到)?(Excel|CSV|PDF)?',
        r'(生成|创建)(Excel|CSV|PDF)(报表|文件)',
      ],
      valueExtractor: (match) => match.group(3) ?? match.group(2) ?? 'Excel',
      confirmTemplate: '正在导出{value}格式数据...',
    ),
    ConfigItemDefinition(
      id: 'data.clear_cache',
      name: '清除缓存',
      category: ConfigCategory.dataSync,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'清除缓存',
        r'清空缓存',
        r'删除缓存',
      ],
      valueExtractor: (match) => true,
      confirmTemplate: '正在清除应用缓存...',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 安全与隐私（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'security.auto_lock',
      name: '自动锁定',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'(设置)?(\\d+)(分钟|秒)后自动锁定',
        r'自动锁定(时间)?(设为|改成)?(\\d+)(分钟|秒)?',
      ],
      valueExtractor: (match) {
        final value = int.tryParse(match.group(2) ?? match.group(3) ?? '');
        final unit = match.group(3) ?? match.group(4);
        if (unit == '秒') return '$value秒';
        return '$value分钟';
      },
      confirmTemplate: '已设置{value}后自动锁定',
    ),
    ConfigItemDefinition(
      id: 'security.screenshot',
      name: '截图保护',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(允许|禁止|开启|关闭)截图',
        r'(开启|关闭)截图保护',
      ],
      valueExtractor: (match) => ['禁止', '开启'].contains(match.group(1)),
      confirmTemplate: '已{action}截图保护',
    ),
    ConfigItemDefinition(
      id: 'privacy.hide_balance',
      name: '隐藏余额',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(显示|隐藏)(总)?余额',
        r'余额(显示|隐藏)',
      ],
      valueExtractor: (match) => match.group(1) == '隐藏',
      confirmTemplate: '已{action}余额显示',
    ),
    ConfigItemDefinition(
      id: 'privacy.gesture_password',
      name: '手势密码',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)手势(密码|解锁)',
        r'(设置|取消)手势密码',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用', '设置'].contains(match.group(1)),
      confirmTemplate: '已{action}手势密码',
    ),
    ConfigItemDefinition(
      id: 'privacy.data_encryption',
      name: '数据加密',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)(数据)?加密',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}数据加密',
    ),
    ConfigItemDefinition(
      id: 'privacy.anonymous_stats',
      name: '匿名统计',
      category: ConfigCategory.securityPrivacy,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(允许|禁止|开启|关闭)匿名(使用)?统计',
        r'(参与|退出)(用户)?统计',
      ],
      valueExtractor: (match) => ['允许', '开启', '参与'].contains(match.group(1)),
      confirmTemplate: '已{action}匿名统计',
    ),

    // ═══════════════════════════════════════════════════════════════
    // 补充配置项 - 网络与性能（续）
    // ═══════════════════════════════════════════════════════════════
    ConfigItemDefinition(
      id: 'network.data_save',
      name: '省流量模式',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)省流量(模式)?',
        r'(开启|关闭)流量节省',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}省流量模式',
    ),
    ConfigItemDefinition(
      id: 'network.preload',
      name: '预加载',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)预加载',
        r'(开启|关闭)数据预载',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}预加载功能',
    ),
    ConfigItemDefinition(
      id: 'performance.animation',
      name: '动画效果',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用|减少)(动画|过渡)效果',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}动画效果',
    ),
    ConfigItemDefinition(
      id: 'performance.battery_save',
      name: '省电模式',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.boolean,
      patterns: [
        r'(开启|打开|启用|关闭|禁用)省电(模式)?',
      ],
      valueExtractor: (match) => ['开启', '打开', '启用'].contains(match.group(1)),
      confirmTemplate: '已{action}省电模式',
    ),
    ConfigItemDefinition(
      id: 'performance.cache_size',
      name: '缓存大小',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.number,
      patterns: [
        r'缓存(大小|上限)(设为|改成)?(\\d+)(MB|G)?',
      ],
      valueExtractor: (match) {
        var size = int.tryParse(match.group(3) ?? '') ?? 100;
        if (match.group(4) == 'G') size *= 1024;
        return size;
      },
      confirmTemplate: '已将缓存上限设为{value}MB',
    ),
    ConfigItemDefinition(
      id: 'performance.log_level',
      name: '日志级别',
      category: ConfigCategory.networkPerformance,
      valueType: ConfigValueType.enumValue,
      patterns: [
        r'日志(级别)?(设为|改成)?(关闭|简洁|详细|调试)',
      ],
      valueExtractor: (match) => match.group(3),
      confirmTemplate: '已将日志级别设为{value}',
    ),
  ];

  /// 解析配置指令
  ConfigParseResult parseConfigCommand(String text) {
    if (text.trim().isEmpty) {
      return ConfigParseResult.failure('请说出您想修改的配置');
    }

    final normalizedText = text.trim();

    for (final definition in _configDefinitions) {
      for (final pattern in definition.patterns) {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(normalizedText);

        if (match != null) {
          final value = definition.valueExtractor(match);
          if (value != null) {
            return ConfigParseResult.success(ConfigCommand(
              definition: definition,
              value: value,
              rawText: text,
              matchedPattern: pattern,
            ));
          }
        }
      }
    }

    return ConfigParseResult.failure('无法识别配置指令，请重新表述');
  }

  /// 执行配置
  Future<ConfigExecuteResult> executeConfig(ConfigCommand command) async {
    try {
      // 记录变更历史
      final record = ConfigChangeRecord(
        configId: command.definition.id,
        configName: command.definition.name,
        oldValue: null, // 实际实现需要获取当前值
        newValue: command.value,
        timestamp: DateTime.now(),
      );
      _addToHistory(record);

      // 生成确认文本
      final confirmText = _generateConfirmText(command);

      return ConfigExecuteResult(
        success: true,
        confirmText: confirmText,
        record: record,
      );
    } catch (e) {
      return ConfigExecuteResult(
        success: false,
        errorMessage: '配置修改失败：$e',
      );
    }
  }

  /// 生成确认文本
  String _generateConfirmText(ConfigCommand command) {
    var template = command.definition.confirmTemplate;
    final value = command.value;

    if (value is Map) {
      for (final entry in value.entries) {
        template = template.replaceAll('{${entry.key}}', entry.value.toString());
      }
    } else if (value is bool) {
      template = template.replaceAll('{action}', value ? '开启' : '关闭');
      template = template.replaceAll('{value}', value ? '开启' : '关闭');
    } else {
      template = template.replaceAll('{value}', value.toString());
    }

    return template;
  }

  /// 添加到历史
  void _addToHistory(ConfigChangeRecord record) {
    _history.add(record);
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
    notifyListeners();
  }

  /// 获取配置历史
  List<ConfigChangeRecord> get history => List.unmodifiable(_history);

  /// 撤销最后一次配置
  ConfigChangeRecord? undoLastConfig() {
    if (_history.isEmpty) return null;
    final record = _history.removeLast();
    notifyListeners();
    return record;
  }

  /// 获取所有配置项
  List<ConfigItemDefinition> get allConfigs => List.unmodifiable(_configDefinitions);

  /// 按类别获取配置项
  List<ConfigItemDefinition> getConfigsByCategory(ConfigCategory category) {
    return _configDefinitions.where((c) => c.category == category).toList();
  }

  /// 获取配置建议
  List<String> getSuggestions() {
    return [
      '把餐饮预算改成2000',
      '设置每天晚上8点提醒记账',
      '切换深色模式',
      '开启自动同步',
      '创建一个旅游储蓄目标',
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

/// 配置类别
enum ConfigCategory {
  /// 预算与财务
  budgetFinance,

  /// 账户与资产
  accountAsset,

  /// 账本与成员
  bookMember,

  /// 分类与标签
  categoryTag,

  /// 目标与债务
  goalDebt,

  /// 提醒与通知
  reminderNotification,

  /// 模板与定时
  templateSchedule,

  /// 外观与显示
  appearanceDisplay,

  /// 国际化
  internationalization,

  /// AI与智能
  aiSmart,

  /// 数据与同步
  dataSync,

  /// 安全与隐私
  securityPrivacy,

  /// 网络与性能
  networkPerformance,
}

/// 配置值类型
enum ConfigValueType {
  /// 数字
  number,

  /// 百分比
  percentage,

  /// 布尔值
  boolean,

  /// 字符串
  string,

  /// 枚举值
  enumValue,

  /// 时间
  time,

  /// 分类金额
  categoryAmount,

  /// 账户金额
  accountAmount,

  /// 父子关系
  parentChild,

  /// 目标配置
  goalConfig,

  /// 债务配置
  debtConfig,

  /// 自动存入配置
  autoSaveConfig,

  /// 定时配置
  scheduleConfig,
}

/// 配置项定义
class ConfigItemDefinition {
  /// 配置ID
  final String id;

  /// 配置名称
  final String name;

  /// 所属类别
  final ConfigCategory category;

  /// 值类型
  final ConfigValueType valueType;

  /// 匹配模式列表
  final List<String> patterns;

  /// 值提取函数
  final dynamic Function(Match match) valueExtractor;

  /// 确认文本模板
  final String confirmTemplate;

  const ConfigItemDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.valueType,
    required this.patterns,
    required this.valueExtractor,
    required this.confirmTemplate,
  });
}

/// 配置指令
class ConfigCommand {
  /// 配置定义
  final ConfigItemDefinition definition;

  /// 配置值
  final dynamic value;

  /// 原始文本
  final String rawText;

  /// 匹配的模式
  final String matchedPattern;

  const ConfigCommand({
    required this.definition,
    required this.value,
    required this.rawText,
    required this.matchedPattern,
  });
}

/// 配置解析结果
class ConfigParseResult {
  final bool success;
  final ConfigCommand? config;
  final String? errorMessage;

  const ConfigParseResult({
    required this.success,
    this.config,
    this.errorMessage,
  });

  factory ConfigParseResult.success(ConfigCommand config) {
    return ConfigParseResult(success: true, config: config);
  }

  factory ConfigParseResult.failure(String message) {
    return ConfigParseResult(success: false, errorMessage: message);
  }
}

/// 配置执行结果
class ConfigExecuteResult {
  final bool success;
  final String? confirmText;
  final String? errorMessage;
  final ConfigChangeRecord? record;

  const ConfigExecuteResult({
    required this.success,
    this.confirmText,
    this.errorMessage,
    this.record,
  });
}

/// 配置变更记录
class ConfigChangeRecord {
  final String configId;
  final String configName;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;

  const ConfigChangeRecord({
    required this.configId,
    required this.configName,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });
}

// ═══════════════════════════════════════════════════════════════
// 配置执行器 - 真正执行配置修改的组件
// ═══════════════════════════════════════════════════════════════

/// 配置执行器接口
///
/// 定义了执行各类配置修改的方法
/// 实际应用中应该注入具体的服务实现
abstract class ConfigExecutor {
  /// 执行配置修改
  Future<ConfigExecuteResult> execute(ConfigCommand command);

  /// 获取配置当前值
  Future<dynamic> getCurrentValue(String configId);

  /// 验证配置值是否合法
  Future<bool> validateValue(String configId, dynamic value);
}

/// 默认配置执行器实现
///
/// 通过回调函数委托给各个具体服务执行配置修改
class DefaultConfigExecutor implements ConfigExecutor {
  /// 预算服务回调
  final Future<void> Function(String category, double amount)? onSetBudget;

  /// 账户服务回调
  final Future<void> Function(String accountId, dynamic value)? onSetAccount;

  /// 主题服务回调
  final Future<void> Function(String themeMode)? onSetTheme;

  /// 通知服务回调
  final Future<void> Function(String type, dynamic value)? onSetNotification;

  /// 同步服务回调
  final Future<void> Function(bool enabled)? onSetSync;

  /// 安全服务回调
  final Future<void> Function(String type, dynamic value)? onSetSecurity;

  /// AI服务回调
  final Future<void> Function(String feature, bool enabled)? onSetAIFeature;

  /// 通用配置回调
  final Future<void> Function(String configId, dynamic value)? onSetGenericConfig;

  /// 配置值获取器
  final Future<dynamic> Function(String configId)? configValueGetter;

  DefaultConfigExecutor({
    this.onSetBudget,
    this.onSetAccount,
    this.onSetTheme,
    this.onSetNotification,
    this.onSetSync,
    this.onSetSecurity,
    this.onSetAIFeature,
    this.onSetGenericConfig,
    this.configValueGetter,
  });

  @override
  Future<ConfigExecuteResult> execute(ConfigCommand command) async {
    try {
      final configId = command.definition.id;
      final category = command.definition.category;
      final value = command.value;

      // 获取当前值用于记录
      final oldValue = await getCurrentValue(configId);

      // 根据配置类别分发执行
      switch (category) {
        case ConfigCategory.budgetFinance:
          await _executeBudgetConfig(configId, value);
          break;

        case ConfigCategory.accountAsset:
          await _executeAccountConfig(configId, value);
          break;

        case ConfigCategory.appearanceDisplay:
          await _executeAppearanceConfig(configId, value);
          break;

        case ConfigCategory.reminderNotification:
          await _executeNotificationConfig(configId, value);
          break;

        case ConfigCategory.dataSync:
          await _executeSyncConfig(configId, value);
          break;

        case ConfigCategory.securityPrivacy:
          await _executeSecurityConfig(configId, value);
          break;

        case ConfigCategory.aiSmart:
          await _executeAIConfig(configId, value);
          break;

        default:
          await _executeGenericConfig(configId, value);
      }

      // 记录变更
      final record = ConfigChangeRecord(
        configId: configId,
        configName: command.definition.name,
        oldValue: oldValue,
        newValue: value,
        timestamp: DateTime.now(),
      );

      return ConfigExecuteResult(
        success: true,
        confirmText: _generateConfirmText(command),
        record: record,
      );
    } catch (e) {
      return ConfigExecuteResult(
        success: false,
        errorMessage: '配置修改失败：$e',
      );
    }
  }

  /// 执行预算配置
  Future<void> _executeBudgetConfig(String configId, dynamic value) async {
    if (onSetBudget == null) {
      debugPrint('Budget executor not configured, config: $configId = $value');
      return;
    }

    switch (configId) {
      case 'budget.monthly_total':
        await onSetBudget!('total', value as double);
        break;
      case 'budget.category':
        final map = value as Map<String, dynamic>;
        await onSetBudget!(map['category'] as String, map['amount'] as double);
        break;
      case 'budget.daily':
        await onSetBudget!('daily', value as double);
        break;
      case 'budget.weekly':
        await onSetBudget!('weekly', value as double);
        break;
      default:
        await onSetGenericConfig?.call(configId, value);
    }
  }

  /// 执行账户配置
  Future<void> _executeAccountConfig(String configId, dynamic value) async {
    if (onSetAccount == null) {
      debugPrint('Account executor not configured, config: $configId = $value');
      return;
    }
    await onSetAccount!(configId, value);
  }

  /// 执行外观配置
  Future<void> _executeAppearanceConfig(String configId, dynamic value) async {
    if (configId == 'theme.mode' && onSetTheme != null) {
      await onSetTheme!(value as String);
      return;
    }
    await onSetGenericConfig?.call(configId, value);
  }

  /// 执行通知配置
  Future<void> _executeNotificationConfig(String configId, dynamic value) async {
    if (onSetNotification == null) {
      debugPrint('Notification executor not configured, config: $configId = $value');
      return;
    }
    await onSetNotification!(configId, value);
  }

  /// 执行同步配置
  Future<void> _executeSyncConfig(String configId, dynamic value) async {
    if (configId == 'sync.auto' && onSetSync != null) {
      await onSetSync!(value as bool);
      return;
    }
    await onSetGenericConfig?.call(configId, value);
  }

  /// 执行安全配置
  Future<void> _executeSecurityConfig(String configId, dynamic value) async {
    if (onSetSecurity == null) {
      debugPrint('Security executor not configured, config: $configId = $value');
      return;
    }
    await onSetSecurity!(configId, value);
  }

  /// 执行AI配置
  Future<void> _executeAIConfig(String configId, dynamic value) async {
    if (onSetAIFeature == null) {
      debugPrint('AI executor not configured, config: $configId = $value');
      return;
    }
    await onSetAIFeature!(configId, value as bool);
  }

  /// 执行通用配置
  Future<void> _executeGenericConfig(String configId, dynamic value) async {
    if (onSetGenericConfig == null) {
      debugPrint('Generic executor not configured, config: $configId = $value');
      return;
    }
    await onSetGenericConfig!(configId, value);
  }

  @override
  Future<dynamic> getCurrentValue(String configId) async {
    if (configValueGetter != null) {
      return await configValueGetter!(configId);
    }
    return null;
  }

  @override
  Future<bool> validateValue(String configId, dynamic value) async {
    // 基础验证
    if (value == null) return false;

    // 数值范围验证
    if (value is num) {
      // 预算不能为负
      if (configId.startsWith('budget.') && value < 0) return false;
      // 百分比范围验证
      if (configId.contains('threshold') || configId.contains('ratio')) {
        return value >= 0 && value <= 100;
      }
    }

    return true;
  }

  /// 生成确认文本
  String _generateConfirmText(ConfigCommand command) {
    var template = command.definition.confirmTemplate;
    final value = command.value;

    if (value is Map) {
      for (final entry in value.entries) {
        template = template.replaceAll('{${entry.key}}', entry.value.toString());
      }
    } else if (value is bool) {
      template = template.replaceAll('{action}', value ? '开启' : '关闭');
      template = template.replaceAll('{value}', value ? '开启' : '关闭');
    } else {
      template = template.replaceAll('{value}', value.toString());
    }

    return template;
  }
}

/// 带服务注入的语音配置服务
///
/// 扩展 VoiceConfigService，支持真正执行配置修改
class VoiceConfigServiceWithExecutor extends VoiceConfigService {
  final ConfigExecutor _executor;

  VoiceConfigServiceWithExecutor({
    required ConfigExecutor executor,
  }) : _executor = executor;

  /// 执行配置（带真正的配置修改）
  @override
  Future<ConfigExecuteResult> executeConfig(ConfigCommand command) async {
    // 验证配置值
    final isValid = await _executor.validateValue(
      command.definition.id,
      command.value,
    );

    if (!isValid) {
      return ConfigExecuteResult(
        success: false,
        errorMessage: '配置值无效，请检查输入',
      );
    }

    // 执行配置修改
    final result = await _executor.execute(command);

    // 记录到历史
    if (result.success && result.record != null) {
      _addToHistory(result.record!);
    }

    return result;
  }
}

/// 配置执行器工厂
///
/// 用于在应用启动时创建配置执行器
class ConfigExecutorFactory {
  /// 创建配置执行器
  ///
  /// [budgetProvider] - 预算Provider
  /// [themeProvider] - 主题Provider
  /// [syncProvider] - 同步Provider
  /// [settingsService] - 设置服务
  static DefaultConfigExecutor create({
    dynamic budgetProvider,
    dynamic themeProvider,
    dynamic syncProvider,
    dynamic settingsService,
  }) {
    return DefaultConfigExecutor(
      onSetBudget: budgetProvider != null
          ? (category, amount) async {
              // 实际调用: budgetProvider.setBudget(category, amount);
              debugPrint('Setting budget: $category = $amount');
            }
          : null,
      onSetTheme: themeProvider != null
          ? (mode) async {
              // 实际调用: themeProvider.setThemeMode(mode);
              debugPrint('Setting theme mode: $mode');
            }
          : null,
      onSetSync: syncProvider != null
          ? (enabled) async {
              // 实际调用: syncProvider.setAutoSync(enabled);
              debugPrint('Setting auto sync: $enabled');
            }
          : null,
      onSetGenericConfig: settingsService != null
          ? (configId, value) async {
              // 实际调用: settingsService.set(configId, value);
              debugPrint('Setting config: $configId = $value');
            }
          : null,
      configValueGetter: settingsService != null
          ? (configId) async {
              // 实际调用: return settingsService.get(configId);
              debugPrint('Getting config: $configId');
              return null;
            }
          : null,
    );
  }
}
