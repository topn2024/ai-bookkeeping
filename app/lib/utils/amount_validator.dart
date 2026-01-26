/// 金额验证工具类
///
/// 统一管理所有金额输入的范围限制，防止异常值影响系统计算
class AmountValidator {
  /// 最大金额：10亿元
  /// 考虑到企业和高净值个人的记账需求，设定为10亿
  static const double maxAmount = 1000000000.0;

  /// 最小金额：0.01元
  static const double minAmount = 0.01;

  /// 验证金额是否在合理范围内
  ///
  /// [amount] 要验证的金额
  /// [allowZero] 是否允许0（某些场景如预算可以为0）
  ///
  /// 返回：
  /// - null: 验证通过
  /// - String: 错误消息
  static String? validate(double amount, {bool allowZero = false}) {
    if (amount.isNaN || amount.isInfinite) {
      return '请输入有效的数值';
    }

    if (amount < 0) {
      return '金额不能为负数';
    }

    if (!allowZero && amount == 0) {
      return '金额必须大于0';
    }

    if (!allowZero && amount < minAmount) {
      return '金额不能小于0.01元';
    }

    if (amount > maxAmount) {
      return '金额不能超过10亿元';
    }

    return null;
  }

  /// 验证金额文本输入
  ///
  /// [text] 文本输入
  /// [allowZero] 是否允许0
  /// [allowEmpty] 是否允许空值
  ///
  /// 返回：
  /// - null: 验证通过
  /// - String: 错误消息
  static String? validateText(
    String text, {
    bool allowZero = false,
    bool allowEmpty = false,
  }) {
    final trimmed = text.replaceAll(',', '').trim();

    if (trimmed.isEmpty) {
      return allowEmpty ? null : '请输入金额';
    }

    final amount = double.tryParse(trimmed);
    if (amount == null) {
      return '请输入有效的数值';
    }

    return validate(amount, allowZero: allowZero);
  }

  /// 限制金额在合理范围内
  ///
  /// 用于计算中对异常值的处理
  static double clamp(double amount) {
    if (amount.isNaN || amount.isInfinite) {
      return 0;
    }
    return amount.clamp(0, maxAmount);
  }
}
