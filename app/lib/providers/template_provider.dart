import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/template.dart';
import 'base/crud_notifier.dart';
import 'transaction_provider.dart';

/// 交易模板管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class TemplateNotifier extends SimpleCrudNotifier<TransactionTemplate, String> {
  @override
  String get tableName => 'templates';

  @override
  String getId(TransactionTemplate entity) => entity.id;

  @override
  Future<List<TransactionTemplate>> fetchAll() async {
    final templates = await db.getTemplates();
    if (templates.isEmpty) {
      // Initialize with default templates
      for (final template in DefaultTemplates.templates) {
        await db.insertTemplate(template);
      }
      return DefaultTemplates.templates;
    }
    return templates;
  }

  @override
  Future<void> insertOne(TransactionTemplate entity) => db.insertTemplate(entity);

  @override
  Future<void> updateOne(TransactionTemplate entity) => db.updateTemplate(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteTemplate(id);

  // ==================== 兼容性方法（保留原有接口）====================

  Future<void> addTemplate(TransactionTemplate template) => add(template);
  Future<void> updateTemplate(TransactionTemplate template) => update(template);
  Future<void> deleteTemplate(String id) => delete(id);
  TransactionTemplate? getTemplateById(String id) => getById(id);

  // ==================== 业务特有方法 ====================

  /// 使用模板（增加使用次数）
  Future<void> useTemplate(String id) async {
    await db.incrementTemplateUseCount(id);
    // Reload to get updated use count
    await refresh();
  }

  /// 获取常用模板
  List<TransactionTemplate> getFrequentlyUsed({int limit = 6}) {
    final sorted = List<TransactionTemplate>.from(state)
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
    return sorted.take(limit).toList();
  }

  /// 获取最近使用的模板
  List<TransactionTemplate> getRecentlyUsed({int limit = 6}) {
    final withLastUsed = state.where((t) => t.lastUsedAt != null).toList()
      ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return withLastUsed.take(limit).toList();
  }

  /// 按类型获取模板
  List<TransactionTemplate> getByType(String type) => where((t) => t.type.name == type);
}

final templateProvider =
    NotifierProvider<TemplateNotifier, List<TransactionTemplate>>(
        TemplateNotifier.new);

/// 使用模板创建交易的 Provider
final useTemplateProvider = Provider.family<Future<void> Function(double?), String>((ref, templateId) {
  return (double? amount) async {
    final templateNotifier = ref.read(templateProvider.notifier);
    final transactionNotifier = ref.read(transactionProvider.notifier);

    final template = templateNotifier.getById(templateId);
    if (template == null) return;

    final transaction = template.toTransaction(overrideAmount: amount);
    await transactionNotifier.addTransaction(transaction);
    await templateNotifier.useTemplate(templateId);
  };
});

/// 常用模板 Provider
final frequentTemplatesProvider = Provider<List<TransactionTemplate>>((ref) {
  ref.watch(templateProvider);
  return ref.read(templateProvider.notifier).getFrequentlyUsed();
});

/// 最近使用模板 Provider
final recentTemplatesProvider = Provider<List<TransactionTemplate>>((ref) {
  ref.watch(templateProvider);
  return ref.read(templateProvider.notifier).getRecentlyUsed();
});
