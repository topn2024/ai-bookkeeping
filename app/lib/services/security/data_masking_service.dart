import 'package:flutter/material.dart';

/// 数据脱敏服务
///
/// 核心功能：
/// 1. 敏感数据展示脱敏（银行卡、手机号、身份证等）
/// 2. 金额隐私模式
/// 3. 可配置脱敏规则
/// 4. 上下文感知脱敏
///
/// 对应设计文档：第26章 安全与隐私
/// 对应实施方案：轨道L 安全与隐私模块
class DataMaskingService {
  static final DataMaskingService _instance = DataMaskingService._();
  factory DataMaskingService() => _instance;
  DataMaskingService._();

  /// 隐私模式状态
  bool _privacyModeEnabled = false;

  /// 脱敏配置
  DataMaskingConfig _config = const DataMaskingConfig();

  /// 初始化服务
  void initialize({DataMaskingConfig? config}) {
    if (config != null) {
      _config = config;
    }
  }

  /// 获取隐私模式状态
  bool get isPrivacyModeEnabled => _privacyModeEnabled;

  /// 设置隐私模式
  void setPrivacyMode(bool enabled) {
    _privacyModeEnabled = enabled;
  }

  /// 切换隐私模式
  void togglePrivacyMode() {
    _privacyModeEnabled = !_privacyModeEnabled;
  }

  /// 更新配置
  void updateConfig(DataMaskingConfig config) {
    _config = config;
  }

  // ==================== 银行卡号脱敏 ====================

  /// 银行卡号脱敏
  ///
  /// 输入: 6222021234567890123
  /// 输出: 6222 **** **** 0123
  String maskBankCard(String? cardNumber) {
    if (cardNumber == null || cardNumber.isEmpty) return '';

    final cleaned = cardNumber.replaceAll(RegExp(r'\s|-'), '');
    if (cleaned.length < 8) return _config.fullMask;

    final first = cleaned.substring(0, 4);
    final last = cleaned.substring(cleaned.length - 4);

    switch (_config.bankCardMaskStyle) {
      case MaskStyle.partial:
        return '$first **** **** $last';
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return _formatBankCard(cleaned);
    }
  }

  /// 格式化银行卡号（每4位空格）
  String _formatBankCard(String cardNumber) {
    final buffer = StringBuffer();
    for (int i = 0; i < cardNumber.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cardNumber[i]);
    }
    return buffer.toString();
  }

  // ==================== 手机号脱敏 ====================

  /// 手机号脱敏
  ///
  /// 输入: 13812345678
  /// 输出: 138****5678
  String maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    final cleaned = phone.replaceAll(RegExp(r'\s|-|\+'), '');
    if (cleaned.length < 7) return _config.fullMask;

    switch (_config.phoneMaskStyle) {
      case MaskStyle.partial:
        if (cleaned.length == 11) {
          // 中国大陆手机号
          return '${cleaned.substring(0, 3)}****${cleaned.substring(7)}';
        } else {
          // 其他格式
          final visibleCount = (cleaned.length * 0.3).floor().clamp(2, 4);
          return '${cleaned.substring(0, visibleCount)}${'*' * (cleaned.length - visibleCount * 2)}${cleaned.substring(cleaned.length - visibleCount)}';
        }
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return phone;
    }
  }

  // ==================== 身份证号脱敏 ====================

  /// 身份证号脱敏
  ///
  /// 输入: 110101199003077890
  /// 输出: 110101********7890
  String maskIdCard(String? idCard) {
    if (idCard == null || idCard.isEmpty) return '';

    if (idCard.length < 10) return _config.fullMask;

    switch (_config.idCardMaskStyle) {
      case MaskStyle.partial:
        if (idCard.length == 18) {
          return '${idCard.substring(0, 6)}********${idCard.substring(14)}';
        } else if (idCard.length == 15) {
          return '${idCard.substring(0, 4)}********${idCard.substring(12)}';
        }
        return '${idCard.substring(0, 3)}${'*' * (idCard.length - 6)}${idCard.substring(idCard.length - 3)}';
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return idCard;
    }
  }

  // ==================== 邮箱脱敏 ====================

  /// 邮箱脱敏
  ///
  /// 输入: example@gmail.com
  /// 输出: exa***@gmail.com
  String maskEmail(String? email) {
    if (email == null || email.isEmpty) return '';

    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return _config.fullMask;

    switch (_config.emailMaskStyle) {
      case MaskStyle.partial:
        final localPart = email.substring(0, atIndex);
        final domain = email.substring(atIndex);

        if (localPart.length <= 3) {
          return '$localPart$domain';
        }

        final visibleCount = (localPart.length * 0.3).floor().clamp(1, 3);
        return '${localPart.substring(0, visibleCount)}${'*' * (localPart.length - visibleCount)}$domain';
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return email;
    }
  }

  // ==================== 姓名脱敏 ====================

  /// 姓名脱敏
  ///
  /// 输入: 张三
  /// 输出: 张*
  ///
  /// 输入: 欧阳明月
  /// 输出: 欧阳**
  String maskName(String? name) {
    if (name == null || name.isEmpty) return '';

    switch (_config.nameMaskStyle) {
      case MaskStyle.partial:
        if (name.length == 1) return name;
        if (name.length == 2) return '${name[0]}*';

        // 检测复姓
        final compoundSurnames = ['欧阳', '司马', '诸葛', '东方', '上官', '南宫', '西门'];
        String surname;
        if (name.length >= 2 && compoundSurnames.contains(name.substring(0, 2))) {
          surname = name.substring(0, 2);
        } else {
          surname = name.substring(0, 1);
        }

        return '$surname${'*' * (name.length - surname.length)}';
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return name;
    }
  }

  // ==================== 金额脱敏 ====================

  /// 金额脱敏（隐私模式下使用）
  ///
  /// 输入: 12345.67
  /// 输出: ****.**
  String maskAmount(double? amount, {String? currencySymbol}) {
    if (amount == null) return '';

    final symbol = currencySymbol ?? _config.defaultCurrencySymbol;

    if (_privacyModeEnabled || _config.amountMaskStyle == MaskStyle.full) {
      return '$symbol${_config.amountMask}';
    }

    if (_config.amountMaskStyle == MaskStyle.none) {
      return '$symbol${amount.toStringAsFixed(2)}';
    }

    // partial 模式：显示范围
    return '$symbol${_getAmountRange(amount)}';
  }

  /// 获取金额范围描述
  String _getAmountRange(double amount) {
    if (amount < 0) return '支出';
    if (amount < 100) return '<100';
    if (amount < 500) return '100-500';
    if (amount < 1000) return '500-1K';
    if (amount < 5000) return '1K-5K';
    if (amount < 10000) return '5K-1W';
    if (amount < 50000) return '1W-5W';
    if (amount < 100000) return '5W-10W';
    return '>10W';
  }

  // ==================== 地址脱敏 ====================

  /// 地址脱敏
  ///
  /// 输入: 北京市朝阳区建国路88号
  /// 输出: 北京市朝阳区****
  String maskAddress(String? address) {
    if (address == null || address.isEmpty) return '';

    switch (_config.addressMaskStyle) {
      case MaskStyle.partial:
        // 尝试保留省市区
        final match = RegExp(r'([\u4e00-\u9fa5]+省|[\u4e00-\u9fa5]+市|[\u4e00-\u9fa5]+区|[\u4e00-\u9fa5]+县)').allMatches(address);
        if (match.length >= 2) {
          final prefix = address.substring(0, match.elementAt(1).end);
          return '$prefix****';
        }

        // 默认保留前30%
        final visibleLength = (address.length * 0.3).floor().clamp(4, 10);
        return '${address.substring(0, visibleLength)}****';
      case MaskStyle.full:
        return _config.fullMask;
      case MaskStyle.none:
        return address;
    }
  }

  // ==================== 通用脱敏 ====================

  /// 根据数据类型自动脱敏
  String maskByType(String? value, SensitiveDataType type) {
    if (value == null || value.isEmpty) return '';

    switch (type) {
      case SensitiveDataType.bankCard:
        return maskBankCard(value);
      case SensitiveDataType.phone:
        return maskPhone(value);
      case SensitiveDataType.idCard:
        return maskIdCard(value);
      case SensitiveDataType.email:
        return maskEmail(value);
      case SensitiveDataType.name:
        return maskName(value);
      case SensitiveDataType.address:
        return maskAddress(value);
      case SensitiveDataType.custom:
        return maskCustom(value, visibleStart: 2, visibleEnd: 2);
    }
  }

  /// 自定义脱敏
  ///
  /// [visibleStart] 开头显示字符数
  /// [visibleEnd] 结尾显示字符数
  /// [maskChar] 脱敏字符
  String maskCustom(
    String? value, {
    int visibleStart = 2,
    int visibleEnd = 2,
    String maskChar = '*',
  }) {
    if (value == null || value.isEmpty) return '';

    if (value.length <= visibleStart + visibleEnd) {
      return value;
    }

    final start = value.substring(0, visibleStart);
    final end = value.substring(value.length - visibleEnd);
    final maskLength = value.length - visibleStart - visibleEnd;

    return '$start${maskChar * maskLength}$end';
  }

  // ==================== 自动检测脱敏 ====================

  /// 自动检测敏感数据类型并脱敏
  String autoMask(String? value) {
    if (value == null || value.isEmpty) return '';

    final type = detectSensitiveDataType(value);
    if (type != null) {
      return maskByType(value, type);
    }

    return value;
  }

  /// 检测敏感数据类型
  SensitiveDataType? detectSensitiveDataType(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s|-'), '');

    // 银行卡号：16-19位数字
    if (RegExp(r'^\d{16,19}$').hasMatch(cleaned)) {
      return SensitiveDataType.bankCard;
    }

    // 手机号：11位数字以1开头
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(cleaned)) {
      return SensitiveDataType.phone;
    }

    // 身份证号：15或18位
    if (RegExp(r'^\d{15}$|^\d{17}[\dXx]$').hasMatch(cleaned)) {
      return SensitiveDataType.idCard;
    }

    // 邮箱
    if (RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value)) {
      return SensitiveDataType.email;
    }

    return null;
  }

  // ==================== 批量脱敏 ====================

  /// 批量脱敏 Map 中的敏感字段
  Map<String, dynamic> maskMapFields(
    Map<String, dynamic> data,
    Map<String, SensitiveDataType> fieldTypes,
  ) {
    final result = Map<String, dynamic>.from(data);

    for (final entry in fieldTypes.entries) {
      if (result.containsKey(entry.key) && result[entry.key] is String) {
        result[entry.key] = maskByType(result[entry.key] as String, entry.value);
      }
    }

    return result;
  }

  /// 脱敏日志中的敏感数据
  String maskLogMessage(String message) {
    var result = message;

    // 脱敏可能的手机号
    result = result.replaceAllMapped(
      RegExp(r'1[3-9]\d{9}'),
      (match) => maskPhone(match.group(0)),
    );

    // 脱敏可能的银行卡号
    result = result.replaceAllMapped(
      RegExp(r'\d{16,19}'),
      (match) => maskBankCard(match.group(0)),
    );

    // 脱敏可能的身份证号
    result = result.replaceAllMapped(
      RegExp(r'\d{15}|\d{17}[\dXx]'),
      (match) => maskIdCard(match.group(0)),
    );

    // 脱敏可能的邮箱
    result = result.replaceAllMapped(
      RegExp(r'[\w\.-]+@[\w\.-]+\.\w+'),
      (match) => maskEmail(match.group(0)),
    );

    return result;
  }
}

/// 脱敏配置
class DataMaskingConfig {
  /// 银行卡脱敏样式
  final MaskStyle bankCardMaskStyle;

  /// 手机号脱敏样式
  final MaskStyle phoneMaskStyle;

  /// 身份证脱敏样式
  final MaskStyle idCardMaskStyle;

  /// 邮箱脱敏样式
  final MaskStyle emailMaskStyle;

  /// 姓名脱敏样式
  final MaskStyle nameMaskStyle;

  /// 金额脱敏样式
  final MaskStyle amountMaskStyle;

  /// 地址脱敏样式
  final MaskStyle addressMaskStyle;

  /// 完全脱敏时的占位符
  final String fullMask;

  /// 金额脱敏时的占位符
  final String amountMask;

  /// 默认货币符号
  final String defaultCurrencySymbol;

  const DataMaskingConfig({
    this.bankCardMaskStyle = MaskStyle.partial,
    this.phoneMaskStyle = MaskStyle.partial,
    this.idCardMaskStyle = MaskStyle.partial,
    this.emailMaskStyle = MaskStyle.partial,
    this.nameMaskStyle = MaskStyle.partial,
    this.amountMaskStyle = MaskStyle.none,
    this.addressMaskStyle = MaskStyle.partial,
    this.fullMask = '******',
    this.amountMask = '****.**',
    this.defaultCurrencySymbol = '¥',
  });

  /// 隐私优先配置
  factory DataMaskingConfig.privacyFirst() => const DataMaskingConfig(
    bankCardMaskStyle: MaskStyle.full,
    phoneMaskStyle: MaskStyle.full,
    idCardMaskStyle: MaskStyle.full,
    emailMaskStyle: MaskStyle.full,
    nameMaskStyle: MaskStyle.full,
    amountMaskStyle: MaskStyle.full,
    addressMaskStyle: MaskStyle.full,
  );

  /// 标准配置
  factory DataMaskingConfig.standard() => const DataMaskingConfig();

  /// 宽松配置（最小脱敏）
  factory DataMaskingConfig.relaxed() => const DataMaskingConfig(
    bankCardMaskStyle: MaskStyle.partial,
    phoneMaskStyle: MaskStyle.partial,
    idCardMaskStyle: MaskStyle.partial,
    emailMaskStyle: MaskStyle.none,
    nameMaskStyle: MaskStyle.none,
    amountMaskStyle: MaskStyle.none,
    addressMaskStyle: MaskStyle.none,
  );

  DataMaskingConfig copyWith({
    MaskStyle? bankCardMaskStyle,
    MaskStyle? phoneMaskStyle,
    MaskStyle? idCardMaskStyle,
    MaskStyle? emailMaskStyle,
    MaskStyle? nameMaskStyle,
    MaskStyle? amountMaskStyle,
    MaskStyle? addressMaskStyle,
    String? fullMask,
    String? amountMask,
    String? defaultCurrencySymbol,
  }) {
    return DataMaskingConfig(
      bankCardMaskStyle: bankCardMaskStyle ?? this.bankCardMaskStyle,
      phoneMaskStyle: phoneMaskStyle ?? this.phoneMaskStyle,
      idCardMaskStyle: idCardMaskStyle ?? this.idCardMaskStyle,
      emailMaskStyle: emailMaskStyle ?? this.emailMaskStyle,
      nameMaskStyle: nameMaskStyle ?? this.nameMaskStyle,
      amountMaskStyle: amountMaskStyle ?? this.amountMaskStyle,
      addressMaskStyle: addressMaskStyle ?? this.addressMaskStyle,
      fullMask: fullMask ?? this.fullMask,
      amountMask: amountMask ?? this.amountMask,
      defaultCurrencySymbol: defaultCurrencySymbol ?? this.defaultCurrencySymbol,
    );
  }
}

/// 脱敏样式
enum MaskStyle {
  /// 部分脱敏（保留首尾）
  partial,

  /// 完全脱敏
  full,

  /// 不脱敏
  none,
}

/// 敏感数据类型
enum SensitiveDataType {
  /// 银行卡号
  bankCard,

  /// 手机号
  phone,

  /// 身份证号
  idCard,

  /// 邮箱
  email,

  /// 姓名
  name,

  /// 地址
  address,

  /// 自定义
  custom,
}

/// 隐私模式切换组件
class PrivacyModeToggle extends StatefulWidget {
  /// 初始状态
  final bool initialValue;

  /// 变更回调
  final ValueChanged<bool>? onChanged;

  /// 图标大小
  final double iconSize;

  /// 启用时的颜色
  final Color? activeColor;

  const PrivacyModeToggle({
    super.key,
    this.initialValue = false,
    this.onChanged,
    this.iconSize = 24,
    this.activeColor,
  });

  @override
  State<PrivacyModeToggle> createState() => _PrivacyModeToggleState();
}

class _PrivacyModeToggleState extends State<PrivacyModeToggle> {
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isEnabled ? Icons.visibility_off : Icons.visibility,
        size: widget.iconSize,
        color: _isEnabled
            ? (widget.activeColor ?? Theme.of(context).primaryColor)
            : null,
      ),
      onPressed: () {
        setState(() {
          _isEnabled = !_isEnabled;
        });
        DataMaskingService().setPrivacyMode(_isEnabled);
        widget.onChanged?.call(_isEnabled);
      },
      tooltip: _isEnabled ? '显示金额' : '隐藏金额',
    );
  }
}

/// 可脱敏文本组件
class MaskedText extends StatelessWidget {
  /// 原始文本
  final String text;

  /// 敏感数据类型
  final SensitiveDataType type;

  /// 文本样式
  final TextStyle? style;

  /// 是否强制脱敏（忽略隐私模式）
  final bool forceMask;

  const MaskedText({
    super.key,
    required this.text,
    required this.type,
    this.style,
    this.forceMask = false,
  });

  @override
  Widget build(BuildContext context) {
    final maskedText = DataMaskingService().maskByType(text, type);
    return Text(maskedText, style: style);
  }
}

/// 可脱敏金额组件
class MaskedAmount extends StatelessWidget {
  /// 金额
  final double amount;

  /// 货币符号
  final String? currencySymbol;

  /// 文本样式
  final TextStyle? style;

  /// 是否使用隐私模式
  final bool usePrivacyMode;

  const MaskedAmount({
    super.key,
    required this.amount,
    this.currencySymbol,
    this.style,
    this.usePrivacyMode = true,
  });

  @override
  Widget build(BuildContext context) {
    final service = DataMaskingService();

    String displayText;
    if (usePrivacyMode && service.isPrivacyModeEnabled) {
      displayText = service.maskAmount(amount, currencySymbol: currencySymbol);
    } else {
      final symbol = currencySymbol ?? '¥';
      displayText = '$symbol${amount.toStringAsFixed(2)}';
    }

    return Text(displayText, style: style);
  }
}
