import 'package:uuid/uuid.dart';
import '../models/expense_split.dart';
import '../models/member.dart';

/// AA分摊服务
class SplitService {
  static final SplitService _instance = SplitService._internal();
  factory SplitService() => _instance;
  SplitService._internal();

  final _uuid = const Uuid();

  // 临时存储（实际应使用数据库）
  final Map<String, SplitTransaction> _transactions = {};
  final Map<String, List<SettlementRecord>> _settlements = {};

  /// 创建分摊交易
  Future<SplitTransaction> createSplitTransaction({
    required String ledgerId,
    required double totalAmount,
    required String categoryId,
    required String description,
    required SplitType splitType,
    required List<String> participantIds,
    required List<LedgerMember> members,
    required String currentUserId,
    String? payerId,
    Map<String, double>? exactAmounts,
    Map<String, int>? shares,
    Map<String, double>? percentages,
    DateTime? transactionDate,
    String? location,
    List<String>? tags,
    List<String>? attachments,
  }) async {
    final actualPayerId = payerId ?? currentUserId;

    // 计算每人应付金额
    final participants = _calculateSplit(
      totalAmount: totalAmount,
      splitType: splitType,
      participantIds: participantIds,
      payerId: actualPayerId,
      members: members,
      exactAmounts: exactAmounts,
      shares: shares,
      percentages: percentages,
    );

    final transactionId = _uuid.v4();
    final now = DateTime.now();

    final splitInfo = SplitInfo(
      type: splitType,
      status: SplitStatus.pending,
      participants: participants,
      payerId: actualPayerId,
      createdAt: now,
    );

    final transaction = SplitTransaction(
      id: transactionId,
      ledgerId: ledgerId,
      amount: totalAmount,
      categoryId: categoryId,
      description: description,
      splitInfo: splitInfo,
      createdBy: currentUserId,
      createdAt: now,
      transactionDate: transactionDate ?? now,
      location: location,
      tags: tags,
      attachments: attachments,
    );

    _transactions[transactionId] = transaction;
    return transaction;
  }

  /// 计算分摊金额
  List<SplitParticipant> _calculateSplit({
    required double totalAmount,
    required SplitType splitType,
    required List<String> participantIds,
    required String payerId,
    required List<LedgerMember> members,
    Map<String, double>? exactAmounts,
    Map<String, int>? shares,
    Map<String, double>? percentages,
  }) {
    final participants = <SplitParticipant>[];

    switch (splitType) {
      case SplitType.equal:
        final perPerson = totalAmount / participantIds.length;
        final percentage = 100.0 / participantIds.length;
        for (final id in participantIds) {
          final member = members.firstWhere(
            (m) => m.userId == id,
            orElse: () => LedgerMember(
              id: id,
              ledgerId: '',
              userId: id,
              userName: 'Unknown',
              role: MemberRole.viewer,
              joinedAt: DateTime.now(),
            ),
          );
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            avatarUrl: member.avatarUrl,
            amount: perPerson,
            percentage: percentage,
            isPayer: id == payerId,
            isSettled: id == payerId, // 付款人自动结算
            settledAt: id == payerId ? DateTime.now() : null,
          ));
        }
        break;

      case SplitType.exact:
        for (final id in participantIds) {
          final member = members.firstWhere(
            (m) => m.userId == id,
            orElse: () => LedgerMember(
              id: id,
              ledgerId: '',
              userId: id,
              userName: 'Unknown',
              role: MemberRole.viewer,
              joinedAt: DateTime.now(),
            ),
          );
          final amount = exactAmounts?[id] ?? 0;
          final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0;
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            avatarUrl: member.avatarUrl,
            amount: amount,
            percentage: percentage.toDouble(),
            isPayer: id == payerId,
            isSettled: id == payerId,
            settledAt: id == payerId ? DateTime.now() : null,
          ));
        }
        break;

      case SplitType.shares:
        final totalShares =
            shares?.values.fold(0, (a, b) => a + b) ?? participantIds.length;
        for (final id in participantIds) {
          final member = members.firstWhere(
            (m) => m.userId == id,
            orElse: () => LedgerMember(
              id: id,
              ledgerId: '',
              userId: id,
              userName: 'Unknown',
              role: MemberRole.viewer,
              joinedAt: DateTime.now(),
            ),
          );
          final memberShares = shares?[id] ?? 1;
          final amount = totalAmount * memberShares / totalShares;
          final percentage = 100.0 * memberShares / totalShares;
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            avatarUrl: member.avatarUrl,
            amount: amount,
            percentage: percentage,
            shares: memberShares,
            isPayer: id == payerId,
            isSettled: id == payerId,
            settledAt: id == payerId ? DateTime.now() : null,
          ));
        }
        break;

      case SplitType.percentage:
        for (final id in participantIds) {
          final member = members.firstWhere(
            (m) => m.userId == id,
            orElse: () => LedgerMember(
              id: id,
              ledgerId: '',
              userId: id,
              userName: 'Unknown',
              role: MemberRole.viewer,
              joinedAt: DateTime.now(),
            ),
          );
          final percentage = percentages?[id] ?? 0;
          final amount = totalAmount * percentage / 100;
          participants.add(SplitParticipant(
            memberId: id,
            memberName: member.displayName,
            avatarUrl: member.avatarUrl,
            amount: amount,
            percentage: percentage,
            isPayer: id == payerId,
            isSettled: id == payerId,
            settledAt: id == payerId ? DateTime.now() : null,
          ));
        }
        break;
    }

    return participants;
  }

  /// 确认分摊（参与者确认自己的份额）
  Future<SplitTransaction?> confirmSplit(
    String transactionId,
    String memberId, {
    String? note,
  }) async {
    final transaction = _transactions[transactionId];
    if (transaction == null) return null;

    final updatedParticipants =
        transaction.splitInfo.participants.map((p) {
      if (p.memberId == memberId && !p.isPayer) {
        return p.copyWith(
          isSettled: true,
          settledAt: DateTime.now(),
          settlementNote: note,
        );
      }
      return p;
    }).toList();

    // 检查是否全部结算
    final allSettled =
        updatedParticipants.every((p) => p.isSettled || p.isPayer);

    final newStatus = allSettled
        ? SplitStatus.settled
        : SplitStatus.partiallySettled;

    final updatedSplitInfo = transaction.splitInfo.copyWith(
      participants: updatedParticipants,
      status: newStatus,
    );

    final updatedTransaction = transaction.copyWith(
      splitInfo: updatedSplitInfo,
    );

    _transactions[transactionId] = updatedTransaction;

    // 创建结算记录
    final participant = updatedParticipants.firstWhere(
      (p) => p.memberId == memberId,
    );
    final payer = updatedParticipants.firstWhere((p) => p.isPayer);

    final settlementRecord = SettlementRecord(
      id: _uuid.v4(),
      splitTransactionId: transactionId,
      fromMemberId: memberId,
      toMemberId: payer.memberId,
      amount: participant.amount,
      settledAt: DateTime.now(),
      note: note,
    );

    _settlements.putIfAbsent(transactionId, () => []).add(settlementRecord);

    return updatedTransaction;
  }

  /// 取消分摊
  Future<SplitTransaction?> cancelSplit(String transactionId) async {
    final transaction = _transactions[transactionId];
    if (transaction == null) return null;

    final updatedSplitInfo = transaction.splitInfo.copyWith(
      status: SplitStatus.cancelled,
    );

    final updatedTransaction = transaction.copyWith(
      splitInfo: updatedSplitInfo,
    );

    _transactions[transactionId] = updatedTransaction;
    return updatedTransaction;
  }

  /// 获取分摊交易
  Future<SplitTransaction?> getSplitTransaction(String transactionId) async {
    return _transactions[transactionId];
  }

  /// 获取账本的所有分摊交易
  Future<List<SplitTransaction>> getSplitTransactionsByLedger(
    String ledgerId, {
    SplitStatus? status,
  }) async {
    var transactions = _transactions.values
        .where((t) => t.ledgerId == ledgerId)
        .toList();

    if (status != null) {
      transactions = transactions.where((t) => t.status == status).toList();
    }

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  /// 获取成员参与的分摊交易
  Future<List<SplitTransaction>> getSplitTransactionsByMember(
    String memberId, {
    String? ledgerId,
    SplitStatus? status,
  }) async {
    var transactions = _transactions.values.where((t) {
      return t.splitInfo.participants.any((p) => p.memberId == memberId);
    }).toList();

    if (ledgerId != null) {
      transactions = transactions.where((t) => t.ledgerId == ledgerId).toList();
    }

    if (status != null) {
      transactions = transactions.where((t) => t.status == status).toList();
    }

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  /// 获取待结算的分摊（成员欠别人的）
  Future<List<SplitTransaction>> getPendingSplitsForMember(
    String memberId, {
    String? ledgerId,
  }) async {
    var transactions = _transactions.values.where((t) {
      if (t.status == SplitStatus.settled || t.status == SplitStatus.cancelled) {
        return false;
      }
      return t.splitInfo.participants.any(
        (p) => p.memberId == memberId && !p.isPayer && !p.isSettled,
      );
    }).toList();

    if (ledgerId != null) {
      transactions = transactions.where((t) => t.ledgerId == ledgerId).toList();
    }

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  /// 获取成员作为付款人的待收款分摊
  Future<List<SplitTransaction>> getPendingCollectionsForMember(
    String memberId, {
    String? ledgerId,
  }) async {
    var transactions = _transactions.values.where((t) {
      if (t.status == SplitStatus.settled || t.status == SplitStatus.cancelled) {
        return false;
      }
      return t.splitInfo.payerId == memberId;
    }).toList();

    if (ledgerId != null) {
      transactions = transactions.where((t) => t.ledgerId == ledgerId).toList();
    }

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  /// 计算成员在账本中的余额
  Future<MemberBalance> calculateMemberBalance(
    String memberId,
    String ledgerId,
    List<LedgerMember> members,
  ) async {
    final transactions = await getSplitTransactionsByLedger(ledgerId);

    double totalOwed = 0; // 别人欠我的
    double totalOwing = 0; // 我欠别人的
    final balanceMap = <String, double>{}; // memberId -> 金额（正数=欠我，负数=我欠）

    for (final transaction in transactions) {
      if (transaction.status == SplitStatus.cancelled) continue;

      for (final participant in transaction.splitInfo.participants) {
        if (participant.memberId == memberId) {
          // 我是付款人
          if (participant.isPayer) {
            // 其他未结算的参与者欠我钱
            for (final other in transaction.splitInfo.participants) {
              if (!other.isPayer && !other.isSettled) {
                totalOwed += other.amount;
                balanceMap[other.memberId] =
                    (balanceMap[other.memberId] ?? 0) + other.amount;
              }
            }
          }
          // 我不是付款人且未结算
          else if (!participant.isSettled) {
            totalOwing += participant.amount;
            balanceMap[transaction.splitInfo.payerId] =
                (balanceMap[transaction.splitInfo.payerId] ?? 0) -
                    participant.amount;
          }
        }
      }
    }

    // 构建详细余额列表
    final details = balanceMap.entries.map((entry) {
      final otherMember = members.firstWhere(
        (m) => m.userId == entry.key,
        orElse: () => LedgerMember(
          id: entry.key,
          ledgerId: ledgerId,
          userId: entry.key,
          userName: 'Unknown',
          role: MemberRole.viewer,
          joinedAt: DateTime.now(),
        ),
      );
      return BalanceDetail(
        otherMemberId: entry.key,
        otherMemberName: otherMember.displayName,
        amount: entry.value,
        relatedTransactionIds: [], // TODO: 收集相关交易ID
      );
    }).toList();

    final member = members.firstWhere(
      (m) => m.userId == memberId,
      orElse: () => LedgerMember(
        id: memberId,
        ledgerId: ledgerId,
        userId: memberId,
        userName: 'Unknown',
        role: MemberRole.viewer,
        joinedAt: DateTime.now(),
      ),
    );

    return MemberBalance(
      memberId: memberId,
      memberName: member.displayName,
      totalOwed: totalOwed,
      totalOwing: totalOwing,
      details: details,
    );
  }

  /// 计算账本中所有成员的余额汇总
  Future<List<MemberBalance>> calculateAllMemberBalances(
    String ledgerId,
    List<LedgerMember> members,
  ) async {
    final balances = <MemberBalance>[];
    for (final member in members) {
      final balance = await calculateMemberBalance(
        member.userId,
        ledgerId,
        members,
      );
      balances.add(balance);
    }
    return balances;
  }

  /// 获取结算记录
  Future<List<SettlementRecord>> getSettlementRecords(
    String transactionId,
  ) async {
    return _settlements[transactionId] ?? [];
  }

  /// 智能简化结算（最小化转账次数）
  Future<List<SimplifiedSettlement>> simplifySettlements(
    String ledgerId,
    List<LedgerMember> members,
  ) async {
    final balances = await calculateAllMemberBalances(ledgerId, members);

    // 分离债务人和债权人
    final debtors = <String, double>{}; // 欠钱的人
    final creditors = <String, double>{}; // 应收钱的人

    for (final balance in balances) {
      if (balance.netBalance > 0.01) {
        creditors[balance.memberId] = balance.netBalance;
      } else if (balance.netBalance < -0.01) {
        debtors[balance.memberId] = -balance.netBalance;
      }
    }

    final settlements = <SimplifiedSettlement>[];
    final memberMap = {for (var m in members) m.userId: m};

    // 贪心算法：每次选择最大的债务人和债权人进行结算
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // 找到最大债务人
      final maxDebtor = debtors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      // 找到最大债权人
      final maxCreditor = creditors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      final settleAmount =
          maxDebtor.value < maxCreditor.value
              ? maxDebtor.value
              : maxCreditor.value;

      settlements.add(SimplifiedSettlement(
        fromMemberId: maxDebtor.key,
        fromMemberName: memberMap[maxDebtor.key]?.displayName ?? 'Unknown',
        toMemberId: maxCreditor.key,
        toMemberName: memberMap[maxCreditor.key]?.displayName ?? 'Unknown',
        amount: settleAmount,
      ));

      // 更新余额
      debtors[maxDebtor.key] = maxDebtor.value - settleAmount;
      creditors[maxCreditor.key] = maxCreditor.value - settleAmount;

      // 移除已结清的
      if (debtors[maxDebtor.key]! < 0.01) {
        debtors.remove(maxDebtor.key);
      }
      if (creditors[maxCreditor.key]! < 0.01) {
        creditors.remove(maxCreditor.key);
      }
    }

    return settlements;
  }

  /// 清空数据（测试用）
  void clearAll() {
    _transactions.clear();
    _settlements.clear();
  }
}

/// 简化结算建议
class SimplifiedSettlement {
  /// 付款人ID
  final String fromMemberId;
  /// 付款人名称
  final String fromMemberName;
  /// 收款人ID
  final String toMemberId;
  /// 收款人名称
  final String toMemberName;
  /// 结算金额
  final double amount;

  const SimplifiedSettlement({
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
  });

  @override
  String toString() {
    return '$fromMemberName 需向 $toMemberName 支付 ¥${amount.toStringAsFixed(2)}';
  }
}
