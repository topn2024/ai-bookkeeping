import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../services/database_service.dart';

/// CRUD 操作的统一状态
class CrudState<T> {
  final List<T> items;
  final bool isLoading;
  final AppError? error;
  final DateTime? lastUpdated;

  const CrudState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  CrudState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    AppError? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) {
    return CrudState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  bool get hasError => error != null;
  bool get isReady => !isLoading && lastUpdated != null;
}

/// 通用 CRUD Notifier 基类
///
/// 使用方式:
/// ```dart
/// class AccountNotifier extends CrudNotifier<Account, String> {
///   @override
///   String get tableName => 'accounts';
///
///   @override
///   String getId(Account entity) => entity.id;
///
///   @override
///   Account fromMap(Map<String, dynamic> map) => Account.fromMap(map);
///
///   @override
///   Map<String, dynamic> toMap(Account entity) => entity.toMap();
/// }
/// ```
abstract class CrudNotifier<T, ID> extends Notifier<CrudState<T>> {
  /// 数据库服务实例
  DatabaseService get db => DatabaseService();

  /// 表名（用于日志和错误信息）
  String get tableName;

  /// 获取实体ID
  ID getId(T entity);

  /// 从Map创建实体
  T fromMap(Map<String, dynamic> map);

  /// 将实体转换为Map
  Map<String, dynamic> toMap(T entity);

  /// 获取所有数据（子类需要实现）
  Future<List<T>> fetchAll();

  /// 插入数据（子类需要实现）
  Future<void> insertOne(T entity);

  /// 更新数据（子类需要实现）
  Future<void> updateOne(T entity);

  /// 删除数据（子类需要实现）
  Future<void> deleteOne(ID id);

  @override
  CrudState<T> build() {
    _initialize();
    return const CrudState();
  }

  Future<void> _initialize() async {
    await refresh();
  }

  /// 刷新数据
  Future<Result<List<T>>> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await fetchAll();
      state = state.copyWith(
        items: items,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      return Result.success(items);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(isLoading: false, error: error);
      return Result.failure(error);
    }
  }

  /// 添加项目
  Future<Result<T>> add(T entity) async {
    try {
      await insertOne(entity);
      state = state.copyWith(
        items: [...state.items, entity],
        lastUpdated: DateTime.now(),
      );
      return Result.success(entity);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(error: error);
      return Result.failure(error);
    }
  }

  /// 更新项目
  Future<Result<T>> update(T entity) async {
    try {
      await updateOne(entity);
      state = state.copyWith(
        items: state.items.map((item) {
          return getId(item) == getId(entity) ? entity : item;
        }).toList(),
        lastUpdated: DateTime.now(),
      );
      return Result.success(entity);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(error: error);
      return Result.failure(error);
    }
  }

  /// 删除项目
  Future<Result<bool>> delete(ID id) async {
    try {
      await deleteOne(id);
      state = state.copyWith(
        items: state.items.where((item) => getId(item) != id).toList(),
        lastUpdated: DateTime.now(),
      );
      return Result.success(true);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(error: error);
      return Result.failure(error);
    }
  }

  /// 根据ID获取单个项目
  T? getById(ID id) {
    try {
      return state.items.firstWhere((item) => getId(item) == id);
    } catch (e) {
      return null;
    }
  }

  /// 根据条件查找项目
  List<T> where(bool Function(T) test) {
    return state.items.where(test).toList();
  }

  /// 查找第一个匹配项
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return state.items.firstWhere(test);
    } catch (e) {
      return null;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 批量添加
  Future<Result<List<T>>> addAll(List<T> entities) async {
    try {
      for (final entity in entities) {
        await insertOne(entity);
      }
      state = state.copyWith(
        items: [...state.items, ...entities],
        lastUpdated: DateTime.now(),
      );
      return Result.success(entities);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(error: error);
      return Result.failure(error);
    }
  }

  /// 批量删除
  Future<Result<bool>> deleteWhere(bool Function(T) test) async {
    final toDelete = state.items.where(test).toList();
    try {
      for (final item in toDelete) {
        await deleteOne(getId(item));
      }
      state = state.copyWith(
        items: state.items.where((item) => !test(item)).toList(),
        lastUpdated: DateTime.now(),
      );
      return Result.success(true);
    } catch (e, st) {
      final error = ErrorMapper.mapException(e, st);
      state = state.copyWith(error: error);
      return Result.failure(error);
    }
  }
}

/// 简化版 CRUD Notifier（使用 List 作为状态）
///
/// 适用于不需要 isLoading/error 状态的简单场景
abstract class SimpleCrudNotifier<T, ID> extends Notifier<List<T>> {
  DatabaseService get db => DatabaseService();

  String get tableName;
  ID getId(T entity);
  Future<List<T>> fetchAll();
  Future<void> insertOne(T entity);
  Future<void> updateOne(T entity);
  Future<void> deleteOne(ID id);

  @override
  List<T> build() {
    _initialize();
    return [];
  }

  Future<void> _initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    state = await fetchAll();
  }

  Future<void> add(T entity) async {
    await insertOne(entity);
    state = [...state, entity];
  }

  Future<void> update(T entity) async {
    await updateOne(entity);
    state = state.map((item) {
      return getId(item) == getId(entity) ? entity : item;
    }).toList();
  }

  Future<void> delete(ID id) async {
    await deleteOne(id);
    state = state.where((item) => getId(item) != id).toList();
  }

  T? getById(ID id) {
    try {
      return state.firstWhere((item) => getId(item) == id);
    } catch (e) {
      return null;
    }
  }
}
