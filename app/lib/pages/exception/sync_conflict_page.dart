import 'package:flutter/material.dart';

/// 同步冲突解决页面
/// 原型设计 11.02：同步冲突解决
/// - 冲突说明卡片
/// - 冲突记录详情（本地版本 vs 云端版本）
/// - 操作选项（使用本地版本、使用云端版本、手动合并）
class SyncConflictPage extends StatelessWidget {
  final ConflictRecord conflict;
  final VoidCallback? onUseLocal;
  final VoidCallback? onUseCloud;
  final VoidCallback? onManualMerge;

  const SyncConflictPage({
    super.key,
    required this.conflict,
    this.onUseLocal,
    this.onUseCloud,
    this.onManualMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConflictWarning(theme),
                    const SizedBox(height: 16),
                    _buildConflictDetails(theme),
                    const SizedBox(height: 16),
                    _buildActionButtons(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFB74D),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          const Expanded(
            child: Text(
              '数据冲突',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 冲突警告卡片
  Widget _buildConflictWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem,
            color: Color(0xFFFFB74D),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '发现数据冲突',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFF57C00),
                  ),
                ),
                Text(
                  '同一条记录在本地和云端都有修改',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 冲突详情
  Widget _buildConflictDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '冲突记录',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 记录标题
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      conflict.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflict.title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          conflict.dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 12),

              // 本地版本
              _buildVersionCard(
                theme,
                isLocal: true,
                amount: conflict.localAmount,
                note: conflict.localNote,
                modifiedAt: conflict.localModifiedAt,
              ),
              const SizedBox(height: 8),

              // 云端版本
              _buildVersionCard(
                theme,
                isLocal: false,
                amount: conflict.cloudAmount,
                note: conflict.cloudNote,
                modifiedAt: conflict.cloudModifiedAt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionCard(
    ThemeData theme, {
    required bool isLocal,
    required double amount,
    required String note,
    required String modifiedAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isLocal ? Icons.smartphone : Icons.cloud,
                    size: 16,
                    color: isLocal
                        ? theme.colorScheme.primary
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLocal ? '本地版本' : '云端版本',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '$modifiedAt 修改',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('金额', style: TextStyle(fontSize: 13)),
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('备注', style: TextStyle(fontSize: 13)),
              Text(note, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        // 使用本地版本
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onUseLocal,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.smartphone, size: 20),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '使用本地版本',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '保留 ¥${conflict.localAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 使用云端版本
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onUseCloud,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF4169E1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud, size: 20),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '使用云端版本',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '保留 ¥${conflict.cloudAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 手动合并
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onManualMerge,
            icon: const Icon(Icons.merge, size: 20),
            label: const Text('手动合并'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 冲突记录数据模型
class ConflictRecord {
  final String id;
  final String title;
  final String emoji;
  final String dateStr;
  final double localAmount;
  final String localNote;
  final String localModifiedAt;
  final double cloudAmount;
  final String cloudNote;
  final String cloudModifiedAt;

  ConflictRecord({
    required this.id,
    required this.title,
    required this.emoji,
    required this.dateStr,
    required this.localAmount,
    required this.localNote,
    required this.localModifiedAt,
    required this.cloudAmount,
    required this.cloudNote,
    required this.cloudModifiedAt,
  });
}
