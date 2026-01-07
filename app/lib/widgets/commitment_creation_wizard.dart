import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commitment_progress_card.dart';

/// 承诺创建向导
///
/// 引导用户创建财务承诺的分步向导
class CommitmentCreationWizard extends StatefulWidget {
  /// 创建完成回调
  final Function(FinancialCommitment)? onComplete;

  /// 取消回调
  final VoidCallback? onCancel;

  const CommitmentCreationWizard({
    super.key,
    this.onComplete,
    this.onCancel,
  });

  /// 显示创建向导
  static Future<FinancialCommitment?> show(BuildContext context) {
    return showModalBottomSheet<FinancialCommitment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommitmentCreationWizard(
        onComplete: (commitment) => Navigator.of(context).pop(commitment),
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<CommitmentCreationWizard> createState() =>
      _CommitmentCreationWizardState();
}

class _CommitmentCreationWizardState extends State<CommitmentCreationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // 表单数据
  CommitmentType? _selectedType;
  String _title = '';
  String _description = '';
  double _targetValue = 0;
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String? _rewardDescription;

  // 表单控制器
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _rewardController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createCommitment();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onCancel?.call();
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedType != null;
      case 1:
        return _title.isNotEmpty;
      case 2:
        return _targetValue > 0;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _createCommitment() {
    final commitment = FinancialCommitment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title,
      description: _description,
      type: _selectedType!,
      status: CommitmentStatus.active,
      targetValue: _targetValue,
      currentValue: 0,
      startDate: DateTime.now(),
      endDate: _endDate,
      rewardDescription: _rewardDescription?.isNotEmpty == true
          ? _rewardDescription
          : null,
    );

    widget.onComplete?.call(commitment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '创建财务承诺',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 步骤指示器
          _buildStepIndicator(theme),
          const SizedBox(height: 20),

          // 内容区域
          SizedBox(
            height: 320,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTypeSelection(theme),
                _buildBasicInfo(theme),
                _buildTargetSetting(theme),
                _buildRewardSetting(theme),
              ],
            ),
          ),

          // 底部按钮
          _buildBottomActions(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                // 圆点
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.primary
                        : isCurrent
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                // 连接线
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < _currentStep
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTypeSelection(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择承诺类型',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择你想要做出的财务承诺类型',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),

          // 类型选项
          ...CommitmentType.values.map((type) {
            final isSelected = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    // 自动填充默认标题
                    if (_title.isEmpty) {
                      _title = _getDefaultTitle(type);
                      _titleController.text = _title;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type.icon,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getTypeDescription(type),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基本信息',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '为你的承诺起个名字',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),

          // 标题输入
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '承诺标题',
              hintText: '例如：本月储蓄3000元',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
            onChanged: (value) {
              setState(() {
                _title = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // 描述输入
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: '详细说明（可选）',
              hintText: '描述一下你的具体计划',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 3,
            onChanged: (value) {
              setState(() {
                _description = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSetting(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设定目标',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设定你要达成的目标值和截止日期',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),

          // 目标金额
          TextField(
            controller: _targetController,
            decoration: InputDecoration(
              labelText: _getTargetLabel(),
              hintText: _getTargetHint(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.flag),
              prefixText: _selectedType == CommitmentType.moneyAge ? '' : '¥ ',
              suffixText: _getTargetSuffix(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (value) {
              setState(() {
                _targetValue = double.tryParse(value) ?? 0;
              });
            },
          ),
          const SizedBox(height: 16),

          // 截止日期
          InkWell(
            onTap: _selectEndDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '截止日期',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          '${_endDate.year}年${_endDate.month}月${_endDate.day}日',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_endDate.difference(DateTime.now()).inDays}天后',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 快捷日期选项
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildQuickDateChip(theme, '7天', 7),
              _buildQuickDateChip(theme, '1个月', 30),
              _buildQuickDateChip(theme, '3个月', 90),
              _buildQuickDateChip(theme, '6个月', 180),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip(ThemeData theme, String label, int days) {
    final targetDate = DateTime.now().add(Duration(days: days));
    final isSelected = _endDate.difference(DateTime.now()).inDays == days;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _endDate = targetDate;
        });
      },
    );
  }

  Widget _buildRewardSetting(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '完成奖励',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '给自己设定一个达成目标后的奖励（可选）',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),

          // 奖励输入
          TextField(
            controller: _rewardController,
            decoration: InputDecoration(
              labelText: '奖励描述',
              hintText: '例如：请自己吃一顿大餐',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.card_giftcard),
            ),
            onChanged: (value) {
              setState(() {
                _rewardDescription = value;
              });
            },
          ),
          const SizedBox(height: 20),

          // 承诺预览
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.preview,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '承诺预览',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"我承诺在${_endDate.month}月${_endDate.day}日前，'
                  '${_getCommitmentSummary()}。"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 返回按钮
          TextButton.icon(
            onPressed: _previousStep,
            icon: const Icon(Icons.arrow_back),
            label: Text(_currentStep == 0 ? '取消' : '上一步'),
          ),
          const Spacer(),
          // 下一步/完成按钮
          FilledButton.icon(
            onPressed: _canProceed() ? _nextStep : null,
            icon: Icon(_currentStep == 3 ? Icons.check : Icons.arrow_forward),
            label: Text(_currentStep == 3 ? '创建承诺' : '下一步'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  String _getDefaultTitle(CommitmentType type) {
    switch (type) {
      case CommitmentType.savings:
        return '本月储蓄目标';
      case CommitmentType.budgetControl:
        return '预算100%执行';
      case CommitmentType.moneyAge:
        return '提升钱龄至30天';
      case CommitmentType.spendingLimit:
        return '控制娱乐支出';
      case CommitmentType.recordingHabit:
        return '每日记账打卡';
    }
  }

  String _getTypeDescription(CommitmentType type) {
    switch (type) {
      case CommitmentType.savings:
        return '设定储蓄金额目标';
      case CommitmentType.budgetControl:
        return '控制预算不超支';
      case CommitmentType.moneyAge:
        return '提升资金平均年龄';
      case CommitmentType.spendingLimit:
        return '限制某类消费';
      case CommitmentType.recordingHabit:
        return '养成记账习惯';
    }
  }

  String _getTargetLabel() {
    switch (_selectedType) {
      case CommitmentType.savings:
        return '储蓄目标金额';
      case CommitmentType.budgetControl:
        return '预算执行率目标';
      case CommitmentType.moneyAge:
        return '钱龄目标';
      case CommitmentType.spendingLimit:
        return '消费上限';
      case CommitmentType.recordingHabit:
        return '连续记账天数';
      default:
        return '目标值';
    }
  }

  String _getTargetHint() {
    switch (_selectedType) {
      case CommitmentType.savings:
        return '例如：3000';
      case CommitmentType.budgetControl:
        return '例如：100';
      case CommitmentType.moneyAge:
        return '例如：30';
      case CommitmentType.spendingLimit:
        return '例如：500';
      case CommitmentType.recordingHabit:
        return '例如：30';
      default:
        return '';
    }
  }

  String _getTargetSuffix() {
    switch (_selectedType) {
      case CommitmentType.budgetControl:
        return '%';
      case CommitmentType.moneyAge:
        return '天';
      case CommitmentType.recordingHabit:
        return '天';
      default:
        return '';
    }
  }

  String _getCommitmentSummary() {
    switch (_selectedType) {
      case CommitmentType.savings:
        return '储蓄${_targetValue.toStringAsFixed(0)}元';
      case CommitmentType.budgetControl:
        return '预算执行率达到${_targetValue.toStringAsFixed(0)}%';
      case CommitmentType.moneyAge:
        return '将钱龄提升至${_targetValue.toStringAsFixed(0)}天';
      case CommitmentType.spendingLimit:
        return '将相关支出控制在${_targetValue.toStringAsFixed(0)}元以内';
      case CommitmentType.recordingHabit:
        return '连续记账${_targetValue.toStringAsFixed(0)}天';
      default:
        return '完成目标';
    }
  }
}
