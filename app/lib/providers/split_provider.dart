import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_split.dart';
import '../models/member.dart';
import '../services/split_service.dart';

/// SplitService Provider
final splitServiceProvider = Provider<SplitService>((ref) {
  return SplitService();
});

/// 分摊交易列表状态
class SplitTransactionListState {
  final List<SplitTransaction> transactions;
  final bool isLoading;
  final String? error;
  final String? ledgerId;

  const SplitTransactionListState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.ledgerId,
  });

  SplitTransactionListState copyWith({
    List<SplitTransaction>? transactions,
    bool? isLoading,
    String? error,
    String? ledgerId,
  }) {
    return SplitTransactionListState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      ledgerId: ledgerId ?? this.ledgerId,
    );
  }
}

/// 分摊交易列表 Notifier
class SplitTransactionListNotifier extends Notifier<SplitTransactionListState> {
  @override
  SplitTransactionListState build() {
    return const SplitTransactionListState();
  }

  SplitService get _splitService => ref.read(splitServiceProvider);

  /// 加载账本的分摊交易
  Future<void> loadSplitTransactions(String ledgerId,
      {SplitStatus? status}) async {
    state = state.copyWith(isLoading: true, ledgerId: ledgerId);
    try {
      final transactions = await _splitService.getSplitTransactionsByLedger(
        ledgerId,
        status: status,
      );
      state = state.copyWith(
        transactions: transactions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 创建分摊交易
  Future<SplitTransaction?> createSplitTransaction({
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
    try {
      final transaction = await _splitService.createSplitTransaction(
        ledgerId: ledgerId,
        totalAmount: totalAmount,
        categoryId: categoryId,
        description: description,
        splitType: splitType,
        participantIds: participantIds,
        members: members,
        currentUserId: currentUserId,
        payerId: payerId,
        exactAmounts: exactAmounts,
        shares: shares,
        percentages: percentages,
        transactionDate: transactionDate,
        location: location,
        tags: tags,
        attachments: attachments,
      );

      // 刷新列表
      if (state.ledgerId == ledgerId) {
        state = state.copyWith(
          transactions: [transaction, ...state.transactions],
        );
      }

      return transaction;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 确认分摊
  Future<bool> confirmSplit(String transactionId, String memberId,
      {String? note}) async {
    try {
      final updated = await _splitService.confirmSplit(
        transactionId,
        memberId,
        note: note,
      );

      if (updated != null) {
        final updatedList = state.transactions.map((t) {
          return t.id == transactionId ? updated : t;
        }).toList();
        state = state.copyWith(transactions: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 取消分摊
  Future<bool> cancelSplit(String transactionId) async {
    try {
      final updated = await _splitService.cancelSplit(transactionId);
      if (updated != null) {
        final updatedList = state.transactions.map((t) {
          return t.id == transactionId ? updated : t;
        }).toList();
        state = state.copyWith(transactions: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 分摊交易列表 Provider
final splitTransactionListProvider =
    NotifierProvider<SplitTransactionListNotifier, SplitTransactionListState>(
        SplitTransactionListNotifier.new);

/// 成员待处理分摊状态
class MemberPendingSplitsState {
  final List<SplitTransaction> pendingSplits;
  final List<SplitTransaction> pendingCollections;
  final bool isLoading;
  final String? error;

  const MemberPendingSplitsState({
    this.pendingSplits = const [],
    this.pendingCollections = const [],
    this.isLoading = false,
    this.error,
  });

  /// 待支付总额（我欠别人的）
  double get totalPending {
    double total = 0;
    for (final split in pendingSplits) {
      for (final p in split.splitInfo.participants) {
        if (!p.isPayer && !p.isSettled) {
          total += p.amount;
        }
      }
    }
    return total;
  }

  /// 待收款总额（别人欠我的）
  double get totalToCollect {
    double total = 0;
    for (final split in pendingCollections) {
      total += split.pendingAmount;
    }
    return total;
  }

  MemberPendingSplitsState copyWith({
    List<SplitTransaction>? pendingSplits,
    List<SplitTransaction>? pendingCollections,
    bool? isLoading,
    String? error,
  }) {
    return MemberPendingSplitsState(
      pendingSplits: pendingSplits ?? this.pendingSplits,
      pendingCollections: pendingCollections ?? this.pendingCollections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 成员待处理分摊 Notifier
class MemberPendingSplitsNotifier extends Notifier<MemberPendingSplitsState> {
  @override
  MemberPendingSplitsState build() {
    return const MemberPendingSplitsState();
  }

  SplitService get _splitService => ref.read(splitServiceProvider);

  /// 加载成员待处理的分摊
  Future<void> loadPendingSplits(String memberId, {String? ledgerId}) async {
    state = state.copyWith(isLoading: true);
    try {
      final pendingSplits = await _splitService.getPendingSplitsForMember(
        memberId,
        ledgerId: ledgerId,
      );
      final pendingCollections =
          await _splitService.getPendingCollectionsForMember(
        memberId,
        ledgerId: ledgerId,
      );
      state = state.copyWith(
        pendingSplits: pendingSplits,
        pendingCollections: pendingCollections,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// 成员待处理分摊 Provider
final memberPendingSplitsProvider =
    NotifierProvider<MemberPendingSplitsNotifier, MemberPendingSplitsState>(
        MemberPendingSplitsNotifier.new);

/// 成员余额状态
class MemberBalanceState {
  final MemberBalance? balance;
  final List<MemberBalance> allBalances;
  final bool isLoading;
  final String? error;

  const MemberBalanceState({
    this.balance,
    this.allBalances = const [],
    this.isLoading = false,
    this.error,
  });

  MemberBalanceState copyWith({
    MemberBalance? balance,
    List<MemberBalance>? allBalances,
    bool? isLoading,
    String? error,
  }) {
    return MemberBalanceState(
      balance: balance ?? this.balance,
      allBalances: allBalances ?? this.allBalances,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 成员余额 Notifier
class MemberBalanceNotifier extends Notifier<MemberBalanceState> {
  @override
  MemberBalanceState build() {
    return const MemberBalanceState();
  }

  SplitService get _splitService => ref.read(splitServiceProvider);

  /// 加载成员余额
  Future<void> loadMemberBalance(
    String memberId,
    String ledgerId,
    List<LedgerMember> members,
  ) async {
    state = state.copyWith(isLoading: true);
    try {
      final balance = await _splitService.calculateMemberBalance(
        memberId,
        ledgerId,
        members,
      );
      state = state.copyWith(balance: balance, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载所有成员余额
  Future<void> loadAllMemberBalances(
    String ledgerId,
    List<LedgerMember> members,
  ) async {
    state = state.copyWith(isLoading: true);
    try {
      final balances = await _splitService.calculateAllMemberBalances(
        ledgerId,
        members,
      );
      state = state.copyWith(allBalances: balances, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// 成员余额 Provider
final memberBalanceProvider =
    NotifierProvider<MemberBalanceNotifier, MemberBalanceState>(
        MemberBalanceNotifier.new);

/// 简化结算建议 Provider
final simplifiedSettlementsProvider =
    FutureProvider.family<List<SimplifiedSettlement>, SimplifySettlementParams>(
        (ref, params) async {
  final splitService = ref.watch(splitServiceProvider);
  return splitService.simplifySettlements(params.ledgerId, params.members);
});

/// 简化结算参数
class SimplifySettlementParams {
  final String ledgerId;
  final List<LedgerMember> members;

  const SimplifySettlementParams({
    required this.ledgerId,
    required this.members,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimplifySettlementParams &&
        other.ledgerId == ledgerId &&
        other.members.length == members.length;
  }

  @override
  int get hashCode => ledgerId.hashCode ^ members.length.hashCode;
}
