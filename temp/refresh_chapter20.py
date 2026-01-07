# -*- coding: utf-8 -*-
"""
刷新第20章用户体验设计
1. 添加20.0设计原则回顾部分
2. 添加20.10与其他系统集成部分
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 添加20.0设计原则回顾 ==========
    old_chapter_start = '''## 20. 用户体验设计

> **设计原则依据**：本章的所有设计实现遵循第3章"[懒人设计原则](#3-懒人设计原则)"和第4章"[伙伴化设计原则](#4-伙伴化设计原则)"，包括最少操作、智能默认、渐进复杂度、单手操作、伙伴原则等核心理念。

### 20.1 核心设计理念：以钱龄和零基预算为中心'''

    new_chapter_start = '''## 20. 用户体验设计

### 20.0 设计原则回顾

在深入用户体验设计细节之前，让我们回顾本章如何体现2.0版本的核心设计原则：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       用户体验设计 - 设计原则矩阵                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  懒人设计    │  │  伙伴化      │  │  游戏化      │  │  情感化      │       │
│  │             │  │             │  │             │  │             │       │
│  │ 最少��作    │  │ AI陪伴      │  │ 成就激励    │  │ 正向反馈    │       │
│  │ 智能默认    │  │ 主动关怀    │  │ 等级进阶    │  │ 情绪共鸣    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│         │                │                │                │              │
│         ▼                ▼                ▼                ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌───���─────────┐  ┌─────────────┐       │
│  │  极简交互    │  │  智能引导    │  │  视觉愉悦    │  │  信任建立    │       │
│  │             │  │             │  │             │  │             │       │
│  │ 单手操作    │  │ 场景建议    │  │ 动效流畅    │  │ 透明可控    │       │
│  │ 手势优先    │  │ 预测输入    │  │ 数据可视    │  │ 隐私安心    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                            │
│  用户体验核心理念：                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  "成长为中心，习惯养成，愉悦体验，信任第一"                            │   │
│  │                                                                    │   │
│  │   成长为中心 ──→ 从"记录消费"转向"培养财务习惯"                       │   │
│  │   习惯养成   ──→ 钱龄可视化让用户主动打开APP                          │   │
│  │   愉悦体验   ──→ 精心设计的视觉、动效、反馈                           │   │
│  │   信任第一   ──→ 数据透明、操作可逆、隐私保护                         │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 20.0.1 设计原则在用户体验中的体现

| 设计原则 | UX应用 | 具体措施 | 效果指标 |
|---------|---------|---------|---------|
| **懒人设计** | 最少操作 | 语音记账、智能分类、一键模板 | 记账<5秒 |
| **伙伴化** | AI陪伴 | 智能洞察、主动提醒、财务建议 | 日活率+40% |
| **游戏化** | 成就系统 | 徽章、等级、连续打卡奖励 | 留存率+30% |
| **情感化** | 正向反馈 | 庆祝动画、鼓励文案、成长轨迹 | NPS>50 |
| **极简交互** | 单手操作 | 底部导航、手势滑动、大按钮 | 操作成功率>95% |
| **信任建立** | 透明可控 | 数据可导出、操作可撤销、隐私设置 | 用户投诉率<0.1% |

#### 20.0.2 与其他系统的协同关系

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       用户体验与其他模块的协同关系                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│                        ┌─────────────────────────┐                         │
│                        │   20. 用户体验设计       │                         │
│                        │       （本章）           │                         │
│                        └───────────┬─────────────┘                         │
│                                    │                                       │
│        ┌───────────────────────────┼───────────────────────────┐           │
│        │                           │                           │           │
│        ▼                           ▼                           ▼           │
│   ┌──────────┐              ┌──────────┐              ┌──────────┐        │
│   │ 7.钱龄   │              │ 8.预算   │              │ 9.习惯   │        │
│   │  系统    │              │  系统    │              │  培养    │        │
│   │ ──────── │              │ ──────── │              │ ──────── │        │
│   │ 钱龄仪表 │              │ 预算可视 │              │ 成就展示 │        │
│   │ 等级徽章 │              │ 小金库卡 │              │ 打卡界面 │        │
│   └──────────┘              └──────────┘              └──────────┘        │
│        │                           │                           │           │
│        └───────────────────────────┼───────────────────────────┘           │
│                                    ▼                                       │
│                        ┌─────────────────────────┐                         │
│                        │   12. 数据联动与可视化   │                         │
│                        │   - 图表组件            │                         │
│                        │   - 数据动效            │                         │
│                        └─────────────────────────┘                         │
│                                                                            │
│  ════════════════════════════════════════════════════════════════════════  │
│                           2.0新增协作模块                                   │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│   │18.语音   │  │17.自学习 │  │13.家庭   │  │10.AI识别 │  │28-29.增长│   │
│   │  交互    │  │  系统    │  │  账本    │  │  系统    │  │  体系    │   │
│   │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │  │ ──────── │   │
│   │语音按钮  ���  │个性化UI  │  │家庭视图  │  │识别反馈  │  │引导流程  │   │
│   │波形动画  │  │智能排序  │  │成员切换  │  │结果展示  │  │分享界面  │   │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 20.0.3 目标达成检测

```dart
/// 第20章设计目标达成检测
class Chapter20GoalChecker {
  /// 检查用户体验设计目标是否达成
  static Future<GoalCheckResult> checkGoals() async {
    final results = <GoalCheck>[];

    // 1. 记账效率目标
    results.add(GoalCheck(
      goal: '记账操作<5秒',
      checker: () async {
        final avgTime = await UXAnalytics.getAverageRecordTime();
        return avgTime.inSeconds <= 5;
      },
      requirement: '语音/拍照/模板任一方式',
    ));

    // 2. 单手操作目标
    results.add(GoalCheck(
      goal: '核心功能单手可达',
      checker: () => UXAudit.checkSingleHandReachability(),
      requirement: '底部导航+手势滑动',
    ));

    // 3. 首屏加载目标
    results.add(GoalCheck(
      goal: '首屏加载<500ms',
      checker: () async {
        final loadTime = await PerformanceMetrics.getFirstScreenTime();
        return loadTime.inMilliseconds <= 500;
      },
      requirement: '懒加载+本地缓存',
    ));

    // 4. 用户满意度目标
    results.add(GoalCheck(
      goal: 'NPS>50',
      checker: () async {
        final nps = await UserSurvey.getLatestNPS();
        return nps >= 50;
      },
      requirement: '用户愿意推荐',
    ));

    // 5. 日活率目标
    results.add(GoalCheck(
      goal: '日活率提升40%',
      checker: () async {
        final improvement = await UXAnalytics.getDAUImprovement();
        return improvement >= 0.40;
      },
      requirement: '钱龄可视化驱动',
    ));

    return GoalCheckResult(checks: results);
  }
}
```

> **设计原则依据**：本章的所有设计实现遵循第3章"[懒人设计原则](#3-懒人设计原则)"和第4章"[伙伴化设计原则](#4-伙伴化设计原则)"，包括最少操作、智能默认、渐进复杂度、单手操作、伙伴原则等核心理念。

### 20.1 核心设计理念：以钱龄和零基预算为中心'''

    if old_chapter_start in content:
        content = content.replace(old_chapter_start, new_chapter_start)
        print("✓ 修复1: 添加20.0设计原则回顾部分")
        changes += 1
    else:
        print("✗ 修复1: 未找到章节起始位置")

    # ========== 修复2: 在20.9之后添加20.10与其他系统集成 ==========
    # 找到第21章开始位置
    chapter21_start = '## 21. 国际化与本地化'

    new_section_20_10 = '''### 20.10 与其他系统集成

#### 20.10.1 系统集成概览

用户体验设计与其他2.0模块的集成聚焦于视觉呈现和交互流程：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        用户体验集成全景图                                    │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                        UX设计系统核心                                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ 视觉规范  │  │ 交互模式  │  │ 动效系统  │  │ 组件库   │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘           │  │
│  └───────────────────────────┬─────────────────────────────────────────┘  │
│                              │                                            │
│         ┌────────────────────┼────────────────────┐                       │
│         │                    │                    │                       │
│         ▼                    ▼                    ▼                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│  │  核心业务    │     │  智能增强    │     │  2.0新增    │                 │
│  │  界面集成    │     │  界面集成    │     │  界面集成    │                 │
│  ├─────────────┤     ├─────────────┤     ├─────────────┤                 │
│  │ • 钱龄仪表盘│     │ • AI识别结果│     │ • 语音交互UI│                 │
│  │ • 预算卡片  │     │ • 智能建议卡│     │ • 家庭视图  │                 │
│  │ • 习惯打卡  │     │ • 洞察图表  │     │ • 新手引导  │                 │
│  └─────────────┘     └─────────────┘     └─────────────┘                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 20.10.2 语音交互界面集成

```dart
/// 语音交互UI组件
class VoiceInteractionUI extends StatefulWidget {
  final VoiceRecognitionService voiceService;
  final Function(String) onResult;

  @override
  State<VoiceInteractionUI> createState() => _VoiceInteractionUIState();
}

class _VoiceInteractionUIState extends State<VoiceInteractionUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  double _volume = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    widget.voiceService.volumeStream.listen((volume) {
      setState(() => _volume = volume);
    });

    widget.voiceService.stateStream.listen((state) {
      setState(() => _state = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 语音状态指示器
          _buildStateIndicator(),
          const SizedBox(height: 16),

          // 波形动画
          _buildWaveAnimation(),
          const SizedBox(height: 16),

          // 识别文本显示
          _buildRecognizedText(),
          const SizedBox(height: 24),

          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 60),
          painter: VoiceWavePainter(
            progress: _waveController.value,
            volume: _volume,
            color: _getStateColor(),
            isActive: _state == VoiceState.listening,
          ),
        );
      },
    );
  }

  Widget _buildStateIndicator() {
    final stateConfig = _getStateConfig();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(stateConfig.icon, color: stateConfig.color, size: 20),
        const SizedBox(width: 8),
        Text(
          stateConfig.text,
          style: TextStyle(
            color: stateConfig.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  StateConfig _getStateConfig() {
    switch (_state) {
      case VoiceState.idle:
        return StateConfig(
          icon: Icons.mic_none,
          text: '点击开始语音记账',
          color: Colors.grey,
        );
      case VoiceState.listening:
        return StateConfig(
          icon: Icons.mic,
          text: '正在聆听...',
          color: Theme.of(context).colorScheme.primary,
        );
      case VoiceState.processing:
        return StateConfig(
          icon: Icons.psychology,
          text: 'AI正在理解...',
          color: Colors.orange,
        );
      case VoiceState.success:
        return StateConfig(
          icon: Icons.check_circle,
          text: '识别完成',
          color: Colors.green,
        );
      case VoiceState.error:
        return StateConfig(
          icon: Icons.error,
          text: '识别失败，请重试',
          color: Colors.red,
        );
    }
  }
}

/// 波形绘制器
class VoiceWavePainter extends CustomPainter {
  final double progress;
  final double volume;
  final Color color;
  final bool isActive;

  VoiceWavePainter({
    required this.progress,
    required this.volume,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      // 静态波形
      _drawStaticWave(canvas, size);
      return;
    }

    // 动态波形
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barCount = 20;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2 + barWidth / 2;
      final normalizedHeight = (sin((i / barCount + progress) * 2 * pi) + 1) / 2;
      final barHeight = normalizedHeight * size.height * volume.clamp(0.2, 1.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: barWidth,
            height: barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.volume != volume ||
        oldDelegate.isActive != isActive;
  }
}
```

#### 20.10.3 AI识别结果展示

```dart
/// AI识别结果展示组件
class AIRecognitionResultCard extends StatelessWidget {
  final RecognitionResult result;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：AI识别标识
            _buildHeader(context),
            const SizedBox(height: 16),

            // 识别结果预览
            _buildResultPreview(context),
            const SizedBox(height: 16),

            // 置信度指示器
            _buildConfidenceIndicator(context),
            const SizedBox(height: 16),

            // 操作按钮
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'AI智能识别',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          _getSourceLabel(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResultPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 分类图标
          CategoryIcon(
            categoryId: result.categoryId,
            size: 48,
          ),
          const SizedBox(width: 12),

          // 交易信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.description ?? '未识别描述',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  result.categoryName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // 金额
          AmountText(
            amount: result.amount,
            type: result.type,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context) {
    final confidence = result.confidence;
    final color = confidence >= 0.9
        ? Colors.green
        : confidence >= 0.7
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI置信度',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: confidence,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
        ),
        if (confidence < 0.7) ...[
          const SizedBox(height: 8),
          Text(
            '💡 建议检查识别结果是否准确',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新识别'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('确认记账'),
          ),
        ),
      ],
    );
  }

  String _getSourceLabel() {
    switch (result.source) {
      case RecognitionSource.voice:
        return '来自语音';
      case RecognitionSource.image:
        return '来自图片';
      case RecognitionSource.text:
        return '来自文本';
    }
  }
}
```

#### 20.10.4 家庭账本界面集成

```dart
/// 家庭账本视图切换器
class FamilyViewSwitcher extends StatelessWidget {
  final String? currentFamilyId;
  final List<FamilyInfo> families;
  final Function(String?) onFamilyChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      initialValue: currentFamilyId,
      onSelected: onFamilyChanged,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentFamilyId == null ? Icons.person : Icons.family_restroom,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              currentFamilyId == null
                  ? '个人账本'
                  : families.firstWhere((f) => f.id == currentFamilyId).name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
      itemBuilder: (context) => [
        // 个人账本选项
        PopupMenuItem<String?>(
          value: null,
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('个人账本'),
            trailing: currentFamilyId == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        // 家庭账本列表
        ...families.map((family) => PopupMenuItem<String>(
          value: family.id,
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: family.avatarUrl != null
                  ? NetworkImage(family.avatarUrl!)
                  : null,
              child: family.avatarUrl == null
                  ? Text(family.name[0])
                  : null,
            ),
            title: Text(family.name),
            subtitle: Text('${family.memberCount}位成员'),
            trailing: currentFamilyId == family.id
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        )),
        const PopupMenuDivider(),
        // 创建/加入家庭
        PopupMenuItem<String>(
          value: '__create__',
          child: ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('创建或加入家庭'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// 家庭成员消费排行榜
class FamilyMemberRanking extends StatelessWidget {
  final List<MemberSpending> rankings;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, size: 20),
                const SizedBox(width: 8),
                Text(
                  '本月消费排行',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rankings.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isCurrentUser = member.userId == currentUserId;

              return _buildRankingItem(
                context,
                rank: index + 1,
                member: member,
                isCurrentUser: isCurrentUser,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(
    BuildContext context, {
    required int rank,
    required MemberSpending member,
    required bool isCurrentUser,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentUser
            ? Border.all(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 32,
            child: Text(
              _getRankEmoji(rank),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          // 头像
          CircleAvatar(
            radius: 18,
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(member.name[0])
                : null,
          ),
          const SizedBox(width: 12),
          // 名字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name + (isCurrentUser ? ' (我)' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${member.transactionCount}笔交易',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // 金额
          Text(
            '¥${member.totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: rank == 1 ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }
}
```

#### 20.10.5 新手引导流程集成

```dart
/// 新手引导管理器
class OnboardingManager {
  final UserPreferences _prefs;
  final AnalyticsService _analytics;

  /// 引导步骤定义
  static const onboardingSteps = [
    OnboardingStep(
      id: 'welcome',
      title: '欢迎使用 AI智能记账',
      description: '您的智能财务伙伴，帮助您养成良好的理财习惯',
      illustration: 'assets/onboarding/welcome.svg',
    ),
    OnboardingStep(
      id: 'money_age',
      title: '认识"钱龄"',
      description: '钱龄是衡量您财务健康的核心指标，数值越高代表您的财务状况越稳定',
      illustration: 'assets/onboarding/money_age.svg',
      highlightFeature: 'moneyAgeWidget',
    ),
    OnboardingStep(
      id: 'zero_budget',
      title: '零基预算法',
      description: '给每一分钱都安排工作，让您的收入发挥最大价值',
      illustration: 'assets/onboarding/zero_budget.svg',
      highlightFeature: 'budgetAllocation',
    ),
    OnboardingStep(
      id: 'voice_record',
      title: '语音快速记账',
      description: '说一句话就能记账，比如"午餐花了25块"',
      illustration: 'assets/onboarding/voice.svg',
      demoAction: DemoAction.showVoiceDemo,
    ),
    OnboardingStep(
      id: 'ai_insights',
      title: 'AI智能洞察',
      description: '我们会分析您的消费习惯，提供个性化的省钱建议',
      illustration: 'assets/onboarding/ai_insights.svg',
    ),
    OnboardingStep(
      id: 'ready',
      title: '准备开始！',
      description: '设置您的第一个月预算，开启理财之旅',
      illustration: 'assets/onboarding/start.svg',
      action: OnboardingAction.setupFirstBudget,
    ),
  ];

  /// 显示引导页面
  Future<void> showOnboarding(BuildContext context) async {
    final completed = await _prefs.isOnboardingCompleted();
    if (completed) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          steps: onboardingSteps,
          onComplete: () async {
            await _prefs.setOnboardingCompleted(true);
            await _analytics.logEvent('onboarding_completed');
            Navigator.of(context).pop();
          },
          onSkip: () async {
            await _prefs.setOnboardingCompleted(true);
            await _analytics.logEvent('onboarding_skipped');
            Navigator.of(context).pop();
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// 显示功能引导气泡
  Future<void> showFeatureCoachMark(
    BuildContext context,
    String featureId,
    GlobalKey targetKey,
  ) async {
    final shown = await _prefs.isCoachMarkShown(featureId);
    if (shown) return;

    final config = _getCoachMarkConfig(featureId);
    if (config == null) return;

    await showCoachMark(
      context: context,
      targetKey: targetKey,
      title: config.title,
      description: config.description,
      onDismiss: () async {
        await _prefs.setCoachMarkShown(featureId);
      },
    );
  }

  CoachMarkConfig? _getCoachMarkConfig(String featureId) {
    const configs = {
      'voice_button': CoachMarkConfig(
        title: '语音记账',
        description: '点击这里，说出您的消费，AI会自动识别并记录',
      ),
      'money_age_card': CoachMarkConfig(
        title: '您的钱龄',
        description: '这是您的财务健康指标，点击查看详细分析',
      ),
      'quick_add': CoachMarkConfig(
        title: '快速记账',
        description: '长按可以选择不同的记账方式',
      ),
      'budget_card': CoachMarkConfig(
        title: '预算管理',
        description: '点击查看和调整您的小金库分配',
      ),
    };
    return configs[featureId];
  }
}

/// 引导气泡组件
class CoachMarkOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return const SizedBox();

    final targetPosition = targetBox.localToGlobal(Offset.zero);
    final targetSize = targetBox.size;

    return Stack(
      children: [
        // 半透明遮罩（镂空目标区域）
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: CoachMarkPainter(
            targetRect: Rect.fromLTWH(
              targetPosition.dx - 8,
              targetPosition.dy - 8,
              targetSize.width + 16,
              targetSize.height + 16,
            ),
          ),
        ),

        // 提示卡片
        Positioned(
          left: 16,
          right: 16,
          top: targetPosition.dy + targetSize.height + 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: onDismiss,
                      child: const Text('知道了'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

#### 20.10.6 成就系统界面集成

```dart
/// 成就解锁动画
class AchievementUnlockAnimation extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onComplete;

  @override
  State<AchievementUnlockAnimation> createState() =>
      _AchievementUnlockAnimationState();
}

class _AchievementUnlockAnimationState extends State<AchievementUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // 启动动画序列
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    // 1. 缩放动画
    await _scaleController.forward();

    // 2. 礼花动画
    _confettiController.forward();

    // 3. 播放音效
    await HapticFeedback.mediumImpact();

    // 4. 延迟后关闭
    await Future.delayed(const Duration(seconds: 2));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 礼花效果
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [
              Colors.yellow,
              Colors.orange,
              Colors.pink,
              Colors.purple,
            ],
          ),

          // 成就卡片
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildAchievementCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber[300]!,
            Colors.orange[400]!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎉 图标
          const Text(
            '🎉',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),

          // 标题
          const Text(
            '成就解锁！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // 徽章
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.achievement.icon,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 成就名称
          Text(
            widget.achievement.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 成就描述
          Text(
            widget.achievement.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 奖励
          if (widget.achievement.reward != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '奖励：${widget.achievement.reward}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}
```

---

'''

    if chapter21_start in content:
        # 在第21章之前插入新内容
        content = content.replace(chapter21_start, new_section_20_10 + chapter21_start)
        print("✓ 修复2: 添加20.10与其他系统集成部分（6个子章节）")
        changes += 1
    else:
        print("✗ 修复2: 未找到第21章开始位置")

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 第20章刷新完成，共 {changes} 处修改 =====")
    else:
        print("\n未找到需要修改的内容")

    return changes

if __name__ == '__main__':
    main()
