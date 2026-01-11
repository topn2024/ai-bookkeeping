import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/source_file_service.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import '../utils/date_utils.dart';

/// 多笔交易确认页面
/// 用于展示和编辑语音识别出的多笔交易
class MultiTransactionConfirmPage extends ConsumerStatefulWidget {
  final List<AIRecognitionResult> transactions;
  final String? audioFilePath;
  final DateTime? recognitionTimestamp;

  const MultiTransactionConfirmPage({
    super.key,
    required this.transactions,
    this.audioFilePath,
    this.recognitionTimestamp,
  });

  @override
  ConsumerState<MultiTransactionConfirmPage> createState() =>
      _MultiTransactionConfirmPageState();
}

class _MultiTransactionConfirmPageState
    extends ConsumerState<MultiTransactionConfirmPage> {
  late List<_EditableTransaction> _transactions;
  final SourceFileService _sourceFileService = SourceFileService();
  bool _isSaving = false;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactions.map((tx) {
      return _EditableTransaction(
        type: tx.type ?? 'expense',
        amount: tx.amount ?? 0,
        category: _mapCategory(tx.category, tx.type),
        description: tx.description ?? '',
        date: _parseDate(tx.date),
        confidence: tx.confidence,
      );
    }).toList();
  }

  String _mapCategory(String? category, String? type) {
    if (category == null) {
      return type == 'income' ? 'other_income' : 'other_expense';
    }

    // 使用 AIRecognitionResult 的有效分类ID列表（包含所有二级分类）
    if (AIRecognitionResult.validCategoryIds.contains(category)) {
      return category;
    }

    // 处理 'other' 特殊情况
    if (category == 'other') {
      return type == 'income' ? 'other_income' : 'other_expense';
    }

    // 尝试通过 DefaultCategories 查找
    final cat = DefaultCategories.findById(category);
    if (cat != null) {
      return cat.id;
    }

    return type == 'income' ? 'other_income' : 'other_expense';
  }

  /// 解析AI识别的日期字符串
  /// 使用集中的日期解析工具类 AppDateUtils.parseRecognizedDate
  DateTime _parseDate(String? dateStr) {
    return AppDateUtils.parseRecognizedDate(dateStr);
  }

  double get _totalAmount =>
      _transactions.fold(0.0, (sum, tx) => sum + tx.amount);

  Future<void> _saveAllTransactions() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final provider = ref.read(transactionProvider.notifier);
      final baseId = DateTime.now().millisecondsSinceEpoch.toString();

      // 保存音频文件（所有交易共享同一个源文件）
      String? savedAudioPath;
      int? audioFileSize;
      if (widget.audioFilePath != null) {
        final audioFile = File(widget.audioFilePath!);
        if (await audioFile.exists()) {
          savedAudioPath =
              await _sourceFileService.saveAudioFile(audioFile, baseId);
          if (savedAudioPath != null) {
            audioFileSize = await _sourceFileService.getFileSize(savedAudioPath);
          }
        }
      }

      final expiryDate = await _sourceFileService.calculateExpiryDate();

      for (int i = 0; i < _transactions.length; i++) {
        final tx = _transactions[i];
        final transactionId = '${baseId}_$i';

        // 构建原始识别数据
        String? recognitionRawData;
        if (i < widget.transactions.length) {
          final original = widget.transactions[i];
          final rawData = {
            'original': {
              'type': original.type,
              'amount': original.amount,
              'category': original.category,
              'description': original.description,
              'date': original.date,
              'confidence': original.confidence,
            },
            'edited': {
              'type': tx.type,
              'amount': tx.amount,
              'category': tx.category,
              'description': tx.description,
            },
            'batch_index': i,
            'batch_total': _transactions.length,
            'timestamp': widget.recognitionTimestamp?.toIso8601String(),
          };
          recognitionRawData = jsonEncode(rawData);
        }

        final transaction = Transaction(
          id: transactionId,
          type: tx.type == 'income'
              ? TransactionType.income
              : TransactionType.expense,
          amount: tx.amount,
          category: tx.category,
          note: tx.description.isNotEmpty ? tx.description : null,
          date: tx.date,
          accountId: 'cash',
          source: TransactionSource.voice,
          aiConfidence: tx.confidence,
          sourceFileLocalPath: savedAudioPath,
          sourceFileType: 'audio/wav',
          sourceFileSize: audioFileSize,
          recognitionRawData: recognitionRawData,
          sourceFileExpiresAt: expiryDate,
        );

        await provider.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存 ${_transactions.length} 笔交易'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _removeTransaction(int index) {
    if (_transactions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一笔交易')),
      );
      return;
    }

    setState(() {
      _transactions.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _addTransaction() {
    setState(() {
      _transactions.add(_EditableTransaction(
        type: 'expense',
        amount: 0,
        category: 'other_expense',
        description: '',
        date: DateTime.now(),
        confidence: 0,
      ));
      _expandedIndex = _transactions.length - 1;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = ThemeColors.of(ref);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1a2e) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('确认 ${_transactions.length} 笔交易'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          TextButton.icon(
            onPressed: _addTransaction,
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 交易列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                return _buildTransactionCard(index, themeColors, isDark);
              },
            ),
          ),

          // 底部汇总和保存按钮
          _buildBottomBar(themeColors, isDark),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(int index, ThemeColors themeColors, bool isDark) {
    final tx = _transactions[index];
    final isExpense = tx.type == 'expense';
    final amountColor = isExpense ? themeColors.expense : themeColors.income;
    final isExpanded = _expandedIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isExpanded
            ? BorderSide(color: themeColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // 头部 - 点击展开/收起
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 分类图标
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: themeColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryIcon(tx.category),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 描述和分类
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description.isNotEmpty
                              ? tx.description
                              : _getCategoryName(tx.category),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCategoryName(tx.category),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 金额
                  Text(
                    '${isExpense ? "-" : "+"}¥${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),

          // 展开的编辑区域
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildEditForm(index, themeColors, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildEditForm(int index, ThemeColors themeColors, bool isDark) {
    final tx = _transactions[index];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型切换
          Row(
            children: [
              Expanded(
                child: _buildTypeButton(
                  index,
                  'expense',
                  '支出',
                  themeColors.expense,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeButton(
                  index,
                  'income',
                  '收入',
                  themeColors.income,
                  isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 金额输入
          TextField(
            controller: TextEditingController(text: tx.amount.toStringAsFixed(2)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tx.type == 'expense'
                  ? themeColors.expense
                  : themeColors.income,
            ),
            decoration: InputDecoration(
              prefixText: '¥ ',
              prefixStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: tx.type == 'expense'
                    ? themeColors.expense
                    : themeColors.income,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0;
              setState(() {
                _transactions[index] = tx.copyWith(amount: amount);
              });
            },
          ),

          const SizedBox(height: 16),

          // 分类选择
          const Text(
            '分类',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getCategoriesForType(tx.type).map((cat) {
              final isSelected = cat['id'] == tx.category;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _transactions[index] = tx.copyWith(category: cat['id']!);
                  });
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? themeColors.primary.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: themeColors.primary, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        cat['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? themeColors.primary
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 备注输入
          TextField(
            controller: TextEditingController(text: tx.description),
            decoration: InputDecoration(
              hintText: '添加备注...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _transactions[index] = tx.copyWith(description: value);
              });
            },
          ),

          const SizedBox(height: 16),

          // 删除按钮
          Center(
            child: TextButton.icon(
              onPressed: () => _removeTransaction(index),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('删除此笔', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    int index,
    String type,
    String label,
    Color color,
    bool isDark,
  ) {
    final tx = _transactions[index];
    final isSelected = tx.type == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          // 切换类型时重置分类
          final newCategory = type == 'income' ? 'other_income' : 'other_expense';
          _transactions[index] = tx.copyWith(
            type: type,
            category: newCategory,
          );
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white24 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeColors themeColors, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252545) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 总计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 ${_transactions.length} 笔',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              Text(
                '总计: ¥${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAllTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check),
                        SizedBox(width: 8),
                        Text(
                          '全部保存',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getCategoriesForType(String type) {
    if (type == 'income') {
      return [
        {'id': 'salary', 'name': '工资', 'icon': '💰'},
        {'id': 'bonus', 'name': '奖金', 'icon': '🎁'},
        {'id': 'parttime', 'name': '兼职', 'icon': '💼'},
        {'id': 'investment', 'name': '投资', 'icon': '📈'},
        {'id': 'other_income', 'name': '其他', 'icon': '📦'},
      ];
    }
    return [
      {'id': 'food', 'name': '餐饮', 'icon': '🍜'},
      {'id': 'transport', 'name': '交通', 'icon': '🚗'},
      {'id': 'shopping', 'name': '购物', 'icon': '🛒'},
      {'id': 'entertainment', 'name': '娱乐', 'icon': '🎬'},
      {'id': 'housing', 'name': '居住', 'icon': '🏠'},
      {'id': 'medical', 'name': '医疗', 'icon': '💊'},
      {'id': 'education', 'name': '教育', 'icon': '📚'},
      {'id': 'other_expense', 'name': '其他', 'icon': '📦'},
    ];
  }

  String _getCategoryIcon(String categoryId) {
    // 尝试通过 DefaultCategories 获取图标
    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      // 获取对应的 emoji，根据图标类型映射
      return _iconToEmoji(category.icon);
    }

    // 回退到默认图标
    const icons = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎬',
      'housing': '🏠',
      'medical': '💊',
      'education': '📚',
      'salary': '💰',
      'bonus': '🎁',
      'parttime': '💼',
      'investment': '📈',
      'other_expense': '📦',
      'other_income': '📦',
      'other': '📦',
    };
    return icons[categoryId] ?? '📦';
  }

  String _iconToEmoji(IconData icon) {
    // 根据常见图标映射到 emoji
    if (icon == Icons.restaurant) return '🍜';
    if (icon == Icons.directions_car) return '🚗';
    if (icon == Icons.local_taxi) return '🚕';
    if (icon == Icons.directions_bus) return '🚌';
    if (icon == Icons.train) return '🚆';
    if (icon == Icons.flight) return '✈️';
    if (icon == Icons.local_gas_station) return '⛽';
    if (icon == Icons.local_parking) return '🅿️';
    if (icon == Icons.shopping_cart) return '🛒';
    if (icon == Icons.phone_android) return '📱';
    if (icon == Icons.tv) return '📺';
    if (icon == Icons.weekend) return '🛋️';
    if (icon == Icons.card_giftcard) return '🎁';
    if (icon == Icons.movie) return '🎬';
    if (icon == Icons.sports_esports) return '🎮';
    if (icon == Icons.beach_access) return '🏖️';
    if (icon == Icons.sports) return '⚽';
    if (icon == Icons.mic) return '🎤';
    if (icon == Icons.celebration) return '🎉';
    if (icon == Icons.fitness_center) return '💪';
    if (icon == Icons.home) return '🏠';
    if (icon == Icons.bolt) return '⚡';
    if (icon == Icons.water_drop) return '💧';
    if (icon == Icons.local_fire_department) return '🔥';
    if (icon == Icons.ac_unit) return '❄️';
    if (icon == Icons.local_hospital) return '🏥';
    if (icon == Icons.medication) return '💊';
    if (icon == Icons.school) return '🎓';
    if (icon == Icons.menu_book) return '📖';
    if (icon == Icons.phone) return '📞';
    if (icon == Icons.wifi) return '📶';
    if (icon == Icons.checkroom) return '👔';
    if (icon == Icons.spa) return '💆';
    if (icon == Icons.subscriptions) return '📺';
    if (icon == Icons.people) return '👥';
    if (icon == Icons.account_balance) return '🏦';
    if (icon == Icons.pets) return '🐾';
    if (icon == Icons.account_balance_wallet) return '💰';
    if (icon == Icons.emoji_events) return '🏆';
    if (icon == Icons.trending_up) return '📈';
    if (icon == Icons.work) return '💼';
    if (icon == Icons.redeem) return '🧧';
    if (icon == Icons.receipt_long) return '🧾';
    if (icon == Icons.store) return '🏪';
    if (icon == Icons.more_horiz) return '📦';
    return '📦';
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) {
      return CategoryLocalizationService.instance.getCategoryName('other_expense');
    }

    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.localizedName;
    }

    return CategoryLocalizationService.instance.getCategoryName(categoryId);
  }
}

/// 可编辑的交易数据
class _EditableTransaction {
  final String type;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final double confidence;

  _EditableTransaction({
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.confidence,
  });

  _EditableTransaction copyWith({
    String? type,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    double? confidence,
  }) {
    return _EditableTransaction(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      confidence: confidence ?? this.confidence,
    );
  }
}
