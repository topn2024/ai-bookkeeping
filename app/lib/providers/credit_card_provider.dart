import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_card.dart';
import 'base/crud_notifier.dart';

/// 信用卡管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class CreditCardNotifier extends SimpleCrudNotifier<CreditCard, String> {
  @override
  String get tableName => 'credit_cards';

  @override
  String getId(CreditCard entity) => entity.id;

  @override
  Future<List<CreditCard>> fetchAll() => db.getCreditCards();

  @override
  Future<void> insertOne(CreditCard entity) => db.insertCreditCard(entity);

  @override
  Future<void> updateOne(CreditCard entity) => db.updateCreditCard(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteCreditCard(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加信用卡（保持原有方法名兼容）
  Future<void> addCreditCard(CreditCard card) => add(card);

  /// 更新信用卡（保持原有方法名兼容）
  Future<void> updateCreditCard(CreditCard card) => update(card);

  /// 删除信用卡（保持原有方法名兼容）
  Future<void> deleteCreditCard(String id) => delete(id);

  /// 切换信用卡启用状态
  Future<void> toggleCreditCard(String id) async {
    final card = getById(id);
    if (card == null) return;
    final updated = card.copyWith(isEnabled: !card.isEnabled);
    await update(updated);
  }

  /// 更新已用额度
  Future<void> updateUsedAmount(String id, double amount) async {
    final card = getById(id);
    if (card == null) return;
    final updated = card.copyWith(usedAmount: card.usedAmount + amount);
    await updateCreditCard(updated);
  }

  /// 还款
  Future<void> makePayment(String id, double amount) async {
    final card = getById(id);
    if (card == null) return;
    final newUsedAmount = (card.usedAmount - amount).clamp(0.0, card.creditLimit);
    final updated = card.copyWith(usedAmount: newUsedAmount);
    await updateCreditCard(updated);
  }

  /// 获取启用的信用卡
  List<CreditCard> get enabledCards => state.where((c) => c.isEnabled).toList();

  /// 获取即将还款的信用卡
  List<CreditCard> get cardsDueSoon =>
      state.where((c) => c.isEnabled && c.isPaymentDueSoon).toList();

  /// 获取已逾期的信用卡
  List<CreditCard> get overdueCards =>
      state.where((c) => c.isEnabled && c.isOverdue).toList();

  /// 获取额度紧张的信用卡
  List<CreditCard> get cardsNearLimit =>
      state.where((c) => c.isEnabled && c.isNearLimit).toList();

  /// 总信用额度
  double get totalCreditLimit =>
      state.where((c) => c.isEnabled).fold(0.0, (sum, c) => sum + c.creditLimit);

  /// 总已用额度
  double get totalUsedAmount =>
      state.where((c) => c.isEnabled).fold(0.0, (sum, c) => sum + c.usedAmount);

  /// 总可用额度
  double get totalAvailableCredit => totalCreditLimit - totalUsedAmount;

  @override
  CreditCard? getById(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}

final creditCardProvider =
    NotifierProvider<CreditCardNotifier, List<CreditCard>>(
        CreditCardNotifier.new);

/// 即将还款的信用卡
final cardsDueSoonProvider = Provider<List<CreditCard>>((ref) {
  final notifier = ref.watch(creditCardProvider.notifier);
  return notifier.cardsDueSoon;
});

/// 已逾期的信用卡
final overdueCardsProvider = Provider<List<CreditCard>>((ref) {
  final notifier = ref.watch(creditCardProvider.notifier);
  return notifier.overdueCards;
});

/// 信用卡汇总信息
class CreditCardSummary {
  final double totalLimit;
  final double totalUsed;
  final double totalAvailable;
  final int cardCount;
  final int dueSoonCount;
  final int overdueCount;

  CreditCardSummary({
    required this.totalLimit,
    required this.totalUsed,
    required this.totalAvailable,
    required this.cardCount,
    required this.dueSoonCount,
    required this.overdueCount,
  });

  double get usageRate => totalLimit > 0 ? totalUsed / totalLimit : 0;
}

final creditCardSummaryProvider = Provider<CreditCardSummary>((ref) {
  final cards = ref.watch(creditCardProvider);
  final enabledCards = cards.where((c) => c.isEnabled).toList();

  return CreditCardSummary(
    totalLimit: enabledCards.fold(0.0, (sum, c) => sum + c.creditLimit),
    totalUsed: enabledCards.fold(0.0, (sum, c) => sum + c.usedAmount),
    totalAvailable: enabledCards.fold(0.0, (sum, c) => sum + c.availableCredit),
    cardCount: enabledCards.length,
    dueSoonCount: enabledCards.where((c) => c.isPaymentDueSoon).length,
    overdueCount: enabledCards.where((c) => c.isOverdue).length,
  );
});
