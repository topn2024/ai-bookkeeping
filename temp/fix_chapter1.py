# -*- coding: utf-8 -*-
"""修复第1章缺失的代码块"""

import time

file_path = 'd:/code/ai-bookkeeping/docs/design/app_v2_code_design.md'

# 等待一下，避免文件冲突
time.sleep(1)

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 查找插入位置
marker = '*来源: app_v2_design.md 第715行*\n\n---\n\n## 第2章 产品定位与愿景'

if marker not in content:
    print(f'未找到标记位置')
    # 尝试另一个标记
    marker2 = '*来源: app_v2_design.md 第715行*'
    if marker2 in content:
        idx = content.find(marker2)
        # 找到后面的 "## 第2章"
        idx2 = content.find('## 第2章 产品定位与愿景', idx)
        if idx2 > idx:
            before = content[:idx + len(marker2)]
            after = content[idx2:]
            middle = content[idx + len(marker2):idx2]
            print(f'找到替代标记，中间内容长度: {len(middle)}')
else:
    print('找到标记位置')

# 要插入的代码
chapter1_addition = '''

### 1.5 目标达成检测框架

#### <a id="code-1b"></a>代码块 1b

```dart
/// 目标达成检测结果
class ValidationResult {
  final String goalName;
  final bool passed;
  final double score;
  final List<String> details;
  final DateTime timestamp;

  const ValidationResult({
    required this.goalName,
    required this.passed,
    required this.score,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'goalName': goalName,
    'passed': passed,
    'score': score,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 目标检测器接口
abstract class GoalChecker {
  String get goalName;

  /// 验证目标是否达成
  Future<ValidationResult> validate();

  /// 获取当前进度 (0.0 - 1.0)
  Future<double> getProgress();

  /// 获取改进建议
  Future<List<String>> getSuggestions();
}

/// 钱龄目标检测器
class MoneyAgeGoalChecker implements GoalChecker {
  final MoneyAgeService _moneyAgeService;
  final AnalyticsService _analytics;

  MoneyAgeGoalChecker(this._moneyAgeService, this._analytics);

  @override
  String get goalName => '钱龄分析';

  @override
  Future<ValidationResult> validate() async {
    final awarenessRate = await _analytics.getFeatureAwarenessRate('money_age');
    final trialRate = await _analytics.getFeatureTrialRate('money_age');
    final regularUseRate = await _analytics.getFeatureRegularUseRate('money_age');

    final functionalityComplete = await _checkFunctionalityComplete();
    final adoptionMet = awarenessRate >= 0.80 &&
                        trialRate >= 0.60 &&
                        regularUseRate >= 0.30;

    final passed = functionalityComplete && adoptionMet;
    final score = (awarenessRate + trialRate + regularUseRate) / 3;

    return ValidationResult(
      goalName: goalName,
      passed: passed,
      score: score,
      details: [
        '功能完整度: ${functionalityComplete ? "通过" : "未通过"}',
        '知晓率: ${(awarenessRate * 100).toStringAsFixed(1)}%',
        '试用率: ${(trialRate * 100).toStringAsFixed(1)}%',
        '持续使用率: ${(regularUseRate * 100).toStringAsFixed(1)}%',
      ],
      timestamp: DateTime.now(),
    );
  }

  Future<bool> _checkFunctionalityComplete() async {
    return await _moneyAgeService.isFullyImplemented();
  }

  @override
  Future<double> getProgress() async {
    final result = await validate();
    return result.score;
  }

  @override
  Future<List<String>> getSuggestions() async {
    final result = await validate();
    if (result.passed) return ['目标已达成，继续保持！'];

    return [
      if (result.score < 0.5) '增加钱龄功能的用户引导',
      if (result.score < 0.7) '优化钱龄展示的可视化效果',
      '在首页添加钱龄卡片入口',
    ];
  }
}
```

*来源: 第1章设计要求补充*

### 1.6 设计原则定义

#### <a id="code-1c"></a>代码块 1c

```dart
/// 设计原则类型枚举
enum DesignPrincipleType {
  userFirst,        // 用户第一
  simplicity,       // 简洁至上
  dataIntegrity,    // 数据完整
  performance,      // 性能优先
  accessibility,    // 无障碍设计
}

/// 设计原则定义
class DesignPrinciple {
  final DesignPrincipleType type;
  final String name;
  final String description;
  final List<String> guidelines;
  final int priority;

  const DesignPrinciple({
    required this.type,
    required this.name,
    required this.description,
    required this.guidelines,
    required this.priority,
  });
}

/// 设计原则验证器
class DesignPrincipleValidator {
  static const principles = [
    DesignPrinciple(
      type: DesignPrincipleType.userFirst,
      name: '用户第一',
      description: '所有设计决策优先考虑用户体验',
      guidelines: [
        '减少用户操作步骤',
        '提供清晰的反馈',
        '允许撤销操作',
        '渐进式功能展示',
      ],
      priority: 1,
    ),
    DesignPrinciple(
      type: DesignPrincipleType.simplicity,
      name: '简洁至上',
      description: '界面简洁直观，避免功能过载',
      guidelines: [
        '核心功能突出展示',
        '高级功能渐进可见',
        '减少视觉噪音',
        '统一交互模式',
      ],
      priority: 2,
    ),
    DesignPrinciple(
      type: DesignPrincipleType.dataIntegrity,
      name: '数据完整',
      description: '确保用户数据安全完整',
      guidelines: [
        '本地优先存储',
        '自动增量同步',
        '冲突智能合并',
        '完整备份恢复',
      ],
      priority: 3,
    ),
  ];

  /// 验证设计是否符合原则
  Future<ValidationResult> validate(String featureName) async {
    final violations = <String>[];
    var score = 1.0;

    for (final principle in principles) {
      final isCompliant = await _checkCompliance(featureName, principle);
      if (!isCompliant) {
        violations.add('违反原则: ${principle.name}');
        score -= 0.2;
      }
    }

    return ValidationResult(
      goalName: '设计原则验证: $featureName',
      passed: violations.isEmpty,
      score: score.clamp(0.0, 1.0),
      details: violations.isEmpty ? ['所有设计原则已满足'] : violations,
      timestamp: DateTime.now(),
    );
  }

  Future<bool> _checkCompliance(String feature, DesignPrinciple principle) async {
    return true;
  }
}
```

*来源: 第1章设计原则补充*

'''

# 执行替换
old_text = '*来源: app_v2_design.md 第715行*\n\n---\n\n## 第2章 产品定位与愿景'
new_text = '*来源: app_v2_design.md 第715行*' + chapter1_addition + '---\n\n## 第2章 产品定位与愿景'

if old_text in content:
    content = content.replace(old_text, new_text)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('✓ 第1章：添加GoalChecker和DesignPrinciple代码块成功')
else:
    print('✗ 未找到替换位置，尝试其他方法...')
    # 尝试更灵活的匹配
    import re
    pattern = r'(\*来源: app_v2_design\.md 第715行\*)\s*\n\s*---\s*\n\s*(## 第2章 产品定位与愿景)'
    match = re.search(pattern, content)
    if match:
        new_content = content[:match.end(1)] + chapter1_addition + '---\n\n' + match.group(2) + content[match.end():]
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print('✓ 第1章：使用正则匹配添加代码块成功')
    else:
        print('✗ 正则匹配也失败')
