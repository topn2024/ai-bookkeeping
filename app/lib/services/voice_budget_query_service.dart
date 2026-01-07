import '../models/budget_vault.dart';
import 'vault_repository.dart';

/// 语音查询意图类型
enum VoiceBudgetIntent {
  /// 查询总预算
  queryTotalBudget,

  /// 查询特定小金库
  querySpecificVault,

  /// 查询剩余金额
  queryRemaining,

  /// 查询消费情况
  querySpending,

  /// 查询储蓄进度
  querySavingsProgress,

  /// 查询超支情况
  queryOverspent,

  /// 获取预算建议
  getBudgetSuggestion,

  /// 未识别的意图
  unknown,
}

/// 语音查询结果
class VoiceBudgetQueryResult {
  final VoiceBudgetIntent intent;
  final String spokenResponse; // TTS播报文案
  final String displayText; // 屏幕显示文案
  final Map<String, dynamic>? data;
  final bool success;

  const VoiceBudgetQueryResult({
    required this.intent,
    required this.spokenResponse,
    required this.displayText,
    this.data,
    this.success = true,
  });

  factory VoiceBudgetQueryResult.error(String message) {
    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.unknown,
      spokenResponse: message,
      displayText: message,
      success: false,
    );
  }
}

/// 语音意图识别结果
class IntentRecognitionResult {
  final VoiceBudgetIntent intent;
  final Map<String, String> entities; // 提取的实体（如小金库名称）
  final double confidence;

  const IntentRecognitionResult({
    required this.intent,
    this.entities = const {},
    required this.confidence,
  });
}

/// 语音预算查询服务
///
/// 处理语音输入的预算查询请求，返回适合TTS播报的响应
class VoiceBudgetQueryService {
  final VaultRepository _vaultRepo;

  // 意图关键词映射
  static const Map<VoiceBudgetIntent, List<String>> _intentKeywords = {
    VoiceBudgetIntent.queryTotalBudget: [
      '总预算', '总共', '一共', '预算多少', '预算情况',
    ],
    VoiceBudgetIntent.queryRemaining: [
      '还剩', '剩余', '还有多少', '剩多少', '可用',
    ],
    VoiceBudgetIntent.querySpending: [
      '花了', '消费', '支出', '用了多少', '花费',
    ],
    VoiceBudgetIntent.querySavingsProgress: [
      '储蓄', '存了', '攒了', '储蓄进度', '存款',
    ],
    VoiceBudgetIntent.queryOverspent: [
      '超支', '超了', '超预算', '透支',
    ],
    VoiceBudgetIntent.getBudgetSuggestion: [
      '建议', '怎么分配', '该怎么', '如何',
    ],
    VoiceBudgetIntent.querySpecificVault: [
      '小金库', '金库', // 需要结合实体识别
    ],
  };

  VoiceBudgetQueryService(this._vaultRepo);

  /// 处理语音查询
  Future<VoiceBudgetQueryResult> processVoiceQuery(String voiceInput) async {
    // 1. 识别意图
    final intentResult = await recognizeIntent(voiceInput);

    // 2. 根据意图生成响应
    switch (intentResult.intent) {
      case VoiceBudgetIntent.queryTotalBudget:
        return _handleTotalBudgetQuery();

      case VoiceBudgetIntent.querySpecificVault:
        final vaultName = intentResult.entities['vaultName'];
        return _handleSpecificVaultQuery(vaultName);

      case VoiceBudgetIntent.queryRemaining:
        return _handleRemainingQuery(intentResult.entities['vaultName']);

      case VoiceBudgetIntent.querySpending:
        return _handleSpendingQuery(intentResult.entities['vaultName']);

      case VoiceBudgetIntent.querySavingsProgress:
        return _handleSavingsProgressQuery();

      case VoiceBudgetIntent.queryOverspent:
        return _handleOverspentQuery();

      case VoiceBudgetIntent.getBudgetSuggestion:
        return _handleSuggestionQuery();

      case VoiceBudgetIntent.unknown:
        return VoiceBudgetQueryResult.error(
          '抱歉，我没有理解您的问题。您可以问我"还剩多少钱"或"本月花了多少"。',
        );
    }
  }

  /// 识别语音意图
  Future<IntentRecognitionResult> recognizeIntent(String input) async {
    final normalizedInput = input.toLowerCase().trim();
    final entities = <String, String>{};

    // 尝试提取小金库名称
    final vaults = await _vaultRepo.getEnabled();
    for (final vault in vaults) {
      if (normalizedInput.contains(vault.name)) {
        entities['vaultName'] = vault.name;
        break;
      }
    }

    // 匹配意图
    VoiceBudgetIntent matchedIntent = VoiceBudgetIntent.unknown;
    double highestConfidence = 0;

    for (final entry in _intentKeywords.entries) {
      for (final keyword in entry.value) {
        if (normalizedInput.contains(keyword)) {
          final confidence = keyword.length / normalizedInput.length;
          if (confidence > highestConfidence) {
            highestConfidence = confidence;
            matchedIntent = entry.key;
          }
        }
      }
    }

    // 如果提取到了小金库名称但没有其他意图，默认查询该小金库
    if (entities.containsKey('vaultName') &&
        matchedIntent == VoiceBudgetIntent.unknown) {
      matchedIntent = VoiceBudgetIntent.querySpecificVault;
      highestConfidence = 0.5;
    }

    return IntentRecognitionResult(
      intent: matchedIntent,
      entities: entities,
      confidence: highestConfidence.clamp(0.0, 1.0),
    );
  }

  /// 生成预算播报文案
  Future<String> generateBudgetAnnouncement() async {
    final vaults = await _vaultRepo.getEnabled();
    if (vaults.isEmpty) {
      return '您还没有设置预算，建议先创建小金库来管理资金。';
    }

    final summary = await _vaultRepo.getSummary();
    final healthyCount = vaults.where((v) => v.status == VaultStatus.healthy).length;
    final overspentVaults = vaults.where((v) => v.isOverSpent).toList();

    final buffer = StringBuffer();

    // 开场
    buffer.write('您好，为您播报今日预算情况。');

    // 总览
    buffer.write('本月预算总计${_formatMoney(summary.totalAllocated)}元，');
    buffer.write('已消费${_formatMoney(summary.totalSpent)}元，');
    buffer.write('剩余${_formatMoney(summary.totalAvailable)}元。');

    // 健康状态
    if (overspentVaults.isNotEmpty) {
      buffer.write('注意，有${overspentVaults.length}个小金库已超支：');
      for (final vault in overspentVaults.take(3)) {
        buffer.write('${vault.name}超支${_formatMoney(-vault.available)}元；');
      }
    } else if (healthyCount == vaults.length) {
      buffer.write('所有小金库状态良好。');
    }

    // 建议
    final daysRemaining = _getDaysRemainingInMonth();
    if (daysRemaining > 0 && summary.totalAvailable > 0) {
      final dailyBudget = summary.totalAvailable / daysRemaining;
      buffer.write('本月还剩$daysRemaining天，建议每日消费控制在${_formatMoney(dailyBudget)}元以内。');
    }

    return buffer.toString();
  }

  // ==================== 私有处理方法 ====================

  /// 处理总预算查询
  Future<VoiceBudgetQueryResult> _handleTotalBudgetQuery() async {
    final summary = await _vaultRepo.getSummary();
    final vaults = await _vaultRepo.getEnabled();

    final spoken = '您本月总预算${_formatMoney(summary.totalAllocated)}元，'
        '已消费${_formatMoney(summary.totalSpent)}元，'
        '剩余${_formatMoney(summary.totalAvailable)}元。'
        '共有${vaults.length}个小金库。';

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.queryTotalBudget,
      spokenResponse: spoken,
      displayText: '总预算: ¥${summary.totalAllocated.toStringAsFixed(0)}\n'
          '已消费: ¥${summary.totalSpent.toStringAsFixed(0)}\n'
          '剩余: ¥${summary.totalAvailable.toStringAsFixed(0)}',
      data: {
        'totalAllocated': summary.totalAllocated,
        'totalSpent': summary.totalSpent,
        'totalAvailable': summary.totalAvailable,
        'vaultCount': vaults.length,
      },
    );
  }

  /// 处理特定小金库查询
  Future<VoiceBudgetQueryResult> _handleSpecificVaultQuery(String? vaultName) async {
    if (vaultName == null) {
      return VoiceBudgetQueryResult.error('请告诉我您要查询哪个小金库。');
    }

    final vaults = await _vaultRepo.getEnabled();
    final vault = vaults.firstWhere(
      (v) => v.name.contains(vaultName),
      orElse: () => throw Exception('未找到'),
    );

    String statusText;
    if (vault.isOverSpent) {
      statusText = '已超支${_formatMoney(-vault.available)}元';
    } else if (vault.usageRate > 0.8) {
      statusText = '余额较低，请注意控制';
    } else {
      statusText = '状态良好';
    }

    final spoken = '${vault.name}预算${_formatMoney(vault.allocatedAmount)}元，'
        '已花费${_formatMoney(vault.spentAmount)}元，'
        '剩余${_formatMoney(vault.available)}元。$statusText。';

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.querySpecificVault,
      spokenResponse: spoken,
      displayText: '${vault.name}\n'
          '预算: ¥${vault.allocatedAmount.toStringAsFixed(0)}\n'
          '已花: ¥${vault.spentAmount.toStringAsFixed(0)}\n'
          '剩余: ¥${vault.available.toStringAsFixed(0)}',
      data: {
        'vaultId': vault.id,
        'vaultName': vault.name,
        'allocated': vault.allocatedAmount,
        'spent': vault.spentAmount,
        'available': vault.available,
        'status': vault.status.name,
      },
    );
  }

  /// 处理剩余金额查询
  Future<VoiceBudgetQueryResult> _handleRemainingQuery(String? vaultName) async {
    if (vaultName != null) {
      // 查询特定小金库的剩余
      final vaults = await _vaultRepo.getEnabled();
      try {
        final vault = vaults.firstWhere((v) => v.name.contains(vaultName));
        final spoken = '${vault.name}还剩${_formatMoney(vault.available)}元。';
        return VoiceBudgetQueryResult(
          intent: VoiceBudgetIntent.queryRemaining,
          spokenResponse: spoken,
          displayText: '${vault.name}: ¥${vault.available.toStringAsFixed(0)}',
          data: {'vaultName': vault.name, 'available': vault.available},
        );
      } catch (_) {
        return VoiceBudgetQueryResult.error('未找到名为"$vaultName"的小金库。');
      }
    }

    // 查询总剩余
    final summary = await _vaultRepo.getSummary();
    final daysRemaining = _getDaysRemainingInMonth();

    String suggestion = '';
    if (daysRemaining > 0 && summary.totalAvailable > 0) {
      final dailyBudget = summary.totalAvailable / daysRemaining;
      suggestion = '本月还剩$daysRemaining天，建议日均消费${_formatMoney(dailyBudget)}元。';
    }

    final spoken = '您本月还剩${_formatMoney(summary.totalAvailable)}元。$suggestion';

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.queryRemaining,
      spokenResponse: spoken,
      displayText: '剩余预算: ¥${summary.totalAvailable.toStringAsFixed(0)}',
      data: {
        'totalAvailable': summary.totalAvailable,
        'daysRemaining': daysRemaining,
      },
    );
  }

  /// 处理消费查询
  Future<VoiceBudgetQueryResult> _handleSpendingQuery(String? vaultName) async {
    if (vaultName != null) {
      final vaults = await _vaultRepo.getEnabled();
      try {
        final vault = vaults.firstWhere((v) => v.name.contains(vaultName));
        final usagePercent = (vault.usageRate * 100).toStringAsFixed(0);
        final spoken = '${vault.name}本月消费${_formatMoney(vault.spentAmount)}元，'
            '占预算的$usagePercent%。';
        return VoiceBudgetQueryResult(
          intent: VoiceBudgetIntent.querySpending,
          spokenResponse: spoken,
          displayText: '${vault.name}消费: ¥${vault.spentAmount.toStringAsFixed(0)} ($usagePercent%)',
          data: {'vaultName': vault.name, 'spent': vault.spentAmount, 'usageRate': vault.usageRate},
        );
      } catch (_) {
        return VoiceBudgetQueryResult.error('未找到名为"$vaultName"的小金库。');
      }
    }

    final summary = await _vaultRepo.getSummary();
    final usageRate = summary.totalAllocated > 0
        ? summary.totalSpent / summary.totalAllocated
        : 0.0;
    final usagePercent = (usageRate * 100).toStringAsFixed(0);

    final spoken = '本月已消费${_formatMoney(summary.totalSpent)}元，'
        '占总预算的$usagePercent%。';

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.querySpending,
      spokenResponse: spoken,
      displayText: '本月消费: ¥${summary.totalSpent.toStringAsFixed(0)} ($usagePercent%)',
      data: {
        'totalSpent': summary.totalSpent,
        'usageRate': usageRate,
      },
    );
  }

  /// 处理储蓄进度查询
  Future<VoiceBudgetQueryResult> _handleSavingsProgressQuery() async {
    final vaults = await _vaultRepo.getEnabled();
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings).toList();

    if (savingsVaults.isEmpty) {
      return VoiceBudgetQueryResult(
        intent: VoiceBudgetIntent.querySavingsProgress,
        spokenResponse: '您还没有设置储蓄目标，建议创建一个储蓄类小金库。',
        displayText: '暂无储蓄目标',
      );
    }

    final totalTarget = savingsVaults.fold(0.0, (sum, v) => sum + v.targetAmount);
    final totalSaved = savingsVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final overallProgress = totalTarget > 0 ? totalSaved / totalTarget : 0.0;

    final buffer = StringBuffer('您的储蓄情况：');
    for (final vault in savingsVaults.take(3)) {
      final progress = (vault.progress * 100).toStringAsFixed(0);
      buffer.write('${vault.name}已存${_formatMoney(vault.allocatedAmount)}元，完成$progress%；');
    }

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.querySavingsProgress,
      spokenResponse: buffer.toString(),
      displayText: '储蓄总进度: ${(overallProgress * 100).toStringAsFixed(0)}%\n'
          '已存: ¥${totalSaved.toStringAsFixed(0)} / ¥${totalTarget.toStringAsFixed(0)}',
      data: {
        'totalTarget': totalTarget,
        'totalSaved': totalSaved,
        'progress': overallProgress,
        'savingsVaults': savingsVaults.map((v) => v.name).toList(),
      },
    );
  }

  /// 处理超支查询
  Future<VoiceBudgetQueryResult> _handleOverspentQuery() async {
    final overspentVaults = await _vaultRepo.getOverspentVaults();

    if (overspentVaults.isEmpty) {
      return VoiceBudgetQueryResult(
        intent: VoiceBudgetIntent.queryOverspent,
        spokenResponse: '太棒了！您目前没有超支的小金库。',
        displayText: '无超支小金库 ✓',
      );
    }

    final buffer = StringBuffer('有${overspentVaults.length}个小金库超支：');
    var totalOverspent = 0.0;

    for (final vault in overspentVaults) {
      final overspent = -vault.available;
      totalOverspent += overspent;
      buffer.write('${vault.name}超支${_formatMoney(overspent)}元；');
    }

    buffer.write('建议调整预算或减少消费。');

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.queryOverspent,
      spokenResponse: buffer.toString(),
      displayText: '超支小金库: ${overspentVaults.length}个\n'
          '总超支: ¥${totalOverspent.toStringAsFixed(0)}',
      data: {
        'overspentCount': overspentVaults.length,
        'totalOverspent': totalOverspent,
        'vaults': overspentVaults.map((v) => {
          'name': v.name,
          'overspent': -v.available,
        }).toList(),
      },
    );
  }

  /// 处理建议查询
  Future<VoiceBudgetQueryResult> _handleSuggestionQuery() async {
    final vaults = await _vaultRepo.getEnabled();
    final summary = await _vaultRepo.getSummary();
    final suggestions = <String>[];

    // 检查储蓄率
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings);
    final savingsAmount = savingsVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final savingsRate = summary.totalAllocated > 0
        ? savingsAmount / summary.totalAllocated
        : 0.0;

    if (savingsRate < 0.1) {
      suggestions.add('储蓄比例较低，建议增加到收入的10%以上');
    }

    // 检查超支
    final overspentVaults = vaults.where((v) => v.isOverSpent).toList();
    if (overspentVaults.isNotEmpty) {
      suggestions.add('${overspentVaults.first.name}已超支，建议控制消费或调拨资金');
    }

    // 检查使用率高的小金库
    final highUsageVaults = vaults.where((v) =>
        v.type == VaultType.flexible && v.usageRate > 0.8 && !v.isOverSpent);
    if (highUsageVaults.isNotEmpty) {
      suggestions.add('${highUsageVaults.first.name}余额较低，剩余${_getDaysRemainingInMonth()}天请谨慎消费');
    }

    if (suggestions.isEmpty) {
      suggestions.add('您的预算执行情况良好，继续保持');
    }

    final spoken = suggestions.join('。') + '。';

    return VoiceBudgetQueryResult(
      intent: VoiceBudgetIntent.getBudgetSuggestion,
      spokenResponse: spoken,
      displayText: suggestions.join('\n'),
      data: {'suggestions': suggestions},
    );
  }

  // ==================== 工具方法 ====================

  /// 格式化金额为口语化表达
  String _formatMoney(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}千';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  /// 获取本月剩余天数
  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return endOfMonth.day - now.day;
  }

  /// 快捷查询方法：还剩多少钱
  Future<String> queryRemaining() async {
    final result = await processVoiceQuery('还剩多少');
    return result.spokenResponse;
  }

  /// 快捷查询方法：本月消费
  Future<String> querySpending() async {
    final result = await processVoiceQuery('花了多少');
    return result.spokenResponse;
  }

  /// 快捷查询方法：储蓄进度
  Future<String> querySavings() async {
    final result = await processVoiceQuery('储蓄进度');
    return result.spokenResponse;
  }
}
