import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';

/// 语音识别类型
enum VoiceRecordType {
  voice, // 语音输入
  image, // 图片识别
  text, // 文字输入
}

/// 语音记录数据模型
class VoiceRecord {
  final String id;
  final VoiceRecordType type;
  final String content;
  final DateTime timestamp;
  final bool isRecorded;
  final double? amount;
  final String? category;

  VoiceRecord({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.isRecorded = true,
    this.amount,
    this.category,
  });
}

/// 6.06 对话历史页面
/// 显示用户的语音/图片识别记录历史
class VoiceHistoryPage extends ConsumerStatefulWidget {
  const VoiceHistoryPage({super.key});

  @override
  ConsumerState<VoiceHistoryPage> createState() => _VoiceHistoryPageState();
}

class _VoiceHistoryPageState extends ConsumerState<VoiceHistoryPage> {
  List<VoiceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoiceRecords();
  }

  /// 从数据库加载语音和图片识别记录
  Future<void> _loadVoiceRecords() async {
    try {
      final db = await DatabaseService().database;

      // 查询来源为voice或image的交易记录
      final results = await db.query(
        'transactions',
        where: 'source IN (?, ?)',
        whereArgs: [TransactionSource.voice.index, TransactionSource.image.index],
        orderBy: 'datetime DESC',
      );

      if (mounted) {
        setState(() {
          _records = results.map((row) {
            final transaction = Transaction.fromMap(row);

            return VoiceRecord(
              id: transaction.id,
              type: transaction.source == TransactionSource.voice
                  ? VoiceRecordType.voice
                  : VoiceRecordType.image,
              content: transaction.note ?? '${transaction.category} ${transaction.amount}',
              timestamp: transaction.date,
              amount: transaction.amount,
              category: transaction.category,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _records = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupedRecords = _groupRecordsByDate(_records);

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
          l10n.voiceHistoryTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppTheme.textSecondaryColor,
            ),
            onPressed: _showClearConfirmDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedRecords.isEmpty
              ? _buildEmptyState(l10n)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: groupedRecords.length,
                  itemBuilder: (context, index) {
                    final entry = groupedRecords.entries.elementAt(index);
                    return _buildDateSection(entry.key, entry.value, l10n);
                  },
                ),
      floatingActionButton: _buildVoiceFab(l10n),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// 按日期分组记录
  Map<String, List<VoiceRecord>> _groupRecordsByDate(List<VoiceRecord> records) {
    final Map<String, List<VoiceRecord>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final record in records) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );

      String dateKey;
      if (recordDate == today) {
        dateKey = '今天';
      } else if (recordDate == yesterday) {
        dateKey = '昨天';
      } else {
        dateKey = '${record.timestamp.month}月${record.timestamp.day}日';
      }

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(record);
    }

    return grouped;
  }

  /// 构建空状态
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noVoiceHistory,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.voiceHistoryHint,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建日期分区
  Widget _buildDateSection(
    String dateLabel,
    List<VoiceRecord> records,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          ...records.map((record) => _buildRecordCard(record, l10n)),
        ],
      ),
    );
  }

  /// 构建记录卡片
  Widget _buildRecordCard(VoiceRecord record, AppLocalizations l10n) {
    final isVoice = record.type == VoiceRecordType.voice;
    final isImage = record.type == VoiceRecordType.image;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showRecordDetail(record),
          onLongPress: () => _showRecordOptions(record),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isVoice
                        ? AppTheme.primaryColor
                        : isImage
                            ? AppTheme.secondaryColor
                            : AppTheme.textSecondaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isVoice
                        ? Icons.mic
                        : isImage
                            ? Icons.photo_camera
                            : Icons.text_fields,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVoice ? '"${record.content}"' : record.content,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(record.timestamp) +
                            (record.isRecorded
                                ? ' · ${record.amount != null ? "已记录 ¥${record.amount!.toStringAsFixed(2)}" : "已记录"}'
                                : ' · 未记录'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 状态图标
                Icon(
                  record.isRecorded ? Icons.check_circle : Icons.pending,
                  color: record.isRecorded
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建悬浮语音按钮
  Widget _buildVoiceFab(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.9),
                AppTheme.primaryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: _startVoiceRecording,
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.quickBookkeeping,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  /// 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 显示记录详情
  void _showRecordDetail(VoiceRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: record.type == VoiceRecordType.voice
                        ? AppTheme.primaryColor
                        : AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    record.type == VoiceRecordType.voice
                        ? Icons.mic
                        : Icons.photo_camera,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.type == VoiceRecordType.voice
                            ? '语音记账'
                            : '图片识别',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatFullTimestamp(record.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '识别内容',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (record.amount != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '记账金额',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  Text(
                    '¥${record.amount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
            ],
            if (record.category != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '分类',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.category!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRecord(record);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('关闭'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示记录操作选项
  void _showRecordOptions(VoiceRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _showRecordDetail(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('重新识别'),
              onTap: () {
                Navigator.pop(context);
                _reRecognize(record);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: Text('删除', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                _deleteRecord(record);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 显示清空确认对话框
  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话记录'),
        content: const Text('确定要清空所有对话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllRecords();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  /// 格式化完整时间戳
  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 删除记录
  void _deleteRecord(VoiceRecord record) {
    setState(() {
      _records.removeWhere((r) => r.id == record.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除记录')),
    );
  }

  /// 清空所有记录
  void _clearAllRecords() {
    setState(() {
      _records.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空所有记录')),
    );
  }

  /// 开始语音记账
  void _startVoiceRecording() {
    Navigator.pushNamed(context, '/voice-recognition');
  }

  /// 重新识别记录
  void _reRecognize(VoiceRecord record) {
    // 根据记录类型导航到对应的识别页面
    if (record.type == VoiceRecordType.voice) {
      // 语音记录：跳转到语音识别页面，带上原始内容供参考
      Navigator.pushNamed(
        context,
        '/voice-recognition',
        arguments: {'originalContent': record.content},
      );
    } else if (record.type == VoiceRecordType.image) {
      // 图片记录：提示用户重新拍照
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请重新拍照或选择图片进行识别'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamed(context, '/image-recognition');
    }
  }
}
