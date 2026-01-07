# -*- coding: utf-8 -*-
"""
修复无障碍设计原则相关问题
包括：语义标签、替代文本、触控目标、动画偏好、颜色依赖等
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ============================================================
    # 修复1: 第13章 - 成员头像添加语义标签规范
    # ============================================================
    old_member_contribution = '''/// 成员贡献展示（无排名，平等展示）
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
}'''

    new_member_contribution = '''/// 成员贡献展示（无排名，平等展示）
/// 【无障碍设计】参考第5章，所有视觉元素都有语义标签
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

  /// 【无障碍】头像语义标签（供屏幕阅读器使用）
  String get avatarSemanticLabel => '$memberName的头像';

  /// 【无障碍】完整语义描述（供屏幕阅读器朗读）
  String get fullSemanticDescription {
    final parts = <String>[memberName, contributionLabel];
    if (personalHighlight != null) {
      parts.add(personalHighlight!);
    }
    parts.add(appreciationNote);
    return parts.join('，');
  }
}'''

    if old_member_contribution in content:
        content = content.replace(old_member_contribution, new_member_contribution)
        print("✓ 修复1: 第13章成员头像添加语义标签")
        changes += 1

    # ============================================================
    # 修复2: 第13章 - 邀请二维码添加替代方案
    # ============================================================
    # 在成员管理部分找到邀请相关代码后添加无障碍替代方案
    old_invite_section = '''/// 智能角色推荐（基于邀请关系）
  static MemberRole recommendRole(String relationship) {
    return familyDefaults[relationship] ?? MemberRole.member;
  }
}'''

    new_invite_section = '''/// 智能角色推荐（基于邀请关系）
  static MemberRole recommendRole(String relationship) {
    return familyDefaults[relationship] ?? MemberRole.member;
  }
}

/// 【无障碍设计】邀请方式服务
/// 参考第5章"可操作"原则，为不同能力用户提供多种邀请方式
class AccessibleInviteService {
  /// 邀请方式枚举
  static const inviteMethods = [
    InviteMethod(
      id: 'qrcode',
      name: '二维码邀请',
      description: '展示二维码供对方扫描',
      accessibilityNote: '需要视觉能力',
    ),
    InviteMethod(
      id: 'link',
      name: '复制邀请链接',
      description: '复制链接通过其他方式分享',
      accessibilityNote: '适合所有用户，推荐方式',
      isRecommendedForAccessibility: true,
    ),
    InviteMethod(
      id: 'voice_code',
      name: '语音邀请码',
      description: '生成6位数字邀请码，可口述给对方',
      accessibilityNote: '适合视障用户',
      isRecommendedForAccessibility: true,
    ),
    InviteMethod(
      id: 'contact',
      name: '从通讯录邀请',
      description: '直接选择联系人发送邀请',
      accessibilityNote: '需要通讯录权限',
    ),
  ];

  /// 生成语音邀请码（6位数字，有效期24小时）
  static Future<VoiceInviteCode> generateVoiceCode(String ledgerId) async {
    final code = _generateNumericCode(6);
    final expiry = DateTime.now().add(Duration(hours: 24));

    return VoiceInviteCode(
      code: code,
      ledgerId: ledgerId,
      expiresAt: expiry,
      // 语义化描述，方便屏幕阅读器朗读
      semanticDescription: '邀请码是 ${code.split('').join(' ')}，'
          '24小时内有效。请告诉对方在加入账本时输入此邀请码。',
    );
  }

  static String _generateNumericCode(int length) {
    final random = Random();
    return List.generate(length, (_) => random.nextInt(10)).join();
  }
}

class InviteMethod {
  final String id;
  final String name;
  final String description;
  final String accessibilityNote;
  final bool isRecommendedForAccessibility;

  const InviteMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.accessibilityNote,
    this.isRecommendedForAccessibility = false,
  });
}

class VoiceInviteCode {
  final String code;
  final String ledgerId;
  final DateTime expiresAt;
  final String semanticDescription;

  VoiceInviteCode({
    required this.code,
    required this.ledgerId,
    required this.expiresAt,
    required this.semanticDescription,
  });
}'''

    if old_invite_section in content:
        content = content.replace(old_invite_section, new_invite_section)
        print("✓ 修复2: 第13章邀请二维码添加无障碍替代方案")
        changes += 1

    # ============================================================
    # 修复3: 第28章 - NPS评分添加无障碍支持
    # ============================================================
    old_nps_question = '''  /// NPS问卷设计
  Future<NpsSurveyResult> conductSurvey(String userId) async {
    // 核心问题
    final score = await _askNpsQuestion(
      question: '您有多大可能向朋友或同事推荐AI智能记账？',
      scale: 10,  // 0-10分
    );'''

    new_nps_question = '''  /// NPS问卷设计
  /// 【无障碍设计】参考第5章，提供多种输入方式
  Future<NpsSurveyResult> conductSurvey(String userId) async {
    // 核心问题 - 支持多种无障碍输入方式
    final score = await _askNpsQuestion(
      question: '您有多大可能向朋友或同事推荐AI智能记账？',
      scale: 10,  // 0-10分
      // 【无障碍】评分输入方式
      inputMethods: [
        NpsInputMethod.slider,      // 滑块（默认）
        NpsInputMethod.numberButtons, // 数字按钮（运动障碍友好）
        NpsInputMethod.voiceInput,  // 语音输入（视障友好）
      ],
      // 【无障碍】语义化评分说明
      accessibilityHints: {
        0: '0分，完全不可能推荐',
        5: '5分，中立态度',
        10: '10分，非常愿意推荐',
      },
    );'''

    if old_nps_question in content:
        content = content.replace(old_nps_question, new_nps_question)
        print("✓ 修复3: 第28章NPS评分添加无障碍支持")
        changes += 1

    # ============================================================
    # 修复4: 第28章 - 分享卡片添加图像描述
    # ============================================================
    old_share_card = '''    return ShareCard(
      type: ShareCardType.achievement,
      title: achievement.title,
      subtitle: achievement.description,
      visual: AchievementVisual(
        badge: achievement.badge,
        backgroundColor: achievement.themeColor,
        animation: achievement.celebrationAnimation,
      ),
      stats: ['''

    new_share_card = '''    // 【无障碍设计】生成图像的替代文本描述
    final accessibilityDescription = _generateAccessibilityDescription(
      achievement: achievement,
      stats: stats,
    );

    return ShareCard(
      type: ShareCardType.achievement,
      title: achievement.title,
      subtitle: achievement.description,
      visual: AchievementVisual(
        badge: achievement.badge,
        backgroundColor: achievement.themeColor,
        animation: achievement.celebrationAnimation,
      ),
      // 【无障碍】图像替代文本，供屏幕阅读器和分享时使用
      accessibilityDescription: accessibilityDescription,
      // 【无障碍】纯文本版本，供无法显示图像时使用
      textOnlyVersion: _generateTextOnlyVersion(achievement, stats),
      stats: ['''

    if old_share_card in content:
        content = content.replace(old_share_card, new_share_card)
        print("✓ 修复4: 第28章分享卡片添加图像描述")
        changes += 1

    # ============================================================
    # 修复5: 第28章 - 惊喜动画添加偏好检测
    # ============================================================
    old_delight_config = '''    // 首次体验惊喜
    MilestoneDelight(
      trigger: 'first_transaction_saved',
      title: '记账之旅开始了！',
      message: '恭喜完成第一笔记账，你的财务管理新篇章开启啦',
      animation: 'confetti_celebration',
      reward: AchievementBadge('first_step'),'''

    new_delight_config = '''    // 首次体验惊喜
    // 【无障碍设计】参考第5章，尊重系统动画偏好设置
    MilestoneDelight(
      trigger: 'first_transaction_saved',
      title: '记账之旅开始了！',
      message: '恭喜完成第一笔记账，你的财务管理新篇章开启啦',
      animation: 'confetti_celebration',
      // 【无障碍】为减少动画偏好用户提供静态版本
      staticFallback: 'achievement_badge_static',
      // 【无障碍】动画是否尊重系统设置
      respectsReduceMotion: true,
      reward: AchievementBadge('first_step'),'''

    if old_delight_config in content:
        content = content.replace(old_delight_config, new_delight_config)
        print("✓ 修复5: 第28章惊喜动画添加偏好检测")
        changes += 1

    # ============================================================
    # 修复6: 第29章 - 裂变按钮添加触控目标规范
    # ============================================================
    old_viral_action = '''        ViralAction(
          type: ActionType.inviteSpouse,
          label: '邀请另一半',
          expectedConversion: 0.70,
        ),'''

    new_viral_action = '''        // 【无障碍设计】参考第5章TouchTargetService，确保触控目标≥48x48
        ViralAction(
          type: ActionType.inviteSpouse,
          label: '邀请另一半',
          expectedConversion: 0.70,
          // 【无障碍】按钮无障碍配置
          accessibility: ViralActionAccessibility(
            semanticLabel: '邀请另一半加入家庭账本',
            minTouchTarget: 48.0,  // WCAG 2.5.5 要求
            hint: '点击后可选择邀请方式',
          ),
        ),'''

    if old_viral_action in content:
        content = content.replace(old_viral_action, new_viral_action)
        print("✓ 修复6: 第29章裂变按钮添加触控目标规范")
        changes += 1

    # ============================================================
    # 修复7: 第13/28/29章 - 添加无障碍系统集成说明
    # ============================================================

    # 7a: 第13章添加无障碍集成
    old_13_integration = '''### 13.9 与其他系统的集成

#### 13.9.0 与全局通知控制器的对接'''

    new_13_integration = '''### 13.9 与其他系统的集成

#### 13.9.0 无障碍设计集成

> 📎 **参考章节**：无障碍设计规范详见[第5章 无障碍设计](#5-无障碍设计)

家庭账本模块的无障碍实现要点：

| 组件 | 无障碍要求 | 实现方式 |
|------|-----------|---------|
| 成员头像 | 替代文本 | `avatarSemanticLabel` 属性 |
| 邀请功能 | 多种方式 | 二维码+链接+语音码+通讯录 |
| 贡献展示 | 屏幕阅读器支持 | `fullSemanticDescription` |
| 角色切换 | 清晰反馈 | 语义化通知消息 |
| 分摊请求 | 触控目标 | ≥48x48像素按钮 |

```dart
/// 【无障碍】家庭账本无障碍配置
class FamilyLedgerAccessibilityConfig {
  /// 确保所有交互元素符合WCAG 2.1 AA标准
  static const wcagLevel = WcagLevel.aa;

  /// 成员列表项语义化
  static String getMemberItemSemantics(LedgerMember member) {
    return '${member.displayName}，角色：${member.role.localizedName}，'
           '${member.isOnline ? "在线" : "离线"}';
  }

  /// 邀请按钮语义化
  static const inviteButtonSemantics = '邀请新成员加入账本，'
      '支持二维码、链接、语音码等多种方式';
}
```

#### 13.9.1 与全局通知控制器的对接'''

    if old_13_integration in content:
        content = content.replace(old_13_integration, new_13_integration)
        print("✓ 修复7a: 第13章添加无障碍系统集成说明")
        changes += 1

    # 7b: 第28章添加无障碍集成（在28.8目标达成检测前添加）
    old_28_target = '''### 28.8 目标达成检测'''

    new_28_target = '''### 28.7.3 无障碍设计集成

> 📎 **参考章节**：无障碍设计规范详见[第5章 无障碍设计](#5-无障碍设计)

NPS与口碑系统的无障碍实现要点：

| 组件 | 无障碍要求 | 实现方式 |
|------|-----------|---------|
| NPS评分 | 多种输入方式 | 滑块+数字按钮+语音 |
| 分享卡片 | 图像替代文本 | `accessibilityDescription` |
| 惊喜动画 | 减少动画支持 | `respectsReduceMotion` |
| 反馈选项 | 触控目标 | ≥48x48像素 |
| 成就徽章 | 颜色+图标 | 不仅依赖颜色传达信息 |

```dart
/// 【无障碍】NPS系统无障碍服务
class NpsAccessibilityService {
  /// 检查是否应使用简化动画
  static Future<bool> shouldReduceMotion() async {
    return MediaQuery.of(context).disableAnimations ||
           await AccessibilityService.isReduceMotionEnabled();
  }

  /// 生成分享卡片的纯文本版本
  static String generateTextOnlyShareContent(Achievement achievement) {
    return '我在AI智能记账获得了「${achievement.title}」成就！'
           '${achievement.description}';
  }

  /// NPS评分的语音输入提示
  static const voiceInputPrompt = '请说出0到10之间的数字，'
      '0表示完全不会推荐，10表示非常愿意推荐';
}
```

### 28.8 目标达成检测'''

    if old_28_target in content:
        content = content.replace(old_28_target, new_28_target)
        print("✓ 修复7b: 第28章添加无障碍系统集成说明")
        changes += 1

    # 7c: 第29章添加无障碍集成（在29.6目标达成检测前添加）
    old_29_target = '''### 29.6 目标达成检测'''

    new_29_target = '''### 29.5.1 无障碍设计集成

> 📎 **参考章节**：无障碍设计规范详见[第5章 无障碍设计](#5-无障碍设计)

低成本获客系统的无障碍实现要点：

| 组件 | 无障碍要求 | 实现方式 |
|------|-----------|---------|
| 裂变按钮 | 触控目标≥48px | `ViralActionAccessibility` |
| 分享引导 | 语义化标签 | `semanticLabel` + `hint` |
| 排行榜 | 不依赖颜色 | 图标+文字+颜色组合 |
| 邀请卡片 | 替代文本 | `accessibilityDescription` |
| 落地页 | 键盘导航 | 焦点顺序合理 |

```dart
/// 【无障碍】裂变系统无障碍配置
class ViralAccessibilityConfig {
  /// 裂变按钮无障碍属性
  static Widget wrapViralButton({
    required Widget child,
    required String semanticLabel,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: TouchTargetService.ensureMinTouchTarget(
        child: child,
        onTap: onPressed,
      ),
    );
  }

  /// 排行榜项目语义化（不依赖颜色）
  static String getRankingItemSemantics({
    required int rank,
    required String metric,
    required String value,
    required bool isAboveAverage,
  }) {
    final status = isAboveAverage ? '高于平均' : '继续努力';
    return '第$rank名，$metric：$value，$status';
  }
}

/// 【无障碍】裂变按钮无障碍配置类
class ViralActionAccessibility {
  final String semanticLabel;
  final double minTouchTarget;
  final String? hint;

  const ViralActionAccessibility({
    required this.semanticLabel,
    this.minTouchTarget = 48.0,
    this.hint,
  });
}
```

### 29.6 目标达成检测'''

    if old_29_target in content:
        content = content.replace(old_29_target, new_29_target)
        print("✓ 修复7c: 第29章添加无障碍系统集成说明")
        changes += 1

    # ============================================================
    # 修复8: 第29章 - 社交排行榜颜色依赖问题
    # ============================================================
    old_comparison_result = '''    // 【伙伴化设计】使用温和的正向表述，避免炫耀或焦虑
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
    }'''

    new_comparison_result = '''    // 【伙伴化设计】使用温和的正向表述，避免炫耀或焦虑
    // 参考第4章4.6.1节"不对比用户与他人的消费"原则
    final percentile = _calculatePercentile(userStats.moneyAge, peerStats.moneyAgeDistribution);

    // 根据用户表现生成温和的鼓励语
    // 【无障碍设计】同时使用图标+文字+颜色，不仅依赖颜色传达信息
    String message;
    String statusIcon;  // 无障碍：图标辅助
    String statusLabel; // 无障碍：文字状态标签
    if (percentile >= 80) {
      message = '你的财务习惯很健康，继续保持！✨';
      statusIcon = '🌟';
      statusLabel = '优秀';
    } else if (percentile >= 50) {
      message = '财务管理稳步提升中，加油！💪';
      statusIcon = '📈';
      statusLabel = '良好';
    } else {
      // 对于低于平均的用户，完全不提及对比，只鼓励
      message = '每一步都是进步，我们一起努力！🌱';
      statusIcon = '🌱';
      statusLabel = '成长中';
    }'''

    if old_comparison_result in content:
        content = content.replace(old_comparison_result, new_comparison_result)
        print("✓ 修复8: 第29章社交排行榜添加非颜色指示")
        changes += 1

    # ============================================================
    # 保存修改
    # ============================================================
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 无障碍设计修复完成，共 {changes} 处 =====")
    else:
        print("\n未找到需要修复的内容，可能已经修复过")

    return changes

if __name__ == '__main__':
    main()
