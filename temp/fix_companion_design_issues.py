# -*- coding: utf-8 -*-
"""
修复伙伴化设计原则相关问题
包括：第13章排行榜、通知控制、第29章措辞优化、分享时机等
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ============================================================
    # 修复1: 第13章 - 家庭排行榜改为贡献展示（非竞争性设计）
    # ============================================================
    old_leaderboard = '''/// 家庭排行榜
class FamilyLeaderboard {
  final String ledgerId;
  final String period;
  final List<LeaderboardEntry> savingsRanking;      // 储蓄排行
  final List<LeaderboardEntry> recordingRanking;    // 记账勤奋度
  final List<LeaderboardEntry> budgetCompliance;    // 预算遵守度
  final List<AchievementBadge> recentAchievements;  // 近期成就

  FamilyLeaderboard({
    required this.ledgerId,
    required this.period,
    required this.savingsRanking,
    required this.recordingRanking,
    required this.budgetCompliance,
    required this.recentAchievements,
  });
}

/// 排行榜条目
class LeaderboardEntry {
  final int rank;
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double value;
  final String valueLabel;        // 如 "¥3,200" 或 "98%"
  final int? changeFromLastPeriod;  // 排名变化

  LeaderboardEntry({
    required this.rank,
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.value,
    required this.valueLabel,
    this.changeFromLastPeriod,
  });
}'''

    new_leaderboard = '''/// 【伙伴化设计】家庭贡献展示（非竞争性设计）
/// 设计原则：展示团队成就而非个人排名，避免家庭成员间产生焦虑
/// 参考第4章4.6.1节"不对比用户与他人的消费"原则
class FamilyContributionDisplay {
  final String ledgerId;
  final String period;
  final FamilyTeamStats teamStats;              // 团队整体数据
  final List<MemberContribution> contributions; // 成员贡献（不排名）
  final List<AchievementBadge> recentAchievements;  // 近期成就
  final String encouragementMessage;            // 伙伴化鼓励语

  FamilyContributionDisplay({
    required this.ledgerId,
    required this.period,
    required this.teamStats,
    required this.contributions,
    required this.recentAchievements,
    required this.encouragementMessage,
  });
}

/// 团队整体统计（强调集体成就）
class FamilyTeamStats {
  final double totalSavings;        // 家庭总储蓄
  final int totalRecordDays;        // 家庭累计记账天数
  final double budgetComplianceRate; // 家庭预算达成率
  final int goalsAchieved;          // 已达成目标数

  FamilyTeamStats({
    required this.totalSavings,
    required this.totalRecordDays,
    required this.budgetComplianceRate,
    required this.goalsAchieved,
  });

  /// 生成团队鼓励文案
  String generateEncouragement() {
    if (budgetComplianceRate >= 0.9) {
      return '太棒了！全家一起守住了预算 🎉';
    } else if (goalsAchieved > 0) {
      return '恭喜！又一个家庭目标达成了 ✨';
    } else {
      return '一家人齐心协力，财务越来越健康 💪';
    }
  }
}

/// 成员贡献展示（无排名，平等展示）
class MemberContribution {
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double contributionValue;
  final String contributionLabel;   // 如 "本月记录了32笔"
  final String? personalHighlight;  // 个人亮点，如 "连续记账7天"
  final String appreciationNote;    // 感谢语，如 "感谢你的坚持！"

  MemberContribution({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.contributionValue,
    required this.contributionLabel,
    this.personalHighlight,
    required this.appreciationNote,
  });
}

/// 【伙伴化设计】贡献展示服务
class FamilyContributionService {
  /// 生成成员感谢语（每个成员都有独特的正面评价）
  static String generateAppreciation(MemberStats stats) {
    if (stats.recordDays >= 20) {
      return '记账小达人，坚持就是胜利！';
    } else if (stats.savingsContribution > 0) {
      return '为家庭储蓄贡献了力量 💰';
    } else if (stats.isNewMember) {
      return '欢迎加入！一起加油吧 🌟';
    } else {
      return '感谢你的参与！';
    }
  }

  /// 生成个人亮点（找出每个人的闪光点）
  static String? findPersonalHighlight(MemberStats stats) {
    if (stats.streakDays >= 7) {
      return '连续记账${stats.streakDays}天';
    } else if (stats.budgetCompliance >= 0.95) {
      return '预算控制很棒';
    } else if (stats.categoriesUsed >= 5) {
      return '记账很细致';
    }
    return null;
  }
}'''

    if old_leaderboard in content:
        content = content.replace(old_leaderboard, new_leaderboard)
        print("✓ 修复1: 第13章家庭排行榜改为贡献展示")
        changes += 1

    # ============================================================
    # 修复2: 第13章 - 家庭通知接入全局控制器
    # ============================================================
    old_goal_notify = '''    // 通知所有成员
    final ledger = await _ledgerService.getLedger(ledgerId);
    for (final member in ledger.members) {
      await _notificationService.send(
        member.userId,
        NotificationType.goalCreated,
        {'goalName': name, 'targetAmount': targetAmount},
      );
    }'''

    new_goal_notify = '''    // 【伙伴化设计】通过全局通知控制器发送，避免通知轰炸
    // 参考第28.7节 GlobalNotificationController
    final ledger = await _ledgerService.getLedger(ledgerId);
    for (final member in ledger.members) {
      // 使用全局控制器，确保不超过每日通知上限
      await GlobalNotificationController.requestNotification(
        userId: member.userId,
        type: NotificationType.familyActivity,
        payload: {
          'subType': 'goalCreated',
          'goalName': name,
          'targetAmount': targetAmount,
          'message': '${AuthService().currentUserName}创建了新目标「$name」，一起努力吧！',
        },
      );
    }'''

    if old_goal_notify in content:
        content = content.replace(old_goal_notify, new_goal_notify)
        print("✓ 修复2: 第13章家庭通知接入全局控制器")
        changes += 1

    # ============================================================
    # 修复3: 第29章 - 社交对比措辞温和化
    # ============================================================
    old_comparison = '''    return ComparisonResult(
      highlights: [
        ComparisonItem(
          metric: '钱龄',
          userValue: '${userStats.moneyAge}天',
          peerAverage: '${peerStats.avgMoneyAge}天',
          percentile: _calculatePercentile(userStats.moneyAge, peerStats.moneyAgeDistribution),
          message: '你的钱龄超过了${percentile}%的同龄人',
        ),
      ],
      shareCard: await _generateComparisonCard(userStats, peerStats),
    );'''

    new_comparison = '''    // 【伙伴化设计】使用温和的正向表述，避免炫耀或焦虑
    // 参考第4章4.6.1节"不对比用户与他人的消费"原则
    final percentile = _calculatePercentile(userStats.moneyAge, peerStats.moneyAgeDistribution);

    // 根据用户表现生成温和的鼓励语
    String message;
    if (percentile >= 80) {
      message = '你的财务习惯很健康，继续保持！✨';
    } else if (percentile >= 50) {
      message = '财务管理稳步提升中，加油！💪';
    } else {
      // 对于低于平均的用户，完全不提及对比，只鼓励
      message = '每一步都是进步，我们一起努力！🌱';
    }

    return ComparisonResult(
      highlights: [
        ComparisonItem(
          metric: '钱龄',
          userValue: '${userStats.moneyAge}天',
          peerAverage: '${peerStats.avgMoneyAge}天',
          percentile: percentile,
          message: message,  // 使用温和的鼓励语
        ),
      ],
      shareCard: await _generateComparisonCard(userStats, peerStats),
    );'''

    if old_comparison in content:
        content = content.replace(old_comparison, new_comparison)
        print("✓ 修复3: 第29章社交对比措辞温和化")
        changes += 1

    # ============================================================
    # 修复4: 第29章 - 裂变引导文案伙伴化
    # ============================================================
    old_viral_path = '''  /// 裂变路径设计
  static const viralPath = FamilyViralPath(
    // 创建时引导
    onCreation: ViralStep(
      message: '家庭账本创建成功！邀请家人一起记账吧','''

    new_viral_path = '''  /// 【伙伴化设计】裂变路径设计 - 温暖友善的引导语
  /// 参考第4章伙伴化文案设计原则
  static const viralPath = FamilyViralPath(
    // 创建时引导 - 使用温暖的伙伴语气
    onCreation: ViralStep(
      message: '太好了，家庭账本准备好了！🏠 要不要邀请家人一起管理财务呀？','''

    if old_viral_path in content:
        content = content.replace(old_viral_path, new_viral_path)
        print("✓ 修复4a: 第29章家庭账本创建引导文案伙伴化")
        changes += 1

    # 修复更多裂变文案
    old_viral_messages = [
        ("message: '记录了第一笔家庭支出！邀请家人一起查看？'",
         "message: '第一笔家庭账记好啦！📝 分享给家人看看？一起管钱更有动力哦~'"),
        ("message: '家庭预算设置好了，让其他成员也参与预算管理吧'",
         "message: '预算计划制定完成！✨ 邀请家人一起参与，大家都有数才能一起省~'"),
        ("message: '本月家庭财务报告已生成，分享给家人看看？'",
         "message: '这个月的家庭财务报告出炉啦！📊 要不要和家人一起看看成果？'"),
        ("message: '这笔账需要{partnerName}也记录吗？'",
         "message: '这笔账{partnerName}也要记一下吗？一起记更清楚哦~ 💑'"),
    ]

    for old_msg, new_msg in old_viral_messages:
        if old_msg in content:
            content = content.replace(old_msg, new_msg)
            print(f"✓ 修复4: 裂变文案伙伴化 - {old_msg[:30]}...")
            changes += 1

    # ============================================================
    # 修复5: 第28/29章 - 分享时机优化（先庆祝，后分享）
    # ============================================================
    old_growth_trigger = '''    // 成就解锁时
    GrowthTrigger(
      event: 'achievement_unlocked',
      action: '展示分享入口，一键生成成就卡片',
      expectedConversion: 0.15,  // 15%用户会分享
    ),'''

    new_growth_trigger = '''    // 【伙伴化设计】成就解锁时 - 先庆祝3秒，再温和引导分享
    // 参考第4章"鼓励而非说教"原则
    GrowthTrigger(
      event: 'achievement_unlocked',
      action: '先展示庆祝动画3秒，然后以次要选项展示分享入口',
      celebrationFirst: true,        // 庆祝优先
      celebrationDuration: 3000,     // 庆祝动画持续3秒
      shareButtonStyle: 'secondary', // 分享按钮为次要样式
      dismissOption: '下次再分享',    // 提供稍后选项
      expectedConversion: 0.15,
    ),'''

    if old_growth_trigger in content:
        content = content.replace(old_growth_trigger, new_growth_trigger)
        print("✓ 修复5: 第28/29章分享时机优化（庆祝优先）")
        changes += 1

    # ============================================================
    # 修复6: 第13章 - 角色变更情感化通知
    # ============================================================
    # 在成员管理服务后添加角色变更通知设计
    old_member_role = '''/// 成员角色
/// 【懒人设计】简化为3种常用角色，满足99%场景
/// 高级权限自定义仅在「设置-高级」中提供
enum MemberRole {
  owner,    // 所有者：全部权限（账本创建者自动获得）
  member,   // 成员：记账、查看、编辑自己的账目（默认角色）
  viewer,   // 查看者：仅查看（适合孩子或临时成员）
  // admin角色已合并到owner，减少用户选择困难
}'''

    new_member_role = '''/// 成员角色
/// 【懒人设计】简化为3种常用角色，满足99%场景
/// 高级权限自定义仅在「设置-高级」中提供
enum MemberRole {
  owner,    // 所有者：全部权限（账本创建者自动获得）
  member,   // 成员：记账、查看、编辑自己的账目（默认角色）
  viewer,   // 查看者：仅查看（适合孩子或临时成员）
  // admin角色已合并到owner，减少用户选择困难
}

/// 【伙伴化设计】角色变更通知服务
/// 参考第4章"宽容"和"尊重用户"原则
class RoleChangeNotificationService {
  /// 生成温和的角色变更通知（避免让用户感到被"降级"）
  static NotificationContent generateRoleChangeNotification({
    required MemberRole oldRole,
    required MemberRole newRole,
    required String ledgerName,
  }) {
    // 角色提升 - 表达信任
    if (_getRoleLevel(newRole) > _getRoleLevel(oldRole)) {
      return NotificationContent(
        title: '账本权限更新',
        body: '你在「$ledgerName」的权限有了提升，感谢你的付出！✨',
        mood: CompanionMood.happy,
      );
    }

    // 角色调整 - 温和表达，不使用"降级"等负面词汇
    return NotificationContent(
      title: '账本设置有变化',
      body: '「$ledgerName」的管理方式做了调整，有任何问题随时问我哦 😊',
      mood: CompanionMood.gentle,
      // 不详细说明权限减少，避免负面感受
    );
  }

  static int _getRoleLevel(MemberRole role) {
    switch (role) {
      case MemberRole.owner: return 3;
      case MemberRole.member: return 2;
      case MemberRole.viewer: return 1;
    }
  }
}'''

    if old_member_role in content:
        content = content.replace(old_member_role, new_member_role)
        print("✓ 修复6: 第13章角色变更情感化通知")
        changes += 1

    # ============================================================
    # 修复7: 第13章 - 添加与全局通知控制器的对接说明
    # ============================================================
    # 在13.9与其他系统的集成部分添加说明
    old_integration_section = '''### 13.9 与其他系统的集成'''

    new_integration_section = '''### 13.9 与其他系统的集成

#### 13.9.0 与全局通知控制器的对接

> 📎 **重要**：家庭账本的所有通知必须通过第28.7节的`GlobalNotificationController`发送，以确保：
> - 用户每日收到的通知不超过8条
> - 低优先级通知（如家庭动态）每天最多3条
> - 高优先级通知（如分摊请求）优先发送

```dart
/// 【伙伴化设计】家庭账本通知配置
class FamilyLedgerNotificationConfig {
  /// 家庭账本相关通知的优先级配置
  static const notificationPriorities = {
    'splitRequest': NotificationPriority.high,     // 分摊请求 - 高优先级
    'goalAchieved': NotificationPriority.medium,   // 目标达成 - 中优先级
    'memberJoined': NotificationPriority.medium,   // 成员加入 - 中优先级
    'goalCreated': NotificationPriority.low,       // 目标创建 - 低优先级
    'transactionAdded': NotificationPriority.low,  // 新交易 - 低优先级
    'monthlyReport': NotificationPriority.low,     // 月度报告 - 低优先级
  };

  /// 家庭通知的伙伴化文案模板
  static const companionMessages = {
    'memberJoined': '{memberName}加入了家庭账本，大家一起欢迎ta吧！🎉',
    'goalAchieved': '太棒了！全家一起完成了「{goalName}」目标 🎊',
    'splitRequest': '{memberName}发起了一笔分摊，记得确认哦~',
  };
}
```'''

    if old_integration_section in content:
        content = content.replace(old_integration_section, new_integration_section)
        print("✓ 修复7: 第13章添加与全局通知控制器的对接说明")
        changes += 1

    # ============================================================
    # 保存修改
    # ============================================================
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 伙伴化设计修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到需要修复的内容，可能已经修复过")

    return changes

if __name__ == '__main__':
    main()
