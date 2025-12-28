import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/template.dart';
import '../services/database_service.dart';
import 'transaction_provider.dart';

class TemplateNotifier extends Notifier<List<TransactionTemplate>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<TransactionTemplate> build() {
    _loadTemplates();
    return [];
  }

  Future<void> _loadTemplates() async {
    final templates = await _db.getTemplates();
    if (templates.isEmpty) {
      // Initialize with default templates
      for (final template in DefaultTemplates.templates) {
        await _db.insertTemplate(template);
      }
      state = DefaultTemplates.templates;
    } else {
      state = templates;
    }
  }

  Future<void> addTemplate(TransactionTemplate template) async {
    await _db.insertTemplate(template);
    state = [...state, template];
  }

  Future<void> updateTemplate(TransactionTemplate template) async {
    await _db.updateTemplate(template);
    state = state.map((t) => t.id == template.id ? template : t).toList();
  }

  Future<void> deleteTemplate(String id) async {
    await _db.deleteTemplate(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> useTemplate(String id) async {
    await _db.incrementTemplateUseCount(id);
    // Reload to get updated use count
    final templates = await _db.getTemplates();
    state = templates;
  }

  TransactionTemplate? getTemplateById(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  List<TransactionTemplate> getFrequentlyUsed({int limit = 6}) {
    final sorted = List<TransactionTemplate>.from(state)
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
    return sorted.take(limit).toList();
  }

  List<TransactionTemplate> getRecentlyUsed({int limit = 6}) {
    final withLastUsed = state.where((t) => t.lastUsedAt != null).toList()
      ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return withLastUsed.take(limit).toList();
  }
}

final templateProvider =
    NotifierProvider<TemplateNotifier, List<TransactionTemplate>>(
        TemplateNotifier.new);

// Provider for using a template to create a transaction
final useTemplateProvider = Provider.family<Future<void> Function(double?), String>((ref, templateId) {
  return (double? amount) async {
    final templateNotifier = ref.read(templateProvider.notifier);
    final transactionNotifier = ref.read(transactionProvider.notifier);

    final template = templateNotifier.getTemplateById(templateId);
    if (template == null) return;

    final transaction = template.toTransaction(overrideAmount: amount);
    await transactionNotifier.addTransaction(transaction);
    await templateNotifier.useTemplate(templateId);
  };
});
