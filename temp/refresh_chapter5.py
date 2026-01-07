# -*- coding: utf-8 -*-
"""
刷新第5章无障碍设计
1. 修正章节编号错误（24.0.x -> 5.0.x）
2. 添加5.8 2.0新模块无障碍支持
3. 添加5.9 目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 修正章节编号错误 ==========
    number_fixes = [
        ('#### 24.0.1 无障碍设计原则矩阵', '#### 5.0.1 无障碍设计原则矩阵'),
        ('#### 24.0.2 设计理念', '#### 5.0.2 设计理念'),
        ('#### 24.0.3 与2.0其他系统的协同关系图', '#### 5.0.3 与2.0其他系统的协同关系图'),
    ]

    for old, new in number_fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"Fix number: {old} -> {new}")
            changes += 1

    # ========== 修复2: 添加5.8和5.9新章节 ==========
    # 在5.7.7之后，第6章之前添加
    marker_part3 = '''---


---

# 第三部分：核心业务功能'''

    new_sections = '''### 5.8 2.0新模块无障碍支持

#### 5.8.1 家庭账本无障碍设计

```dart
/// 家庭账本无障碍服务
class FamilyLedgerAccessibility {
  final TtsService _tts;
  final SemanticsService _semantics;

  /// 成员列表语义标签
  String getMemberSemantics(FamilyMember member) {
    final roleDesc = _getRoleDescription(member.role);
    final statusDesc = member.isOnline ? '在线' : '离线';
    return '${member.name}，$roleDesc，$statusDesc';
  }

  String _getRoleDescription(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner: return '账本创建者';
      case FamilyRole.admin: return '管理员';
      case FamilyRole.member: return '成员';
      case FamilyRole.viewer: return '查看者';
    }
  }

  /// 共享交易播报
  Future<void> announceSharedTransaction(Transaction tx, String memberName) async {
    await _tts.speak('$memberName 记录了一笔${tx.isExpense ? "支出" : "收入"}，'
        '${tx.categoryName}，${tx.amount.toInt()}元');
  }

  /// 邀请操作无障碍
  Widget buildInviteButton() {
    return Semantics(
      label: '邀请家人加入账本',
      hint: '双击生成邀请链接或语音邀请码',
      button: true,
      child: _buildInviteButtonUI(),
    );
  }

  /// 权限变更通知
  Future<void> announceRoleChange(String memberName, FamilyRole newRole) async {
    await _tts.speak('$memberName 的权限已变更为 ${_getRoleDescription(newRole)}');
  }
}
```

#### 5.8.2 位置智能无障碍设计

```dart
/// 位置智能无障碍服务
class LocationAccessibility {
  final TtsService _tts;

  /// POI识别结果播报
  Future<void> announcePOI(PoiResult poi) async {
    await _tts.speak('检测到您在 ${poi.name}，'
        '${poi.category}类别，'
        '建议分类为 ${poi.suggestedCategory}');
  }

  /// 地理围栏触发播报
  Future<void> announceGeofenceTrigger(GeofenceEvent event) async {
    final actionDesc = event.type == GeofenceEventType.enter ? '到达' : '离开';
    await _tts.speak('$actionDesc ${event.regionName}，'
        '${event.suggestedAction ?? ""}');
  }

  /// 场景识别语义
  String getSceneSemantics(SceneType scene) {
    switch (scene) {
      case SceneType.dining: return '用餐场景，推荐记录餐饮消费';
      case SceneType.shopping: return '购物场景，推荐记录购物消费';
      case SceneType.commute: return '通勤场景，推荐记录交通消费';
      case SceneType.entertainment: return '娱乐场景，推荐记录娱乐消费';
      default: return '普通场景';
    }
  }

  /// 位置权限引导
  Widget buildLocationPermissionGuide() {
    return Semantics(
      label: '位置权限设置',
      hint: '开启位置权限可自动识别消费场所，让记账更智能',
      child: _buildPermissionGuideUI(),
    );
  }
}
```

#### 5.8.3 语音交互增强无障碍

```dart
/// 语音交互增强无障碍服务
class VoiceInteractionAccessibility {
  final TtsService _tts;
  final HapticService _haptic;

  /// 语音识别状态反馈
  Future<void> announceRecognitionState(VoiceState state) async {
    switch (state) {
      case VoiceState.listening:
        await _haptic.lightImpact();
        await _tts.speak('正在聆听，请说话');
        break;
      case VoiceState.processing:
        await _tts.speak('正在识别');
        break;
      case VoiceState.success:
        await _haptic.successNotification();
        break;
      case VoiceState.error:
        await _haptic.errorNotification();
        await _tts.speak('识别失败，请重试');
        break;
    }
  }

  /// 多笔交易识别结果播报
  Future<void> announceMultipleTransactions(List<Transaction> txList) async {
    await _tts.speak('识别到${txList.length}笔交易');
    for (var i = 0; i < txList.length; i++) {
      final tx = txList[i];
      await _tts.speak('第${i + 1}笔，${tx.categoryName}，${tx.amount.toInt()}元');
      await Future.delayed(Duration(milliseconds: 300));
    }
    await _tts.speak('双击确认记录，左滑取消');
  }

  /// 语音命令帮助
  Widget buildVoiceHelpButton() {
    return Semantics(
      label: '语音命令帮助',
      hint: '双击了解支持的语音命令',
      button: true,
      onTap: () => _showVoiceCommands(),
      child: _buildHelpButtonUI(),
    );
  }

  void _showVoiceCommands() {
    _tts.speak('支持的语音命令：'
        '记账，如"午餐35元"；'
        '查询，如"本月消费多少"；'
        '设置，如"设置餐饮预算1000"');
  }
}
```

#### 5.8.4 习惯培养无障碍设计

```dart
/// 习惯培养无障碍服务
class HabitAccessibility {
  final TtsService _tts;
  final HapticService _haptic;

  /// 连续打卡成就播报
  Future<void> announceStreak(int days, bool isNewRecord) async {
    await _haptic.successNotification();
    if (isNewRecord) {
      await _tts.speak('恭喜！连续记账$days天，创造新纪录！');
    } else {
      await _tts.speak('太棒了！连续记账$days天，继续保持！');
    }
  }

  /// 打卡按钮语义
  Widget buildCheckInButton(HabitStatus status) {
    final label = status.isCheckedIn
        ? '今日已完成记账打卡'
        : '点击完成今日记账打卡';
    final hint = status.isCheckedIn
        ? '当前连续${status.streak}天'
        : '当前连续${status.streak}天，完成后可保持连续';

    return Semantics(
      label: label,
      hint: hint,
      button: !status.isCheckedIn,
      enabled: !status.isCheckedIn,
      child: _buildCheckInButtonUI(status),
    );
  }

  /// 挑战进度播报
  Future<void> announceChallengeProgress(Challenge challenge) async {
    final progress = (challenge.current / challenge.target * 100).toInt();
    await _tts.speak('${challenge.name}挑战，'
        '已完成$progress%，'
        '还差${challenge.target - challenge.current}${challenge.unit}');
  }
}
```

### 5.9 目标达成检测

```dart
/// 无障碍设计目标检测服务
class AccessibilityGoalDetector {
  /// 无障碍相关目标
  static const accessibilityGoals = AccessibilityGoalCriteria(
    // WCAG 2.1 AA级合规
    wcagCompliance: ComplianceTarget(
      level: 'AA',
      measurement: 'WCAG 2.1 AA级准则通过率',
    ),

    // 语义标签覆盖率
    semanticCoverage: RateTarget(
      target: 1.0,  // 100%可交互元素有语义标签
      measurement: '有语义标签的可交互元素/总可交互元素',
    ),

    // 色彩对比度
    colorContrast: RatioTarget(
      target: 4.5,  // AA级最低对比度
      measurement: '文字与背景的对比度比值',
    ),

    // 触控目标尺寸
    touchTargetSize: SizeTarget(
      target: Size(44, 44),  // 最小44x44dp
      measurement: '可点击元素的最小尺寸',
    ),

    // 屏幕阅读器可用率
    screenReaderUsability: RateTarget(
      target: 1.0,  // 100%功能可通过屏幕阅读器使用
      measurement: '屏幕阅读器可操作功能/总功能',
    ),

    // 无障碍审计评分
    auditScore: ScoreTarget(
      target: 90,  // 满分100
      measurement: 'Flutter Accessibility Inspector评分',
    ),
  );

  /// 检测目标达成状态
  Future<AccessibilityGoalStatus> checkGoalStatus() async {
    final status = AccessibilityGoalStatus();

    // 语义覆盖率检测
    final semanticCoverage = await _calculateSemanticCoverage();
    status.semanticCoverage = GoalCheckResult(
      current: semanticCoverage,
      target: accessibilityGoals.semanticCoverage.target,
      achieved: semanticCoverage >= accessibilityGoals.semanticCoverage.target,
    );

    // 触控目标尺寸检测
    final minTouchSize = await _measureMinTouchTargetSize();
    status.touchTargetSize = GoalCheckResult(
      current: minTouchSize,
      target: accessibilityGoals.touchTargetSize.target,
      achieved: minTouchSize.width >= 44 && minTouchSize.height >= 44,
    );

    // 屏幕阅读器可用率
    final screenReaderRate = await _testScreenReaderUsability();
    status.screenReaderUsability = GoalCheckResult(
      current: screenReaderRate,
      target: accessibilityGoals.screenReaderUsability.target,
      achieved: screenReaderRate >= accessibilityGoals.screenReaderUsability.target,
    );

    // 审计评分
    final auditScore = await _runAccessibilityAudit();
    status.auditScore = GoalCheckResult(
      current: auditScore,
      target: accessibilityGoals.auditScore.target,
      achieved: auditScore >= accessibilityGoals.auditScore.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| WCAG合规级别 | AA级 | WCAG 2.1 AA准则通过率 | P0 |
| 语义标签覆盖 | 100% | 可交互元素语义标签覆盖 | P0 |
| 色彩对比度 | >=4.5:1 | 文字与背景对比度 | P0 |
| 触控目标尺寸 | >=44x44dp | 最小可点击区域 | P0 |
| 屏幕阅读器可用 | 100% | 功能可通过屏幕阅读器使用 | P0 |
| 审计评分 | >=90分 | Accessibility Inspector评分 | P1 |
| 文字缩放支持 | 200% | 最大支持的文字缩放比例 | P1 |
| 键盘导航支持 | 100% | 可通过键盘完成的操作 | P1 |

---


'''

    if marker_part3 in content and '### 5.8 2.0新模块无障碍支持' not in content:
        content = content.replace(marker_part3, new_sections + marker_part3)
        print("OK: Added 5.8 and 5.9 sections")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 5 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
