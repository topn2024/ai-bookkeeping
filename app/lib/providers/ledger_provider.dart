import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ledger.dart';
import '../services/database_service.dart';

class LedgerNotifier extends Notifier<List<Ledger>> {
  final DatabaseService _db = DatabaseService();
  String _currentLedgerId = 'default';

  @override
  List<Ledger> build() {
    _loadLedgers();
    return [];
  }

  String get currentLedgerId => _currentLedgerId;

  Future<void> _loadLedgers() async {
    final ledgers = await _db.getLedgers();
    if (ledgers.isEmpty) {
      // Initialize with default ledger
      await _db.insertLedger(DefaultLedgers.defaultLedger);
      state = [DefaultLedgers.defaultLedger];
    } else {
      state = ledgers;
    }
  }

  Future<void> addLedger(Ledger ledger) async {
    await _db.insertLedger(ledger);
    state = [...state, ledger];
  }

  Future<void> updateLedger(Ledger ledger) async {
    await _db.updateLedger(ledger);
    state = state.map((l) => l.id == ledger.id ? ledger : l).toList();
  }

  Future<void> deleteLedger(String id) async {
    if (state.length <= 1) return;
    await _db.deleteLedger(id);
    state = state.where((l) => l.id != id).toList();
    if (_currentLedgerId == id) {
      _currentLedgerId = state.first.id;
    }
  }

  Future<void> setDefaultLedger(String id) async {
    for (final ledger in state) {
      final updated = ledger.copyWith(isDefault: ledger.id == id);
      await _db.updateLedger(updated);
    }
    state = state.map((l) => l.copyWith(isDefault: l.id == id)).toList();
  }

  void setCurrentLedger(String id) {
    _currentLedgerId = id;
  }

  Ledger? getLedgerById(String id) {
    try {
      return state.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  Ledger? get currentLedger => getLedgerById(_currentLedgerId);
}

final ledgerProvider =
    NotifierProvider<LedgerNotifier, List<Ledger>>(LedgerNotifier.new);

final currentLedgerProvider = Provider<Ledger?>((ref) {
  return ref.watch(ledgerProvider.notifier).currentLedger;
});
