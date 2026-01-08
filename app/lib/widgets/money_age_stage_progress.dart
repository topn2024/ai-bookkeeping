import 'package:flutter/material.dart';

import '../services/money_age_level_service.dart';

/// 钱龄阶段进度展示组件
///
/// 功能：
/// 1. 显示当前阶段和下一阶段
/// 2. 展示阶段进度条
/// 3. 显示已获得的奖励积分
/// 4. 支持展开查看全部阶段
class MoneyAgeStageProgressCard extends StatelessWidget {
  /// 当前钱龄天数
  final int currentDays;

  /// 是否显示详细进度
  final bool showDetails;

  /// 点击回调
  final VoidCallback? onTap;

  const MoneyAgeStageProgressCard({
    super.key,
    required this.currentDays,
    this.showDetails = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = StageProgress.calculate(currentDays);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? () => _showStageDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '阶段进度',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${progress.totalRewardPoints}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 当前阶段
              _buildCurrentStage(progress),

              if (showDetails) ...[
                const SizedBox(height: 16),
                // 进度条
                _buildProgressBar(progress),
                const SizedBox(height: 12),
                // 下一阶段提示
                _buildNextStageHint(progress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStage(StageProgress progress) {
    final stage = progress.currentStage;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: stage.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: stage.color,
              width: 2,
            ),
          ),
          child: Icon(
            stage.icon,
            color: stage.color,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    stage.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: stage.color,
                    ),
                  ),
                  if (progress.isMaxStage)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '最高',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stage.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(StageProgress progress) {
    return Column(
      children: [
        // 进度数值
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progress.currentStage.minDays}天',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              '${(progress.progressInStage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: progress.currentStage.color,
              ),
            ),
            Text(
              progress.nextStage != null
                  ? '${progress.nextStage!.minDays}天'
                  : '无上限',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.progressInStage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(progress.currentStage.color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildNextStageHint(StageProgress progress) {
    if (progress.isMaxStage) {
      return Row(
        children: [
          Icon(
            Icons.celebration,
            size: 16,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            '恭喜！您已达到最高阶段',
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final nextStage = progress.nextStage!;

    return Row(
      children: [
        Icon(
          Icons.arrow_forward,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              children: [
                const TextSpan(text: '距离'),
                TextSpan(
                  text: '「${nextStage.name}」',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: nextStage.color,
                  ),
                ),
                TextSpan(text: '还需 ${progress.daysToNextStage} 天'),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, size: 12, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                '+${nextStage.rewardPoints}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStageDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MoneyAgeStageDetailsSheet(currentDays: currentDays),
    );
  }
}

/// 阶段详情底部弹窗
class MoneyAgeStageDetailsSheet extends StatelessWidget {
  final int currentDays;

  const MoneyAgeStageDetailsSheet({
    super.key,
    required this.currentDays,
  });

  @override
  Widget build(BuildContext context) {
    final progress = StageProgress.calculate(currentDays);
    final allStages = MoneyAgeStages.all;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '全部阶段',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '已获得 ${progress.totalRewardPoints} 积分',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 阶段列表
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: allStages.length,
              itemBuilder: (context, index) {
                final stage = allStages[index];
                final isAchieved = stage.isAchieved(currentDays);
                final isCurrent = stage == progress.currentStage;

                return _buildStageItem(
                  stage,
                  isAchieved: isAchieved,
                  isCurrent: isCurrent,
                  progress: isCurrent ? stage.getProgress(currentDays) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageItem(
    MoneyAgeStage stage, {
    required bool isAchieved,
    required bool isCurrent,
    double? progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? stage.color.withValues(alpha: 0.1)
            : isAchieved
                ? Colors.grey.shade100
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? stage.color
              : isAchieved
                  ? Colors.grey.shade300
                  : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 阶段头部
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isAchieved
                      ? stage.color.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  stage.icon,
                  color: isAchieved ? stage.color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stage.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAchieved ? null : Colors.grey,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stage.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isAchieved && !isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '已达成',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stage.minDays}天${stage.maxDays != null ? ' - ${stage.maxDays}天' : '+'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAchieved
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      size: 14,
                      color: isAchieved ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${stage.rewardPoints}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isAchieved ? Colors.amber.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 阶段描述
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              stage.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          // 当前阶段进度条
          if (isCurrent && progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(stage.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '进度 ${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],

          // 阶段建议
          if (stage.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: stage.tips.map((tip) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// 阶段进度简洁显示（用于首页等场景）
class MoneyAgeStageProgressCompact extends StatelessWidget {
  final int currentDays;
  final VoidCallback? onTap;

  const MoneyAgeStageProgressCompact({
    super.key,
    required this.currentDays,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = StageProgress.calculate(currentDays);
    final stage = progress.currentStage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: stage.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: stage.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stage.icon, size: 16, color: stage.color),
            const SizedBox(width: 6),
            Text(
              stage.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: stage.color,
              ),
            ),
            if (!progress.isMaxStage) ...[
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.progressInStage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: stage.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
