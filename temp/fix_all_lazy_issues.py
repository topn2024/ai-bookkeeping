# -*- coding: utf-8 -*-
"""
修复所有懒人设计原则相关问题
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ============================================================
    # 修复1: 第13章 - 分摊默认配置与智能推荐
    # ============================================================
    old_split = '''enum SplitStatus {
  pending,      // 待确认
  confirmed,    // 已确认
  settling,     // 结算中
  settled,      // 已结算
}

/// 分摊服务
class SplitService {'''

    new_split = '''enum SplitStatus {
  pending,      // 待确认
  confirmed,    // 已确认
  settling,     // 结算中
  settled,      // 已结算
}

/// 【懒人设计】分摊默认配置与智能推荐
class SplitDefaults {
  /// 默认使用均摊 - 最简单，一键完成
  static const defaultSplitType = SplitType.equal;

  /// 智能推荐分摊参与者（基于历史记录）
  static Future<List<String>> suggestParticipants({
    required String ledgerId,
    required String categoryId,
  }) async {
    final history = await _getRecentSplitHistory(ledgerId, categoryId);
    final frequency = <String, int>{};
    for (final split in history) {
      for (final p in split.participantIds) {
        frequency[p] = (frequency[p] ?? 0) + 1;
      }
    }
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }
}

/// 分摊服务
class SplitService {'''

    if old_split in content and '【懒人设计】分摊默认配置' not in content:
        content = content.replace(old_split, new_split)
        print("✓ 修复1: 第13章分摊策略默认配置")
        changes += 1

    # ============================================================
    # 修复2: 第28章 - NPS问卷增强预设选项
    # ============================================================
    old_nps = '''// 推荐者：了解推荐动力
      reason = await _askOpenQuestion(
        question: '太棒了！是什么让您愿意推荐我们？',
        suggestions: ['钱龄分析很有用', '记账很方便', '预算管理帮助很大', '界面很好看'],
      );'''

    new_nps = '''// 推荐者：了解推荐动力
      // 【懒人设计】提供丰富的预设选项，减少用户输入
      reason = await _askOpenQuestion(
        question: '太棒了！是什么让您愿意推荐我们？',
        suggestions: [
          '钱龄分析让我知道钱花哪了',
          '语音记账太方便了',
          '预算管理帮我省了不少钱',
          '界面简洁好看',
          '记账习惯终于养成了',
          '家庭账本很实用',
        ],
        allowMultiple: true,  // 允许多选
        skipOption: '直接提交',  // 可跳过详细反馈
      );'''

    if old_nps in content:
        content = content.replace(old_nps, new_nps)
        print("✓ 修复2: 第28章NPS推荐者预设选项")
        changes += 1

    # 被动者预设选项
    old_passive = '''// 被动者：了解提升空间
      reason = await _askOpenQuestion(
        question: '感谢您的支持！我们还能做些什么让您更满意？',
      );'''

    new_passive = '''// 被动者：了解提升空间
      // 【懒人设计】提供常见改进方向选项
      reason = await _askOpenQuestion(
        question: '感谢您的支持！我们还能做些什么让您更满意？',
        suggestions: [
          '希望同步��快',
          '希望增加更多图表',
          '希望支持更多银行导入',
          '希望有桌面版',
          '目前挺好的',
        ],
        skipOption: '暂时没有建议',
      );'''

    if old_passive in content:
        content = content.replace(old_passive, new_passive)
        print("✓ 修复2: 第28章NPS被动者预设选项")
        changes += 1

    # 贬损者预设选项
    old_detractor = '''// 贬损者：了解问题所在
      reason = await _askOpenQuestion(
        question: '很抱歉没能让您满意，能告诉我们哪里需要改进吗？',
      );'''

    new_detractor = '''// 贬损者：了解问题所在
      // 【懒人设计】提供常见问题选项，降低反馈门槛
      reason = await _askOpenQuestion(
        question: '很抱歉没能让您满意，能告诉我们哪里需要改进吗？',
        suggestions: [
          '操作太复杂',
          '功能不够用',
          'App经常卡顿',
          '数据同步有问题',
          '界面不好看',
          '广告太多',  // 虽然我们没广告，但用户可能误解
        ],
        allowMultiple: true,
        requireSelection: true,  // 贬损者必须选择至少一项
      );'''

    if old_detractor in content:
        content = content.replace(old_detractor, new_detractor)
        print("✓ 修复2: 第28章NPS贬损者预设选项")
        changes += 1

    # ============================================================
    # 修复3: 第28章 - 记住用户分享平台偏好
    # ============================================================
    old_share = '''/// 触发惊喜时刻
  Future<void> triggerDelight(MilestoneDelight delight) async {
    // 1. 播放动画
    await _animationService.play(delight.animation);

    // 2. 显示祝贺消息
    await _showDelightCard(delight);

    // 3. 发放奖励
    if (delight.reward != null) {
      await _achievementService.award(delight.reward!);
    }

    // 4. 生成分享内容
    if (delight.shareCard) {
      await _prepareShareCard(delight);
    }

    // 5. 记录惊喜时刻
    await _logDelightMoment(delight);
  }'''

    new_share = '''/// 触发惊喜时刻
  Future<void> triggerDelight(MilestoneDelight delight) async {
    // 1. 播放动画
    await _animationService.play(delight.animation);

    // 2. 显示祝贺消息
    await _showDelightCard(delight);

    // 3. 发放奖励
    if (delight.reward != null) {
      await _achievementService.award(delight.reward!);
    }

    // 4. 生成分享内容
    if (delight.shareCard) {
      await _prepareShareCard(delight);
    }

    // 5. 记录惊喜时刻
    await _logDelightMoment(delight);
  }

  /// 【懒人设计】用户分享平台偏好记忆
  Future<void> shareWithPreference(ShareCard card) async {
    // 获取用户上次使用的平台
    final preferredPlatform = await _prefs.getString('last_share_platform');

    if (preferredPlatform != null) {
      // 一键分享到常用平台
      final confirmed = await _showQuickShareConfirm(
        platform: preferredPlatform,
        message: '分享到$preferredPlatform？',
      );
      if (confirmed) {
        await _shareToplatform(card, preferredPlatform);
        return;
      }
    }

    // 首次或用户想换平台时，显示平台选择
    final selectedPlatform = await _showPlatformPicker(card.platforms);
    if (selectedPlatform != null) {
      await _prefs.setString('last_share_platform', selectedPlatform);
      await _shareToplatform(card, selectedPlatform);
    }
  }'''

    if old_share in content and '用户分享平台偏好记忆' not in content:
        content = content.replace(old_share, new_share)
        print("✓ 修复3: 第28章分享平台偏好记忆")
        changes += 1

    # ============================================================
    # 修复4: 第29章 - 裂变引导频率控制
    # ============================================================
    old_viral = '''/// 产品内置增长引擎
class ProductGrowthEngine {
  /// 增长触发点
  static const growthTriggers = ['''

    new_viral = '''/// 【懒人设计】裂变引导频率控制器
/// 防止过度打扰用户，保护用户体验优先
class ViralFrequencyController {
  static const maxDailyPrompts = 2;        // 每天最多2次裂变引导
  static const minIntervalHours = 4;       // 两次引导间隔至少4小时
  static const cooldownAfterDismiss = 24;  // 用户关闭后24小时内不再提示

  /// 检查是否可以显示裂变引导
  static Future<bool> canShowViralPrompt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 检查今日次数
    final todayCount = prefs.getInt('viral_count_$today') ?? 0;
    if (todayCount >= maxDailyPrompts) return false;

    // 检查上次提示时间
    final lastPrompt = prefs.getInt('last_viral_prompt');
    if (lastPrompt != null) {
      final hoursSince = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastPrompt)
      ).inHours;
      if (hoursSince < minIntervalHours) return false;
    }

    // 检查是否在冷却期
    final dismissedAt = prefs.getInt('viral_dismissed_at');
    if (dismissedAt != null) {
      final hoursSince = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(dismissedAt)
      ).inHours;
      if (hoursSince < cooldownAfterDismiss) return false;
    }

    return true;
  }

  /// 记录用户关闭引导
  static Future<void> recordDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('viral_dismissed_at', DateTime.now().millisecondsSinceEpoch);
  }
}

/// 产品内置增长引擎
class ProductGrowthEngine {
  /// 增长触发点
  static const growthTriggers = ['''

    if old_viral in content and '裂变引导频率控制器' not in content:
        content = content.replace(old_viral, new_viral)
        print("✓ 修复4: 第29章裂变引导频率控制")
        changes += 1

    # ============================================================
    # 修复5: 添加跨章节统一通知频率控制器（在第28章末尾添加）
    # ============================================================
    insert_marker = '## 29. 低成本获客与自然增长设计'

    notification_controller = '''
### 28.7 跨模块通知频率统一控制

#### 28.7.1 全局通知控制器

为避免多个模块（家庭账本、NPS、裂变引导等）的通知累积造成用户打扰，建立统一的通知频率控制机制。

```dart
/// 【懒人设计】全局通知频率控制器
/// 统一管理所有模块的通知，防止通知轰炸
class GlobalNotificationController {
  // 通知类型权重（决定优先级）
  static const typeWeights = {
    NotificationType.transactionReminder: 1,   // 低优先级
    NotificationType.budgetAlert: 3,           // 高优先级
    NotificationType.familyActivity: 2,        // 中优先级
    NotificationType.achievementUnlock: 2,     // 中优先级
    NotificationType.npsRequest: 1,            // 低优先级
    NotificationType.viralPrompt: 1,           // 低优先级
    NotificationType.splitRequest: 4,          // 最高优先级（涉及金钱）
  };

  // 每日通知上限
  static const maxDailyNotifications = 8;
  static const maxDailyLowPriority = 3;  // 低优先级通知每天最多3条

  /// 请求发送通知（需经过控制器审批）
  static Future<bool> requestNotification({
    required String userId,
    required NotificationType type,
    required Map<String, dynamic> payload,
  }) async {
    final todayCount = await _getTodayNotificationCount(userId);
    final weight = typeWeights[type] ?? 1;

    // 高优先级通知总是允许
    if (weight >= 3) {
      await _sendNotification(userId, type, payload);
      await _incrementCount(userId);
      return true;
    }

    // 检查每日上限
    if (todayCount >= maxDailyNotifications) {
      return false;  // 今日已达上限
    }

    // 检查低优先级上限
    if (weight == 1) {
      final lowPriorityCount = await _getLowPriorityCount(userId);
      if (lowPriorityCount >= maxDailyLowPriority) {
        return false;
      }
    }

    await _sendNotification(userId, type, payload);
    await _incrementCount(userId);
    return true;
  }

  /// 智能通知时机选择
  static Future<DateTime> getBestNotificationTime(String userId) async {
    // 基于用户活跃时间历史，选择最佳通知时机
    final activeHours = await _getUserActiveHours(userId);
    final now = DateTime.now();

    // 避开睡眠时间（默认22:00-08:00）
    if (now.hour >= 22 || now.hour < 8) {
      return now.copyWith(hour: 9, minute: 0);
    }

    // 选择用户最活跃的时间段
    if (activeHours.contains(now.hour)) {
      return now;
    }

    // 延迟到下一个活跃时间
    for (int h = now.hour + 1; h < 22; h++) {
      if (activeHours.contains(h)) {
        return now.copyWith(hour: h, minute: 0);
      }
    }

    return now.copyWith(hour: 9, minute: 0, day: now.day + 1);
  }
}
```

#### 28.7.2 通知合并策略

```dart
/// 通知合并服务 - 将多条相似通知合并为一条
class NotificationMergeService {
  /// 可合并的通知类型
  static const mergeableTypes = {
    NotificationType.familyActivity,     // 家庭动态可合并
    NotificationType.achievementUnlock,  // 成就可合并
  };

  /// 合并待发送通知
  static Future<List<MergedNotification>> mergeNotifications(
    List<PendingNotification> pending,
  ) async {
    final merged = <MergedNotification>[];
    final byType = <NotificationType, List<PendingNotification>>{};

    // 按类型分组
    for (final n in pending) {
      byType.putIfAbsent(n.type, () => []).add(n);
    }

    for (final entry in byType.entries) {
      if (mergeableTypes.contains(entry.key) && entry.value.length > 1) {
        // 合并为一条
        merged.add(MergedNotification(
          type: entry.key,
          title: _generateMergedTitle(entry.key, entry.value.length),
          // 例如: "家庭账本有3条新动态"
          items: entry.value,
        ));
      } else {
        // 不合并，保持原样
        for (final n in entry.value) {
          merged.add(MergedNotification.single(n));
        }
      }
    }

    return merged;
  }
}
```

---

'''

    if insert_marker in content and '跨模块通知频率统一控制' not in content:
        content = content.replace(insert_marker, notification_controller + insert_marker)
        print("✓ 修复5: 添加跨章节统一通知频率控制器")
        changes += 1

    # ============================================================
    # 修复6: 统一分享素材生成服务说明（在第29章添加引用）
    # ============================================================
    old_share_service = '''#### 29.1.2 分享素材自动生成

```dart
/// 分享素材生成服务
class ShareAssetGeneratorService {'''

    new_share_service = '''#### 29.1.2 分享素材自动生成

> 📎 **设计说明**：本服务为统一的分享素材生成服务，同时被第28章（NPS口碑分享）和第29章（增长裂变）复用，确保分享体验一致性。

```dart
/// 【统一服务】分享素材生成服务
/// 被第28章NPS系统和第29章增长系统共同使用
class ShareAssetGeneratorService {'''

    if old_share_service in content and '【统一服务】分享素材生成服务' not in content:
        content = content.replace(old_share_service, new_share_service)
        print("✓ 修复6: 统一分享素材生成服务说明")
        changes += 1

    # 保存修改
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 全部修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到需要修复的内容或已修复")

    return changes

if __name__ == '__main__':
    main()
