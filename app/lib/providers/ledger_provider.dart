import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ledger.dart';
import 'base/crud_notifier.dart';

/// 账本管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class LedgerNotifier extends SimpleCrudNotifier<Ledger, String> {
  String _currentLedgerId = 'default';

  @override
  String get tableName => 'ledgers';

  @override
  String getId(Ledger entity) => entity.id;

  @override
  Future<List<Ledger>> fetchAll() async {
    final ledgers = await db.getLedgers();
    if (ledgers.isEmpty) {
      // Initialize with default ledger
      await db.insertLedger(DefaultLedgers.defaultLedger);
      return [DefaultLedgers.defaultLedger];
    }
    return ledgers;
  }

  @override
  Future<void> insertOne(Ledger entity) => db.insertLedger(entity);

  @override
  Future<void> updateOne(Ledger entity) => db.updateLedger(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteLedger(id);

  // ==================== 兼容性方法（保留原有接口）====================

  Future<void> addLedger(Ledger ledger) => add(ledger);
  Future<void> updateLedger(Ledger ledger) => update(ledger);
  Ledger? getLedgerById(String id) => getById(id);

  // ==================== 业务特有方法 ====================

  String get currentLedgerId => _currentLedgerId;

  Ledger? get currentLedger => getById(_currentLedgerId);

  void setCurrentLedger(String id) {
    _currentLedgerId = id;
  }

  /// 删除账本（保留至少一个）
  Future<void> deleteLedger(String id) async {
    if (state.length <= 1) return;
    await delete(id);
    if (_currentLedgerId == id) {
      _currentLedgerId = state.first.id;
    }
  }

  /// 设置默认账本
  Future<void> setDefaultLedger(String id) async {
    for (final ledger in state) {
      final updated = ledger.copyWith(isDefault: ledger.id == id);
      await db.updateLedger(updated);
    }
    state = state.map((l) => l.copyWith(isDefault: l.id == id)).toList();
  }

  /// 获取默认账本
  Ledger? get defaultLedger => firstWhereOrNull((l) => l.isDefault);
}

final ledgerProvider =
    NotifierProvider<LedgerNotifier, List<Ledger>>(LedgerNotifier.new);

final currentLedgerProvider = Provider<Ledger?>((ref) {
  ref.watch(ledgerProvider); // 监听状态变化
  return ref.read(ledgerProvider.notifier).currentLedger;
});
