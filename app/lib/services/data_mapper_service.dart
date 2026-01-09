import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/transaction_location.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/ledger.dart';
import '../models/budget.dart';
import '../utils/date_utils.dart';
import 'database_service.dart';

/// Data mapping service for converting between local and server data formats
class DataMapperService {
  static final DataMapperService _instance = DataMapperService._internal();
  final DatabaseService _db = DatabaseService();

  factory DataMapperService() => _instance;
  DataMapperService._internal();

  // ==================== Transaction Mapping ====================

  /// Convert local Transaction to server format
  Future<Map<String, dynamic>> transactionToServer(Transaction tx) async {
    // Get server IDs for referenced entities
    // Get default ledger (book) for this transaction
    final defaultLedger = await _db.getDefaultLedger();
    String? bookServerId;
    if (defaultLedger != null) {
      bookServerId = await _db.getServerIdByLocalId('book', defaultLedger.id) ?? defaultLedger.id;
    }

    // Get account server ID
    final accountServerId = await _db.getServerIdByLocalId('account', tx.accountId) ?? tx.accountId;

    // Get category server ID
    final categoryServerId = await _getCategoryServerId(tx.category);

    return {
      'book_id': bookServerId,
      'account_id': accountServerId,
      'target_account_id': tx.toAccountId != null
          ? (await _db.getServerIdByLocalId('account', tx.toAccountId!) ?? tx.toAccountId)
          : null,
      'category_id': categoryServerId,
      'transaction_type': tx.type.index + 1, // Local 0/1/2 -> Server 1/2/3
      'amount': tx.amount.toString(),
      'fee': '0', // Default fee
      'transaction_date': _formatDate(tx.date),
      'transaction_time': _formatTime(tx.date),
      'note': tx.note,
      'tags': tx.tags,
      // Location fields (Chapter 14) - from TransactionLocation object
      'location_latitude': tx.location?.latitude.toString(),
      'location_longitude': tx.location?.longitude.toString(),
      'location_place_name': tx.location?.placeName,
      'location_address': tx.location?.address,
      'location_city': tx.location?.city,
      'location_district': tx.location?.district,
      'location_type': tx.location?.locationType?.index,
      'location_poi_id': tx.location?.poiId,
      // Money Age fields
      'money_age': tx.moneyAge,
      // Other fields
      'is_reimbursable': tx.isReimbursable,
      'is_reimbursed': tx.isReimbursed,
      'is_exclude_stats': false,
      'source': tx.source.index, // 0: manual, 1: image, 2: voice, 3: email
      'ai_confidence': tx.aiConfidence?.toString(),
    };
  }

  /// Convert server transaction data to local Transaction
  Transaction transactionFromServer(Map<String, dynamic> data, String localId) {
    // Build TransactionLocation from server data if location fields present
    TransactionLocation? location;
    if (data['location_latitude'] != null && data['location_longitude'] != null) {
      location = TransactionLocation(
        latitude: double.tryParse(data['location_latitude'].toString()) ?? 0,
        longitude: double.tryParse(data['location_longitude'].toString()) ?? 0,
        placeName: data['location_place_name'] as String?,
        address: data['location_address'] as String?,
        city: data['location_city'] as String?,
        district: data['location_district'] as String?,
        locationType: data['location_type'] != null
            ? LocationType.values[data['location_type'] as int]
            : null,
        poiId: data['location_poi_id'] as String?,
      );
    }

    return Transaction(
      id: localId,
      type: TransactionType.values[(data['transaction_type'] as int) - 1],
      amount: double.parse(data['amount'].toString()),
      category: data['category_name'] ?? data['category_id'].toString(),
      note: data['note'] as String?,
      date: _parseDateTime(data['transaction_date'], data['transaction_time']),
      accountId: data['account_id'].toString(),
      toAccountId: data['target_account_id']?.toString(),
      isSplit: false,
      isReimbursable: data['is_reimbursable'] as bool? ?? false,
      isReimbursed: data['is_reimbursed'] as bool? ?? false,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      // Location (Chapter 14)
      location: location,
      // Money Age
      moneyAge: data['money_age'] as int?,
      // Source and AI fields
      source: data['source'] != null
          ? TransactionSource.values[data['source'] as int]
          : TransactionSource.manual,
      aiConfidence: data['ai_confidence'] != null
          ? double.tryParse(data['ai_confidence'].toString())
          : null,
    );
  }

  // ==================== Account Mapping ====================

  /// Convert local Account to server format
  Map<String, dynamic> accountToServer(Account account) {
    return {
      'name': account.name,
      'account_type': account.type.index + 1, // Local 0-4 -> Server 1-5
      'icon': _iconCodeToName(account.icon.codePoint),
      'balance': account.balance.toString(),
      'currency': 'CNY',
      'is_default': account.isDefault,
      'is_active': true,
    };
  }

  /// Convert server account data to local Account
  Account accountFromServer(Map<String, dynamic> data, String localId) {
    return Account(
      id: localId,
      name: data['name'] as String,
      type: AccountType.values[(data['account_type'] as int) - 1],
      balance: double.parse(data['balance'].toString()),
      currency: data['currency'] as String? ?? 'CNY',
      icon: _iconNameToData(data['icon'] as String?),
      color: _defaultAccountColor(data['account_type'] as int),
      isDefault: data['is_default'] as bool? ?? false,
      createdAt: DateTime.now(),
    );
  }

  // ==================== Category Mapping ====================

  /// Convert local Category to server format
  Future<Map<String, dynamic>> categoryToServer(Category category) async {
    String? parentServerId;
    if (category.parentId != null) {
      parentServerId = await _db.getServerIdByLocalId('category', category.parentId!);
    }

    return {
      'parent_id': parentServerId,
      'name': category.name,
      'icon': _iconCodeToName(category.icon.codePoint),
      'category_type': category.isExpense ? 1 : 2, // 1=expense, 2=income
      'sort_order': category.sortOrder,
      'is_system': !category.isCustom,
    };
  }

  /// Convert server category data to local Category
  Category categoryFromServer(Map<String, dynamic> data, String localId) {
    return Category(
      id: localId,
      name: data['name'] as String,
      icon: _iconNameToData(data['icon'] as String?),
      color: _defaultCategoryColor(data['category_type'] as int),
      isExpense: (data['category_type'] as int) == 1,
      parentId: data['parent_id']?.toString(),
      sortOrder: data['sort_order'] as int? ?? 0,
      isCustom: !(data['is_system'] as bool? ?? false),
    );
  }

  // ==================== Ledger (Book) Mapping ====================

  /// Convert local Ledger to server format
  Map<String, dynamic> ledgerToServer(Ledger ledger) {
    return {
      'name': ledger.name,
      'description': ledger.description,
      'book_type': 0, // Personal
      'icon': _iconCodeToName(ledger.icon.codePoint),
      'is_default': ledger.isDefault,
      'is_archived': false,
    };
  }

  /// Convert server book data to local Ledger
  Ledger ledgerFromServer(Map<String, dynamic> data, String localId) {
    return Ledger(
      id: localId,
      name: data['name'] as String,
      description: data['description'] as String?,
      icon: _iconNameToData(data['icon'] as String?),
      color: _defaultLedgerColor(),
      ownerId: 'default_user',
      isDefault: data['is_default'] as bool? ?? false,
      createdAt: DateTime.now(),
    );
  }

  // ==================== Budget Mapping ====================

  /// Convert local Budget to server format
  Future<Map<String, dynamic>> budgetToServer(Budget budget) async {
    final bookServerId = await _db.getServerIdByLocalId('book', budget.ledgerId) ?? budget.ledgerId;
    String? categoryServerId;
    if (budget.categoryId != null) {
      categoryServerId = await _db.getServerIdByLocalId('category', budget.categoryId!);
    }

    return {
      'book_id': bookServerId,
      'category_id': categoryServerId,
      'name': budget.name,
      'amount': budget.amount.toString(),
      'budget_type': budget.period == BudgetPeriod.monthly ? 1 : 2,
      'year': DateTime.now().year,
      'month': budget.period == BudgetPeriod.monthly ? DateTime.now().month : null,
      'is_active': budget.isEnabled,
    };
  }

  /// Convert server budget data to local Budget
  Budget budgetFromServer(Map<String, dynamic> data, String localId) {
    return Budget(
      id: localId,
      name: data['name'] as String,
      amount: double.parse(data['amount'].toString()),
      period: (data['budget_type'] as int) == 1 ? BudgetPeriod.monthly : BudgetPeriod.yearly,
      categoryId: data['category_id']?.toString(),
      ledgerId: data['book_id'].toString(),
      icon: _iconNameToData(null),
      color: _defaultBudgetColor(),
      isEnabled: data['is_active'] as bool? ?? true,
      createdAt: DateTime.now(),
    );
  }

  // ==================== Entity Change Serialization ====================

  /// Serialize entity for sync queue payload
  Future<String> serializeEntity(String entityType, dynamic entity) async {
    Map<String, dynamic> data;

    switch (entityType) {
      case 'transaction':
        data = await transactionToServer(entity as Transaction);
        break;
      case 'account':
        data = accountToServer(entity as Account);
        break;
      case 'category':
        data = await categoryToServer(entity as Category);
        break;
      case 'book':
        data = ledgerToServer(entity as Ledger);
        break;
      case 'budget':
        data = await budgetToServer(entity as Budget);
        break;
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }

    return jsonEncode(data);
  }

  /// Deserialize entity from sync queue payload
  dynamic deserializeEntity(String entityType, String payload, String localId) {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    switch (entityType) {
      case 'transaction':
        return transactionFromServer(data, localId);
      case 'account':
        return accountFromServer(data, localId);
      case 'category':
        return categoryFromServer(data, localId);
      case 'book':
        return ledgerFromServer(data, localId);
      case 'budget':
        return budgetFromServer(data, localId);
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  // ==================== Helper Methods ====================

  Future<String> _getCategoryServerId(String categoryName) async {
    // Try to find by name in ID mapping, otherwise use the name as ID
    final mappings = await _db.getIdMappings('category');
    for (final mapping in mappings) {
      if (mapping['localId'] == categoryName) {
        return mapping['serverId'] as String;
      }
    }
    // If no mapping found, return the category name (will need to be resolved)
    return categoryName;
  }

  /// Format date for server (Beijing time)
  String _formatDate(DateTime date) {
    // For most Chinese users, local time equals Beijing time
    // So we can use the local date directly
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format time for server (Beijing time)
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// Parse date/time from server (Beijing time) to local DateTime
  /// Uses AppDateUtils for proper timezone handling
  DateTime _parseDateTime(dynamic dateStr, dynamic timeStr) {
    if (dateStr == null) return DateTime.now();

    return AppDateUtils.parseServerDateTime(
      dateStr is String ? dateStr : null,
      timeStr is String ? timeStr : null,
    );
  }

  String _iconCodeToName(int codePoint) {
    // Map common icon codes to names
    final iconMap = {
      0xe227: 'restaurant', // dining
      0xe531: 'directions_car', // transportation
      0xe8cc: 'shopping_cart', // shopping
      0xe838: 'movie', // entertainment
      0xe88a: 'home', // housing
      0xe548: 'local_hospital', // medical
      0xe80c: 'school', // education
      0xe8b8: 'more_horiz', // other
      0xe850: 'attach_money', // salary
      0xe263: 'card_giftcard', // bonus
      0xe8f9: 'work', // work
      0xe8e5: 'trending_up', // investment
    };

    return iconMap[codePoint] ?? 'category';
  }

  IconData _iconNameToData(String? iconName) {
    // Map icon names back to IconData
    // This uses Flutter's material icons
    const defaultIcon = IconData(0xe8b8, fontFamily: 'MaterialIcons'); // more_horiz

    if (iconName == null) return defaultIcon;

    final iconMap = {
      'restaurant': const IconData(0xe227, fontFamily: 'MaterialIcons'),
      'directions_car': const IconData(0xe531, fontFamily: 'MaterialIcons'),
      'shopping_cart': const IconData(0xe8cc, fontFamily: 'MaterialIcons'),
      'movie': const IconData(0xe838, fontFamily: 'MaterialIcons'),
      'home': const IconData(0xe88a, fontFamily: 'MaterialIcons'),
      'local_hospital': const IconData(0xe548, fontFamily: 'MaterialIcons'),
      'school': const IconData(0xe80c, fontFamily: 'MaterialIcons'),
      'more_horiz': const IconData(0xe8b8, fontFamily: 'MaterialIcons'),
      'attach_money': const IconData(0xe850, fontFamily: 'MaterialIcons'),
      'card_giftcard': const IconData(0xe263, fontFamily: 'MaterialIcons'),
      'work': const IconData(0xe8f9, fontFamily: 'MaterialIcons'),
      'trending_up': const IconData(0xe8e5, fontFamily: 'MaterialIcons'),
      'account_balance_wallet': const IconData(0xe850, fontFamily: 'MaterialIcons'),
      'credit_card': const IconData(0xe870, fontFamily: 'MaterialIcons'),
      'savings': const IconData(0xe8d1, fontFamily: 'MaterialIcons'),
    };

    return iconMap[iconName] ?? defaultIcon;
  }

  Color _defaultAccountColor(int accountType) {
    const colors = [
      Color(0xFF4CAF50), // Cash - green
      Color(0xFF2196F3), // Debit - blue
      Color(0xFFFF9800), // Credit - orange
      Color(0xFF1976D2), // Alipay - blue
      Color(0xFF4CAF50), // WeChat - green
    ];
    return colors[(accountType - 1).clamp(0, colors.length - 1)];
  }

  Color _defaultCategoryColor(int categoryType) {
    return categoryType == 1
        ? const Color(0xFFE53935) // Expense - red
        : const Color(0xFF43A047); // Income - green
  }

  Color _defaultLedgerColor() {
    return const Color(0xFF5C6BC0); // Indigo
  }

  Color _defaultBudgetColor() {
    return const Color(0xFFFF7043); // Deep orange
  }
}
