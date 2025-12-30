import 'package:flutter/material.dart';

/// 债务类型
enum DebtType {
  creditCard,     // 信用卡
  mortgage,       // 房贷
  carLoan,        // 车贷
  personalLoan,   // 个人贷款
  studentLoan,    // 学生贷款
  medicalDebt,    // 医疗债务
  other,          // 其他
}

/// 还款策略
enum RepaymentStrategy {
  snowball,   // 雪球法 - 从最小余额开始
  avalanche,  // 雪崩法 - 从最高利率开始
  custom,     // 自定义顺序
}

/// 债务模型
class Debt {
  final String id;
  final String name;
  final String? description;
  final DebtType type;
  final double originalAmount;      // 原始借款金额
  final double currentBalance;      // 当前余额
  final double interestRate;        // 年利率 (如 0.18 表示 18%)
  final double minimumPayment;      // 最低还款额
  final DateTime startDate;         // 借款开始日期
  final DateTime? targetPayoffDate; // 目标还清日期
  final int paymentDay;             // 每月还款日 (1-31)
  final String? linkedAccountId;    // 关联还款账户
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  Debt({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.originalAmount,
    required this.currentBalance,
    required this.interestRate,
    required this.minimumPayment,
    required this.startDate,
    this.targetPayoffDate,
    this.paymentDay = 1,
    this.linkedAccountId,
    required this.icon,
    required this.color,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  /// 已还金额
  double get paidAmount => originalAmount - currentBalance;

  /// 还款进度 (0-1)
  double get progress => originalAmount > 0
      ? (paidAmount / originalAmount).clamp(0.0, 1.0)
      : 0;

  /// 进度百分比显示
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// 月利率
  double get monthlyInterestRate => interestRate / 12;

  /// 每月利息金额
  double get monthlyInterest => currentBalance * monthlyInterestRate;

  /// 是否已还清
  bool get isPaidOff => currentBalance <= 0;

  /// 预计还清月数（按最低还款计算）
  int? get estimatedPayoffMonths {
    if (currentBalance <= 0 || minimumPayment <= 0) return 0;
    if (minimumPayment <= monthlyInterest) return null; // 永远还不清

    double balance = currentBalance;
    int months = 0;
    while (balance > 0 && months < 1200) { // 最多100年
      double interest = balance * monthlyInterestRate;
      balance = balance + interest - minimumPayment;
      months++;
    }
    return months;
  }

  /// 预计还清日期
  DateTime? get estimatedPayoffDate {
    final months = estimatedPayoffMonths;
    if (months == null || months == 0) return null;
    return DateTime.now().add(Duration(days: months * 30));
  }

  /// 总利息支出预估（按最低还款计算）
  double? get totalInterestEstimate {
    if (currentBalance <= 0 || minimumPayment <= 0) return 0;
    if (minimumPayment <= monthlyInterest) return null;

    double balance = currentBalance;
    double totalInterest = 0;
    int months = 0;
    while (balance > 0 && months < 1200) {
      double interest = balance * monthlyInterestRate;
      totalInterest += interest;
      balance = balance + interest - minimumPayment;
      months++;
    }
    return totalInterest;
  }

  /// 距离下次还款日的天数
  int get daysUntilPayment {
    final now = DateTime.now();
    DateTime nextPayment;
    if (now.day <= paymentDay) {
      nextPayment = DateTime(now.year, now.month, paymentDay);
    } else {
      nextPayment = DateTime(now.year, now.month + 1, paymentDay);
    }
    return nextPayment.difference(now).inDays;
  }

  /// 下次还款日期
  DateTime get nextPaymentDate {
    final now = DateTime.now();
    if (now.day <= paymentDay) {
      return DateTime(now.year, now.month, paymentDay);
    } else {
      return DateTime(now.year, now.month + 1, paymentDay);
    }
  }

  /// 债务类型显示名称
  String get typeDisplayName {
    switch (type) {
      case DebtType.creditCard:
        return '信用卡';
      case DebtType.mortgage:
        return '房贷';
      case DebtType.carLoan:
        return '车贷';
      case DebtType.personalLoan:
        return '个人贷款';
      case DebtType.studentLoan:
        return '学生贷款';
      case DebtType.medicalDebt:
        return '医疗债务';
      case DebtType.other:
        return '其他债务';
    }
  }

  /// 利率格式化显示
  String get interestRateDisplay => '${(interestRate * 100).toStringAsFixed(2)}%';

  Debt copyWith({
    String? id,
    String? name,
    String? description,
    DebtType? type,
    double? originalAmount,
    double? currentBalance,
    double? interestRate,
    double? minimumPayment,
    DateTime? startDate,
    DateTime? targetPayoffDate,
    int? paymentDay,
    String? linkedAccountId,
    IconData? icon,
    Color? color,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      originalAmount: originalAmount ?? this.originalAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      interestRate: interestRate ?? this.interestRate,
      minimumPayment: minimumPayment ?? this.minimumPayment,
      startDate: startDate ?? this.startDate,
      targetPayoffDate: targetPayoffDate ?? this.targetPayoffDate,
      paymentDay: paymentDay ?? this.paymentDay,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'originalAmount': originalAmount,
      'currentBalance': currentBalance,
      'interestRate': interestRate,
      'minimumPayment': minimumPayment,
      'startDate': startDate.millisecondsSinceEpoch,
      'targetPayoffDate': targetPayoffDate?.millisecondsSinceEpoch,
      'paymentDay': paymentDay,
      'linkedAccountId': linkedAccountId,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: DebtType.values[map['type']],
      originalAmount: (map['originalAmount'] as num).toDouble(),
      currentBalance: (map['currentBalance'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      minimumPayment: (map['minimumPayment'] as num).toDouble(),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      targetPayoffDate: map['targetPayoffDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetPayoffDate'])
          : null,
      paymentDay: map['paymentDay'] ?? 1,
      linkedAccountId: map['linkedAccountId'],
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      isCompleted: map['isCompleted'] == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

/// 还款记录
class DebtPayment {
  final String id;
  final String debtId;
  final double amount;           // 还款金额
  final double principalPaid;    // 本金部分
  final double interestPaid;     // 利息部分
  final double balanceAfter;     // 还款后余额
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.principalPaid,
    required this.interestPaid,
    required this.balanceAfter,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'amount': amount,
      'principalPaid': principalPaid,
      'interestPaid': interestPaid,
      'balanceAfter': balanceAfter,
      'note': note,
      'date': date.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'],
      debtId: map['debtId'],
      amount: (map['amount'] as num).toDouble(),
      principalPaid: (map['principalPaid'] as num).toDouble(),
      interestPaid: (map['interestPaid'] as num).toDouble(),
      balanceAfter: (map['balanceAfter'] as num).toDouble(),
      note: map['note'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

/// 还款计划项
class RepaymentPlanItem {
  final int month;              // 第几个月
  final DateTime date;          // 还款日期
  final double payment;         // 还款金额
  final double principal;       // 本金部分
  final double interest;        // 利息部分
  final double balanceAfter;    // 还款后余额
  final double cumulativeInterest;  // 累计利息

  RepaymentPlanItem({
    required this.month,
    required this.date,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balanceAfter,
    required this.cumulativeInterest,
  });
}

/// 还款模拟结果
class RepaymentSimulation {
  final RepaymentStrategy strategy;
  final List<DebtRepaymentPlan> plans;  // 每个债务的还款计划
  final int totalMonths;                // 总还款月数
  final double totalInterest;           // 总利息
  final double totalPaid;               // 总还款额
  final DateTime payoffDate;            // 还清日期

  RepaymentSimulation({
    required this.strategy,
    required this.plans,
    required this.totalMonths,
    required this.totalInterest,
    required this.totalPaid,
    required this.payoffDate,
  });
}

/// 单个债务的还款计划
class DebtRepaymentPlan {
  final Debt debt;
  final List<RepaymentPlanItem> items;
  final double totalInterest;
  final int payoffMonth;        // 第几个月还清
  final DateTime payoffDate;    // 还清日期

  DebtRepaymentPlan({
    required this.debt,
    required this.items,
    required this.totalInterest,
    required this.payoffMonth,
    required this.payoffDate,
  });
}

/// 债务模板
class DebtTemplates {
  static List<Map<String, dynamic>> get templates => [
    {
      'name': '信用卡',
      'type': DebtType.creditCard,
      'icon': Icons.credit_card,
      'color': Colors.red,
      'interestRate': 0.18,  // 18%年利率
    },
    {
      'name': '房贷',
      'type': DebtType.mortgage,
      'icon': Icons.home,
      'color': Colors.blue,
      'interestRate': 0.045, // 4.5%年利率
    },
    {
      'name': '车贷',
      'type': DebtType.carLoan,
      'icon': Icons.directions_car,
      'color': Colors.green,
      'interestRate': 0.06,  // 6%年利率
    },
    {
      'name': '个人贷款',
      'type': DebtType.personalLoan,
      'icon': Icons.person,
      'color': Colors.orange,
      'interestRate': 0.12,  // 12%年利率
    },
    {
      'name': '学生贷款',
      'type': DebtType.studentLoan,
      'icon': Icons.school,
      'color': Colors.purple,
      'interestRate': 0.05,  // 5%年利率
    },
    {
      'name': '医疗债务',
      'type': DebtType.medicalDebt,
      'icon': Icons.local_hospital,
      'color': Colors.pink,
      'interestRate': 0.0,   // 通常无息
    },
    {
      'name': '其他债务',
      'type': DebtType.other,
      'icon': Icons.monetization_on,
      'color': Colors.grey,
      'interestRate': 0.10,  // 10%年利率
    },
  ];
}

/// 还款计算器
class DebtCalculator {
  /// 生成还款计划（等额本息）
  static List<RepaymentPlanItem> generateAmortizationPlan({
    required double principal,
    required double annualRate,
    required int months,
    required DateTime startDate,
  }) {
    if (months <= 0 || principal <= 0) return [];

    final monthlyRate = annualRate / 12;
    double balance = principal;
    double cumulativeInterest = 0;

    // 计算月供（等额本息公式）
    double monthlyPayment;
    if (monthlyRate > 0) {
      monthlyPayment = principal * monthlyRate *
          (1 + monthlyRate).pow(months.toDouble()) /
          ((1 + monthlyRate).pow(months.toDouble()) - 1);
    } else {
      monthlyPayment = principal / months;
    }

    final items = <RepaymentPlanItem>[];

    for (int i = 1; i <= months; i++) {
      final interest = balance * monthlyRate;
      final principalPaid = monthlyPayment - interest;
      balance -= principalPaid;
      cumulativeInterest += interest;

      if (balance < 0.01) balance = 0;

      items.add(RepaymentPlanItem(
        month: i,
        date: DateTime(startDate.year, startDate.month + i, startDate.day),
        payment: monthlyPayment,
        principal: principalPaid,
        interest: interest,
        balanceAfter: balance,
        cumulativeInterest: cumulativeInterest,
      ));
    }

    return items;
  }

  /// 计算按特定金额还款需要的月数和总利息
  static Map<String, dynamic> calculatePayoffWithPayment({
    required double balance,
    required double annualRate,
    required double monthlyPayment,
  }) {
    if (balance <= 0) {
      return {'months': 0, 'totalInterest': 0.0, 'totalPaid': 0.0};
    }

    final monthlyRate = annualRate / 12;
    double currentBalance = balance;
    double totalInterest = 0;
    int months = 0;

    // 检查是否能还清
    if (monthlyPayment <= currentBalance * monthlyRate && monthlyRate > 0) {
      return {'months': -1, 'totalInterest': -1.0, 'totalPaid': -1.0}; // 表示无法还清
    }

    while (currentBalance > 0 && months < 1200) {
      double interest = currentBalance * monthlyRate;
      totalInterest += interest;
      currentBalance = currentBalance + interest - monthlyPayment;
      months++;

      if (currentBalance < 0) currentBalance = 0;
    }

    return {
      'months': months,
      'totalInterest': totalInterest,
      'totalPaid': balance + totalInterest,
    };
  }

  /// 雪球法排序 - 按余额从小到大
  static List<Debt> sortBySnowball(List<Debt> debts) {
    final sorted = List<Debt>.from(debts.where((d) => !d.isCompleted));
    sorted.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
    return sorted;
  }

  /// 雪崩法排序 - 按利率从高到低
  static List<Debt> sortByAvalanche(List<Debt> debts) {
    final sorted = List<Debt>.from(debts.where((d) => !d.isCompleted));
    sorted.sort((a, b) => b.interestRate.compareTo(a.interestRate));
    return sorted;
  }

  /// 模拟还款计划
  static RepaymentSimulation simulateRepayment({
    required List<Debt> debts,
    required RepaymentStrategy strategy,
    required double extraPayment, // 每月额外可用于还债的金额
  }) {
    // 按策略排序
    List<Debt> sortedDebts;
    switch (strategy) {
      case RepaymentStrategy.snowball:
        sortedDebts = sortBySnowball(debts);
        break;
      case RepaymentStrategy.avalanche:
        sortedDebts = sortByAvalanche(debts);
        break;
      case RepaymentStrategy.custom:
        sortedDebts = List.from(debts.where((d) => !d.isCompleted));
        break;
    }

    if (sortedDebts.isEmpty) {
      return RepaymentSimulation(
        strategy: strategy,
        plans: [],
        totalMonths: 0,
        totalInterest: 0,
        totalPaid: 0,
        payoffDate: DateTime.now(),
      );
    }

    // 初始化每个债务的当前余额和计划
    final balances = Map<String, double>.fromEntries(
      sortedDebts.map((d) => MapEntry(d.id, d.currentBalance))
    );
    final plans = Map<String, List<RepaymentPlanItem>>.fromEntries(
      sortedDebts.map((d) => MapEntry(d.id, <RepaymentPlanItem>[]))
    );
    final payoffMonths = <String, int>{};

    int month = 0;
    double totalInterest = 0;
    final startDate = DateTime.now();

    while (balances.values.any((b) => b > 0) && month < 1200) {
      month++;
      double availableExtra = extraPayment;

      // 先支付所有债务的最低还款额和利息
      for (final debt in sortedDebts) {
        if (balances[debt.id]! <= 0) continue;

        double balance = balances[debt.id]!;
        double interest = balance * debt.monthlyInterestRate;
        totalInterest += interest;

        double payment = debt.minimumPayment.clamp(0, balance + interest);
        double principalPaid = payment - interest;
        if (principalPaid < 0) principalPaid = 0;

        balance = balance + interest - payment;
        if (balance < 0.01) {
          balance = 0;
          payoffMonths[debt.id] = month;
        }

        balances[debt.id] = balance;

        double cumulativeInterest = plans[debt.id]!.isEmpty ? interest
            : plans[debt.id]!.last.cumulativeInterest + interest;

        plans[debt.id]!.add(RepaymentPlanItem(
          month: month,
          date: DateTime(startDate.year, startDate.month + month, startDate.day),
          payment: payment,
          principal: principalPaid,
          interest: interest,
          balanceAfter: balance,
          cumulativeInterest: cumulativeInterest,
        ));
      }

      // 将额外还款投入到优先级最高的未还清债务
      for (final debt in sortedDebts) {
        if (balances[debt.id]! <= 0 || availableExtra <= 0) continue;

        double extraPay = availableExtra.clamp(0, balances[debt.id]!);
        balances[debt.id] = balances[debt.id]! - extraPay;
        availableExtra -= extraPay;

        if (balances[debt.id]! < 0.01) {
          balances[debt.id] = 0;
          payoffMonths[debt.id] = month;
        }

        // 更新最后一条记录
        if (plans[debt.id]!.isNotEmpty) {
          final last = plans[debt.id]!.last;
          plans[debt.id]![plans[debt.id]!.length - 1] = RepaymentPlanItem(
            month: last.month,
            date: last.date,
            payment: last.payment + extraPay,
            principal: last.principal + extraPay,
            interest: last.interest,
            balanceAfter: balances[debt.id]!,
            cumulativeInterest: last.cumulativeInterest,
          );
        }

        break; // 只投入到一个债务
      }
    }

    // 构建结果
    final debtPlans = sortedDebts.map((debt) {
      final items = plans[debt.id]!;
      return DebtRepaymentPlan(
        debt: debt,
        items: items,
        totalInterest: items.isEmpty ? 0 : items.last.cumulativeInterest,
        payoffMonth: payoffMonths[debt.id] ?? month,
        payoffDate: DateTime(startDate.year, startDate.month + (payoffMonths[debt.id] ?? month), startDate.day),
      );
    }).toList();

    double totalPaid = sortedDebts.fold(0.0, (sum, d) => sum + d.currentBalance) + totalInterest;

    return RepaymentSimulation(
      strategy: strategy,
      plans: debtPlans,
      totalMonths: month,
      totalInterest: totalInterest,
      totalPaid: totalPaid,
      payoffDate: DateTime(startDate.year, startDate.month + month, startDate.day),
    );
  }

  /// 比较不同策略的利息节省
  static Map<String, double> compareStrategies({
    required List<Debt> debts,
    required double extraPayment,
  }) {
    final snowball = simulateRepayment(
      debts: debts,
      strategy: RepaymentStrategy.snowball,
      extraPayment: extraPayment,
    );

    final avalanche = simulateRepayment(
      debts: debts,
      strategy: RepaymentStrategy.avalanche,
      extraPayment: extraPayment,
    );

    return {
      'snowballInterest': snowball.totalInterest,
      'snowballMonths': snowball.totalMonths.toDouble(),
      'avalancheInterest': avalanche.totalInterest,
      'avalancheMonths': avalanche.totalMonths.toDouble(),
      'interestSaved': snowball.totalInterest - avalanche.totalInterest,
      'monthsSaved': (snowball.totalMonths - avalanche.totalMonths).toDouble(),
    };
  }
}

extension _DoublePow on double {
  double pow(double exponent) {
    double result = 1;
    for (int i = 0; i < exponent.round(); i++) {
      result *= this;
    }
    return result;
  }
}
