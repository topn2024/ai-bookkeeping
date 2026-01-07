# -*- coding: utf-8 -*-
"""
修复懒人设计原则相关问题
包括：第13章权限简化、第28章NPS优化、第29章裂变频率控制、跨章节通知统一
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ============================================================
    # 修复1: 第13章 - 简化权限系统，添加预设角色说明
    # ============================================================
    old_permission_text = '''/// 成员角色
enum MemberRole {
  owner,    // 所有者：全部权限
  admin,    // 管理员：除删除账本外的全部权限
  member,   // 成员：记账、查看
  viewer,   // 查看者：仅查看
}'''

    new_permission_text = '''/// 成员角色
/// 【懒人设计】简化为3种常用角色，满足99%场景
/// 高级权限自定义仅在「设置-高级」中提供
enum MemberRole {
  owner,    // 所有者：全部权限（账本创建者自动获得）
  member,   // 成员：记账、查看、编辑自己的账目（默认角色）
  viewer,   // 查看者：仅查看（适合孩子或临时成员）
  // admin角色已合并到owner，减少用户选择困难
}

/// 【懒人设计】预设角色模板 - 一键应用
class RolePresets {
  /// 家庭账本默认角色分配
  static const familyDefaults = {
    'spouse': MemberRole.member,      // 配偶默认为成员
    'parent': MemberRole.member,      // 父母默认为成员
    'child': MemberRole.viewer,       // 孩子默认为查看者
  };

  /// 智能角色推荐（基于邀请关系）
  static MemberRole recommendRole(String relationship) {
    return familyDefaults[relationship] ?? MemberRole.member;
  }
}'''

    if old_permission_text in content:
        content = content.replace(old_permission_text, new_permission_text)
        print("✓ 已简化第13章权限系统")
        changes += 1

    # ============================================================
    # 修复2: 第13章 - 添加智能预算分配建议
    # ============================================================
    old_budget_text = '''/// 家庭预算分配策略
enum FamilyBudgetStrategy {
  unified,      // 统一预算：家庭共用一个预算池
  perMember,    // 成员配额：每个成员有独立配额
  perCategory,  // 分类负责：不同成员负责不同分类
  hybrid,       // 混合模式：部分统一+部分独立
}'''

    new_budget_text = '''/// 家庭预算分配策略
/// 【懒人设计】默认使用unified模式，其他模式在「高级设置」中
enum FamilyBudgetStrategy {
  unified,      // 统一预算：家庭共用一个预算池（默认，最简单）
  perMember,    // 成员配额：每个成员有独立配额（高级）
  perCategory,  // 分类负责：不同成员负责不同分类（高级）
  hybrid,       // 混合模式：部分统一+部分独立（高级）
}

/// 【懒人设计】智能预算分配建议服务
class SmartBudgetAllocationService {
  /// 一键智能分配 - 基于历史消费自动建议
  Future<Map<String, double>> suggestMemberAllocations({
    required String ledgerId,
    required double totalBudget,
  }) async {
    final members = await _getMemberConsumptionHistory(ledgerId);
    final suggestions = <String, double>{};

    // 基于过去3个月消费比例计算建议配额
    final totalSpent = members.values.fold(0.0, (sum, m) => sum + m.avgMonthlySpent);

    for (final entry in members.entries) {
      final ratio = totalSpent > 0 ? entry.value.avgMonthlySpent / totalSpent : 1.0 / members.length;
      suggestions[entry.key] = (totalBudget * ratio).roundToDouble();
    }

    return suggestions;
  }

  /// 生成分配建议说明
  String generateSuggestionExplanation(Map<String, double> suggestions) {
    return '根据过去3个月的消费记录，我们建议：\\n' +
        suggestions.entries.map((e) => '• ${e.key}: ¥${e.value.toStringAsFixed(0)}').join('\\n');
  }
}'''

    if old_budget_text in content:
        content = content.replace(old_budget_text, new_budget_text)
        print("✓ 已添加第13章智能预算分配建议")
        changes += 1

    # ============================================================
    # 修复3: 第13章 - 分摊策略默认值优化
    # ============================================================
    old_split_text = '''/// AA分摊服务
class SplitService {'''

    new_split_text = '''/// 【懒人设计】分摊策略
/// 默认使用「均摊」，其他策略在「更多选项」中
enum SplitStrategy {
  equal,        // 均摊（默认） - 最常用，一键完成
  byRatio,      // 按比例 - 需设置比例
  custom,       // 自定义 - 完全自由设置
}

/// AA分摊服务
class SplitService {
  /// 【懒人设计】默认分摊策略
  static const defaultStrategy = SplitStrategy.equal;

  /// 【懒人设计】智能推荐分摊对象（基于历史）
  Future<List<String>> suggestSplitParticipants(String category) async {
    // 基于该分类的历史分摊记录推荐参与者
    final history = await _getSplitHistory(category);
    return history.mostFrequentParticipants.take(3).toList();
  }'''

    if old_split_text in content:
        content = content.replace(old_split_text, new_split_text)
        print("✓ 已优化第13章分摊策略默认值")
        changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n第一批修复完成，共 {changes} 处")
    else:
        print("\n第一批修复：未找到目标位置或已修复")

    return changes

if __name__ == '__main__':
    main()
