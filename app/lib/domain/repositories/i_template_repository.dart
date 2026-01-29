/// Template Repository Interface
///
/// 定义交易模板实体的仓库接口
library;

import '../../models/template.dart';
import 'i_repository.dart';

/// 模板仓库接口
abstract class ITemplateRepository extends IRepository<TransactionTemplate, String> {
  /// 按分类查询模板
  Future<List<TransactionTemplate>> findByCategory(String category);

  /// 按类型查询模板（支出/收入/转账）
  Future<List<TransactionTemplate>> findByType(String type);

  /// 获取常用模板（按使用频率排序）
  Future<List<TransactionTemplate>> findFrequentlyUsed({int limit = 10});

  /// 按关键词搜索模板
  Future<List<TransactionTemplate>> search(String keyword);

  /// 增加模板使用次数
  Future<void> incrementUsageCount(String templateId);

  /// 获取指定账本的模板
  Future<List<TransactionTemplate>> findByLedger(String ledgerId);

  /// 获取所有启用的模板
  Future<List<TransactionTemplate>> findEnabled();
}
