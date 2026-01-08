import 'dart:async';

/// AA分摊与多人消费处理服务
///
/// 功能：
/// 1. AA制检测：识别文本中的AA/分摊关键词
/// 2. 人数提取：从自然语言中提取参与人数
/// 3. 金额拆分：支持均摊/按比例/自定义分摊
/// 4. 分摊记录：生成个人应付金额
class SplitBillService {
  /// 检测并处理AA制
  Future<AADetectionResult> detectAndProcessAA(
    String text,
    double totalAmount,
  ) async {
    // AA制关键词
    final aaKeywords = [
      'AA',
      'aa',
      'A A',
      'Aa',
      '平摊',
      '均摊',
      '分摊',
      '各付',
      '每人',
      'AA制',
      '平均分',
      '一起付',
      '分开付',
      '各出',
    ];
    final hasAAKeyword = aaKeywords.any((k) => text.contains(k));

    if (!hasAAKeyword) {
      return AADetectionResult(isAA: false);
    }

    // 提取人数
    final peopleCount = extractPeopleCount(text);

    if (peopleCount != null && peopleCount > 1) {
      final perPersonAmount = totalAmount / peopleCount;

      return AADetectionResult(
        isAA: true,
        totalAmount: totalAmount,
        peopleCount: peopleCount,
        perPersonAmount: perPersonAmount,
        confidence: 0.9,
        splitType: SplitType.equal,
      );
    }

    // 如果无法确定人数，返回待确认状态
    return AADetectionResult(
      isAA: true,
      totalAmount: totalAmount,
      needsConfirmation: true,
      confidence: 0.7,
    );
  }

  /// 提取人数
  int? extractPeopleCount(String text) {
    // 模式1: "和XX一起" -> 2人
    if (RegExp(r'和.+一起').hasMatch(text)) {
      final peopleMatch = RegExp(r'和(\d+)个人').firstMatch(text);
      if (peopleMatch != null) {
        return int.parse(peopleMatch.group(1)!) + 1;
      }
      // 检查是否有具体名字数量
      final namesMatch = RegExp(r'和([^一]+)一起').firstMatch(text);
      if (namesMatch != null) {
        final names = namesMatch.group(1)!;
        // 按顿号、逗号分隔计数
        final nameCount =
            names.split(RegExp(r'[、,，和与]')).where((s) => s.isNotEmpty).length;
        return nameCount + 1; // 加上说话者自己
      }
      return 2; // 默认2人
    }

    // 模式2: "X个人/位"
    final countPatterns = [
      RegExp(r'(\d+)\s*个人'),
      RegExp(r'(\d+)\s*人'),
      RegExp(r'(\d+)\s*位'),
      RegExp(r'([二三四五六七八九十])\s*个人'),
      RegExp(r'([二三四五六七八九十])\s*人'),
    ];

    for (final pattern in countPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = match.group(1)!;
        if (RegExp(r'\d+').hasMatch(value)) {
          return int.parse(value);
        } else {
          return _chineseToInt(value);
        }
      }
    }

    // 模式3: "我们三个"
    final pronounPattern = RegExp(r'我们([二三四五六七八九十]|\d+)个');
    final pronounMatch = pronounPattern.firstMatch(text);
    if (pronounMatch != null) {
      final value = pronounMatch.group(1)!;
      return RegExp(r'\d+').hasMatch(value)
          ? int.parse(value)
          : _chineseToInt(value);
    }

    // 模式4: "俩人"/"仨人"
    if (text.contains('俩人') || text.contains('俩')) {
      return 2;
    }
    if (text.contains('仨人') || text.contains('仨')) {
      return 3;
    }

    return null;
  }

  /// 中文数字转整数
  int _chineseToInt(String chinese) {
    const map = {
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '十一': 11,
      '十二': 12,
    };
    return map[chinese] ?? 2;
  }

  /// 计算分摊金额
  SplitResult calculateSplit({
    required double totalAmount,
    required int peopleCount,
    SplitType type = SplitType.equal,
    List<double>? customRatios,
    List<double>? customAmounts,
    int? myIndex,
  }) {
    switch (type) {
      case SplitType.equal:
        return _calculateEqualSplit(totalAmount, peopleCount, myIndex);

      case SplitType.ratio:
        if (customRatios == null || customRatios.length != peopleCount) {
          throw ArgumentError('比例分摊需要提供与人数匹配的比例列表');
        }
        return _calculateRatioSplit(
            totalAmount, peopleCount, customRatios, myIndex);

      case SplitType.custom:
        if (customAmounts == null || customAmounts.length != peopleCount) {
          throw ArgumentError('自定义分摊需要提供与人数匹配的金额列表');
        }
        return _calculateCustomSplit(totalAmount, customAmounts, myIndex);
    }
  }

  /// 均等分摊
  SplitResult _calculateEqualSplit(
    double totalAmount,
    int peopleCount,
    int? myIndex,
  ) {
    final perPerson = totalAmount / peopleCount;
    // 处理小数点精度问题：向下取整到分，余额给最后一人
    final roundedPerPerson = (perPerson * 100).floor() / 100;
    final remainder = totalAmount - (roundedPerPerson * peopleCount);

    final amounts = List.generate(peopleCount, (i) {
      if (i == peopleCount - 1) {
        return roundedPerPerson + remainder;
      }
      return roundedPerPerson;
    });

    return SplitResult(
      totalAmount: totalAmount,
      peopleCount: peopleCount,
      splitType: SplitType.equal,
      amounts: amounts,
      myAmount: myIndex != null ? amounts[myIndex] : amounts.first,
      myIndex: myIndex ?? 0,
    );
  }

  /// 按比例分摊
  SplitResult _calculateRatioSplit(
    double totalAmount,
    int peopleCount,
    List<double> ratios,
    int? myIndex,
  ) {
    final totalRatio = ratios.reduce((a, b) => a + b);
    final amounts = ratios.map((r) {
      final amount = totalAmount * (r / totalRatio);
      return (amount * 100).round() / 100;
    }).toList();

    // 调整余额
    final sumAmounts = amounts.reduce((a, b) => a + b);
    final diff = totalAmount - sumAmounts;
    amounts[amounts.length - 1] += diff;

    return SplitResult(
      totalAmount: totalAmount,
      peopleCount: peopleCount,
      splitType: SplitType.ratio,
      amounts: amounts,
      ratios: ratios,
      myAmount: myIndex != null ? amounts[myIndex] : amounts.first,
      myIndex: myIndex ?? 0,
    );
  }

  /// 自定义金额分摊
  SplitResult _calculateCustomSplit(
    double totalAmount,
    List<double> customAmounts,
    int? myIndex,
  ) {
    final sum = customAmounts.reduce((a, b) => a + b);
    if ((sum - totalAmount).abs() > 0.01) {
      throw ArgumentError('自定义金额总和(¥$sum)与总金额(¥$totalAmount)不匹配');
    }

    return SplitResult(
      totalAmount: totalAmount,
      peopleCount: customAmounts.length,
      splitType: SplitType.custom,
      amounts: customAmounts,
      myAmount: myIndex != null ? customAmounts[myIndex] : customAmounts.first,
      myIndex: myIndex ?? 0,
    );
  }

  /// 生成分摊描述
  String generateSplitDescription(SplitResult result) {
    final buffer = StringBuffer();
    buffer.write('总计¥${result.totalAmount.toStringAsFixed(2)}，');
    buffer.write('${result.peopleCount}人');

    switch (result.splitType) {
      case SplitType.equal:
        buffer.write('均摊');
        break;
      case SplitType.ratio:
        buffer.write('按比例');
        break;
      case SplitType.custom:
        buffer.write('自定义');
        break;
    }

    buffer.write('，我付¥${result.myAmount.toStringAsFixed(2)}');
    return buffer.toString();
  }

  /// 解析分摊请求
  Future<SplitParseResult> parseSplitRequest(String text) async {
    final result = SplitParseResult();

    // 提取总金额
    final amountPatterns = [
      RegExp(r'总[共计]?\s*[¥￥]?\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'一共\s*[¥￥]?\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'[¥￥]\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*[元块]'),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result.totalAmount = double.parse(match.group(1)!);
        break;
      }
    }

    // 提取人数
    result.peopleCount = extractPeopleCount(text);

    // 检测分摊类型
    if (text.contains('按比例') || text.contains('比例分')) {
      result.splitType = SplitType.ratio;
    } else if (text.contains('我付') || text.contains('我出')) {
      result.splitType = SplitType.custom;
      // 提取"我付"的金额
      final myPayPattern = RegExp(r'我[付出]\s*[¥￥]?\s*(\d+(?:\.\d{1,2})?)');
      final myPayMatch = myPayPattern.firstMatch(text);
      if (myPayMatch != null) {
        result.myAmount = double.parse(myPayMatch.group(1)!);
      }
    } else {
      result.splitType = SplitType.equal;
    }

    return result;
  }
}

/// AA检测结果
class AADetectionResult {
  final bool isAA;
  final double? totalAmount;
  final int? peopleCount;
  final double? perPersonAmount;
  final bool needsConfirmation;
  final double confidence;
  final SplitType? splitType;

  const AADetectionResult({
    required this.isAA,
    this.totalAmount,
    this.peopleCount,
    this.perPersonAmount,
    this.needsConfirmation = false,
    this.confidence = 0.0,
    this.splitType,
  });

  @override
  String toString() {
    if (!isAA) return 'AADetectionResult(isAA: false)';
    return 'AADetectionResult(isAA: true, total: $totalAmount, '
        'people: $peopleCount, perPerson: $perPersonAmount, '
        'confidence: $confidence)';
  }
}

/// 分摊类型
enum SplitType {
  equal, // 均等分摊
  ratio, // 按比例分摊
  custom, // 自定义金额
}

/// 分摊计算结果
class SplitResult {
  final double totalAmount;
  final int peopleCount;
  final SplitType splitType;
  final List<double> amounts;
  final List<double>? ratios;
  final double myAmount;
  final int myIndex;

  const SplitResult({
    required this.totalAmount,
    required this.peopleCount,
    required this.splitType,
    required this.amounts,
    this.ratios,
    required this.myAmount,
    required this.myIndex,
  });

  /// 验证金额总和
  bool get isValid {
    final sum = amounts.reduce((a, b) => a + b);
    return (sum - totalAmount).abs() < 0.01;
  }
}

/// 分摊解析结果
class SplitParseResult {
  double? totalAmount;
  int? peopleCount;
  SplitType? splitType;
  double? myAmount;
  List<String>? participants;

  bool get isComplete =>
      totalAmount != null && peopleCount != null && peopleCount! > 1;
}

/// 分摊成员
class SplitMember {
  final String id;
  final String name;
  final double? customAmount;
  final double? ratio;
  final bool isPayer; // 是否是付款人

  const SplitMember({
    required this.id,
    required this.name,
    this.customAmount,
    this.ratio,
    this.isPayer = false,
  });
}

/// 分摊交易记录
class SplitTransaction {
  final String id;
  final String originalTransactionId;
  final double totalAmount;
  final SplitType splitType;
  final List<SplitMember> members;
  final DateTime createdAt;
  final SplitSettlementStatus settlementStatus;

  const SplitTransaction({
    required this.id,
    required this.originalTransactionId,
    required this.totalAmount,
    required this.splitType,
    required this.members,
    required this.createdAt,
    this.settlementStatus = SplitSettlementStatus.pending,
  });
}

/// 分摊结算状态
enum SplitSettlementStatus {
  pending, // 待结算
  partial, // 部分结算
  settled, // 已结算
}
