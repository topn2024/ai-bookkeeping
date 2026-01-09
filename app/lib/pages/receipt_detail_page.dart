import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

/// 商品明细项
class ReceiptItem {
  final String name;
  final String? specification;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem({
    required this.name,
    this.specification,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

/// 小票数据
class ReceiptData {
  final String merchantName;
  final String? merchantAddress;
  final String receiptNumber;
  final DateTime timestamp;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double confidence;
  final String? imageUrl;

  ReceiptData({
    required this.merchantName,
    this.merchantAddress,
    required this.receiptNumber,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.confidence,
    this.imageUrl,
  });
}

/// 6.07 小票商品明细页面
class ReceiptDetailPage extends ConsumerStatefulWidget {
  final ReceiptData? receiptData;

  const ReceiptDetailPage({super.key, this.receiptData});

  @override
  ConsumerState<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends ConsumerState<ReceiptDetailPage> {
  late ReceiptData _receipt;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receiptData ?? _getMockData();
  }

  ReceiptData _getMockData() {
    return ReceiptData(
      merchantName: '永辉超市(朝阳店)',
      merchantAddress: '北京市朝阳区建国路88号',
      receiptNumber: '#2024123015420086',
      timestamp: DateTime(2024, 12, 30, 15, 42),
      items: [
        ReceiptItem(
          name: '伊利纯牛奶 250ml*12',
          quantity: 1,
          unitPrice: 45.90,
          totalPrice: 45.90,
        ),
        ReceiptItem(
          name: '红富士苹果',
          specification: '1.2kg x ¥12.80/kg',
          quantity: 1,
          unitPrice: 12.80,
          totalPrice: 15.36,
        ),
        ReceiptItem(
          name: '金龙鱼菜籽油 5L',
          quantity: 1,
          unitPrice: 79.90,
          totalPrice: 79.90,
        ),
        ReceiptItem(
          name: '清风抽纸 3层*10包',
          quantity: 1,
          unitPrice: 29.90,
          totalPrice: 29.90,
        ),
        ReceiptItem(
          name: '农夫山泉 550ml*12',
          quantity: 1,
          unitPrice: 15.80,
          totalPrice: 15.80,
        ),
      ],
      subtotal: 186.86,
      discount: 0.36,
      totalAmount: 186.50,
      confidence: 0.95,
    );
  }

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
          l10n.receiptDetail,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: _isEditing ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
            ),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 小票图片预览
                  _buildImagePreview(),
                  // 商户信息
                  _buildMerchantInfo(),
                  // 商品列表
                  _buildItemsList(l10n),
                ],
              ),
            ),
          ),
          // 合计区域
          _buildTotalSection(l10n),
        ],
      ),
    );
  }

  /// 构建图片预览
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[200]!,
            Colors.grey[300]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.receipt_long,
              size: 32,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '置信度 ${(_receipt.confidence * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商户信息
  Widget _buildMerchantInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _receipt.merchantName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(_receipt.timestamp)} · 小票号 ${_receipt.receiptNumber}',
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
    );
  }

  /// 构建商品列表
  Widget _buildItemsList(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '商品明细（${_receipt.items.length}件）',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  l10n.autoExtracted,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          ..._receipt.items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  /// 构建商品卡片
  Widget _buildItemCard(ReceiptItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.specification ?? 'x${item.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.edit,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              onPressed: () => _editItem(item),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建合计区域
  Widget _buildTotalSection(AppLocalizations l10n) {
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
        child: Column(
          children: [
            // 商品合计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.subtotal,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  '¥${_receipt.subtotal.toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 优惠折扣
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.discount,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  '-¥${_receipt.discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 实付金额
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '实付金额',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '¥${_receipt.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.expenseColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _confirmBookkeeping,
                icon: const Icon(Icons.check),
                label: Text(l10n.confirmBookkeeping),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 编辑商品项
  void _editItem(ReceiptItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditItemSheet(item),
    );
  }

  /// 构建编辑商品弹窗
  Widget _buildEditItemSheet(ReceiptItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.totalPrice.toStringAsFixed(2),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
          const Text(
            '编辑商品',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: '商品名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '金额',
              prefixText: '¥',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    // 保存编辑的商品
                    final newPrice = double.tryParse(priceController.text) ?? item.totalPrice;
                    final newItem = ReceiptItem(
                      name: nameController.text,
                      specification: item.specification,
                      quantity: item.quantity,
                      unitPrice: newPrice / item.quantity,
                      totalPrice: newPrice,
                    );
                    _updateItem(item, newItem);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 更新商品项
  void _updateItem(ReceiptItem oldItem, ReceiptItem newItem) {
    setState(() {
      final index = _receipt.items.indexOf(oldItem);
      if (index != -1) {
        final newItems = List<ReceiptItem>.from(_receipt.items);
        newItems[index] = newItem;
        final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.totalPrice);
        _receipt = ReceiptData(
          merchantName: _receipt.merchantName,
          merchantAddress: _receipt.merchantAddress,
          receiptNumber: _receipt.receiptNumber,
          timestamp: _receipt.timestamp,
          items: newItems,
          subtotal: newSubtotal,
          discount: _receipt.discount,
          totalAmount: newSubtotal - _receipt.discount,
          confidence: _receipt.confidence,
          imageUrl: _receipt.imageUrl,
        );
      }
    });
  }

  /// 确认记账
  Future<void> _confirmBookkeeping() async {
    final db = DatabaseService();

    // 创建交易记录
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.expense,
      amount: _receipt.totalAmount,
      category: 'shopping',
      note: '${_receipt.merchantName} - ${_receipt.items.length}件商品',
      date: _receipt.timestamp,
      accountId: 'default',
      rawMerchant: _receipt.merchantName,
      source: TransactionSource.image,
      aiConfidence: _receipt.confidence,
    );

    try {
      await db.insertTransaction(transaction);
      if (mounted) {
        Navigator.pop(context, _receipt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已记账 ¥${_receipt.totalAmount.toStringAsFixed(2)}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记账失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
