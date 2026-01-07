import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// AA分摊记账方式
enum AASplitMode {
  myShare, // 仅记我的份额
  totalAmount, // 记录总金额
}

/// 6.09 AA制分摊确认页面
class AASplitPage extends ConsumerStatefulWidget {
  final double totalAmount;
  final int? suggestedPeople;
  final String? description;

  const AASplitPage({
    super.key,
    required this.totalAmount,
    this.suggestedPeople,
    this.description,
  });

  @override
  ConsumerState<AASplitPage> createState() => _AASplitPageState();
}

class _AASplitPageState extends ConsumerState<AASplitPage> {
  late int _peopleCount;
  AASplitMode _splitMode = AASplitMode.myShare;
  String _category = '餐饮';
  String _note = '';

  @override
  void initState() {
    super.initState();
    _peopleCount = widget.suggestedPeople ?? 2;
    _note = widget.description ?? '';
  }

  double get _myShare => widget.totalAmount / _peopleCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n?.aaSplit ?? 'AA制分摊',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 检测提示
                  _buildDetectionHint(l10n),
                  // 分摊信息卡片
                  _buildSplitInfoCard(l10n),
                  // 记账选项
                  _buildSplitModeSelector(l10n),
                  // 分类选择
                  _buildCategorySelector(l10n),
                ],
              ),
            ),
          ),
          // 底部操作
          _buildBottomAction(l10n),
        ],
      ),
    );
  }

  /// 构建检测提示
  Widget _buildDetectionHint(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.group,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.aaDetected ?? '检测到AA制消费',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.description != null
                ? '根据语音"${widget.description}"智能识别'
                : '根据语音内容智能识别到AA制消费',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分摊信息卡片
  Widget _buildSplitInfoCard(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 总金额
          Container(
            padding: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  l10n?.totalAmount ?? '消费总金额',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // 人数选择
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n?.splitPeople ?? '分摊人数',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.suggestedPeople != null)
                      Text(
                        l10n?.autoDetected ?? '自动识别',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCountButton(
                      icon: Icons.remove,
                      onPressed: _peopleCount > 2
                          ? () => setState(() => _peopleCount--)
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Text(
                      '$_peopleCount',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildCountButton(
                      icon: Icons.add,
                      onPressed: _peopleCount < 50
                          ? () => setState(() => _peopleCount++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 我的份额
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.myShare ?? '我的份额',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.totalAmount.toStringAsFixed(2)} ÷ $_peopleCount 人',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${_myShare.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                    Text(
                      l10n?.perPerson ?? '人均',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建数量按钮
  Widget _buildCountButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed != null
                  ? AppTheme.dividerColor
                  : AppTheme.dividerColor.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            icon,
            color: onPressed != null
                ? AppTheme.textPrimaryColor
                : AppTheme.textSecondaryColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// 构建分摊模式选择器
  Widget _buildSplitModeSelector(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.bookkeepingMode ?? '记账方式',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  icon: Icons.person,
                  label: l10n?.onlyMyShare ?? '仅记我的份额',
                  isSelected: _splitMode == AASplitMode.myShare,
                  onTap: () => setState(() => _splitMode = AASplitMode.myShare),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeOption(
                  icon: Icons.group,
                  label: l10n?.recordTotal ?? '记录总金额',
                  isSelected: _splitMode == AASplitMode.totalAmount,
                  onTap: () =>
                      setState(() => _splitMode = AASplitMode.totalAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建模式选项
  Widget _buildModeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分类选择器
  Widget _buildCategorySelector(AppLocalizations? l10n) {
    final categories = [
      {'icon': '🍜', 'name': '餐饮'},
      {'icon': '🎬', 'name': '娱乐'},
      {'icon': '🛒', 'name': '购物'},
      {'icon': '🚗', 'name': '交通'},
      {'icon': '🏠', 'name': '住房'},
      {'icon': '📦', 'name': '其他'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.category ?? '分类',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = _category == cat['name'];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _category = cat['name']!),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.dividerColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat['icon']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat['name']!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作
  Widget _buildBottomAction(AppLocalizations? l10n) {
    final amount = _splitMode == AASplitMode.myShare
        ? _myShare
        : widget.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _confirmSplit,
            icon: const Icon(Icons.check),
            label: Text(
              '${l10n?.confirmSplit ?? "确认分摊"} ¥${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 确认分摊
  void _confirmSplit() {
    final amount = _splitMode == AASplitMode.myShare
        ? _myShare
        : widget.totalAmount;

    final result = {
      'amount': amount,
      'totalAmount': widget.totalAmount,
      'peopleCount': _peopleCount,
      'splitMode': _splitMode.name,
      'category': _category,
      'note': _note.isNotEmpty ? _note : 'AA制聚餐 ($_peopleCount人)',
    };

    Navigator.pop(context, result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记账 ¥${amount.toStringAsFixed(2)}'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
