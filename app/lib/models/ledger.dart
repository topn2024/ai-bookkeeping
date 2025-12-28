import 'package:flutter/material.dart';

class Ledger {
  final String id;
  final String name;
  final String? description;
  final IconData icon;
  final Color color;
  final bool isDefault;
  final DateTime createdAt;
  final List<String> memberIds;

  const Ledger({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
    this.memberIds = const [],
  });

  Ledger copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    bool? isDefault,
    List<String>? memberIds,
  }) {
    return Ledger(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

class DefaultLedgers {
  static Ledger get defaultLedger => Ledger(
        id: 'default',
        name: '日常账本',
        description: '默认账本',
        icon: Icons.book,
        color: const Color(0xFF2196F3),
        isDefault: true,
        createdAt: DateTime.now(),
      );
}
