import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Saga事务状态
enum SagaStatus {
  /// 待执行
  pending,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 补偿中
  compensating,

  /// 已补偿
  compensated,

  /// 失败
  failed,

  /// 部分完成
  partiallyCompleted,
}

/// Saga步骤状态
enum SagaStepStatus {
  /// 待执行
  pending,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 已跳过
  skipped,

  /// 失败
  failed,

  /// 补偿中
  compensating,

  /// 已补偿
  compensated,

  /// 补偿失败
  compensationFailed,
}

/// Saga步骤定义
class SagaStep<T> {
  /// 步骤ID
  final String id;

  /// 步骤名称
  final String name;

  /// 正向操作
  final Future<T> Function(Map<String, dynamic> context) execute;

  /// 补偿操作（回滚）
  final Future<void> Function(T result, Map<String, dynamic> context)? compensate;

  /// 是否可跳过
  final bool skippable;

  /// 超时时间
  final Duration timeout;

  /// 最大重试次数
  final int maxRetries;

  /// 重试延迟
  final Duration retryDelay;

  /// 依赖的步骤ID
  final List<String> dependsOn;

  const SagaStep({
    required this.id,
    required this.name,
    required this.execute,
    this.compensate,
    this.skippable = false,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.dependsOn = const [],
  });
}

/// Saga步骤执行结果
class SagaStepResult<T> {
  /// 步骤ID
  final String stepId;

  /// 状态
  final SagaStepStatus status;

  /// 执行结果
  final T? result;

  /// 错误信息
  final String? error;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime? endTime;

  /// 重试次数
  final int retryCount;

  const SagaStepResult({
    required this.stepId,
    required this.status,
    this.result,
    this.error,
    required this.startTime,
    this.endTime,
    this.retryCount = 0,
  });

  Duration? get duration => endTime?.difference(startTime);

  SagaStepResult<T> copyWith({
    SagaStepStatus? status,
    T? result,
    String? error,
    DateTime? endTime,
    int? retryCount,
  }) {
    return SagaStepResult<T>(
      stepId: stepId,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Saga事务实例
class SagaInstance {
  /// Saga ID
  final String id;

  /// Saga名称
  final String name;

  /// 状态
  SagaStatus status;

  /// 步骤结果
  final Map<String, SagaStepResult> stepResults;

  /// 上下文数据
  final Map<String, dynamic> context;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  /// 完成时间
  DateTime? completedAt;

  /// 当前步骤索引
  int currentStepIndex;

  /// 错误信息
  String? error;

  SagaInstance({
    required this.id,
    required this.name,
    this.status = SagaStatus.pending,
    Map<String, SagaStepResult>? stepResults,
    Map<String, dynamic>? context,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.currentStepIndex = 0,
    this.error,
  })  : stepResults = stepResults ?? {},
        context = context ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'currentStepIndex': currentStepIndex,
      'context': context,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'error': error,
    };
  }
}

/// Saga定义
class SagaDefinition {
  /// Saga名称
  final String name;

  /// 步骤列表
  final List<SagaStep> steps;

  /// 是否启用并行执行（无依赖的步骤）
  final bool enableParallelExecution;

  /// 补偿策略
  final CompensationStrategy compensationStrategy;

  /// 超时时间
  final Duration timeout;

  const SagaDefinition({
    required this.name,
    required this.steps,
    this.enableParallelExecution = false,
    this.compensationStrategy = CompensationStrategy.backward,
    this.timeout = const Duration(minutes: 5),
  });
}

/// 补偿策略
enum CompensationStrategy {
  /// 反向补偿（从最后一个成功步骤开始）
  backward,

  /// 全部补偿（补偿所有已执行步骤）
  all,

  /// 选择性补偿（只补偿关键步骤）
  selective,
}

/// Saga编排器
///
/// 实现Saga分布式事务模式：
/// 1. 编排式Saga（Orchestration）
/// 2. 自动补偿机制
/// 3. 失败重试
/// 4. 超时处理
///
/// 对应设计文档：第33章 分布式一致性设计
/// 代码块：433
class SagaOrchestrator extends ChangeNotifier {
  static final SagaOrchestrator _instance = SagaOrchestrator._();
  factory SagaOrchestrator() => _instance;
  SagaOrchestrator._();

  final Uuid _uuid = const Uuid();
  bool _initialized = false;

  // 已注册的Saga定义
  final Map<String, SagaDefinition> _definitions = {};

  // 活跃的Saga实例
  final Map<String, SagaInstance> _instances = {};

  // 历史记录（用于审计）
  final Queue<SagaInstance> _history = Queue();
  static const int _maxHistorySize = 1000;

  // 统计信息
  int _totalSagas = 0;
  int _completedSagas = 0;
  int _failedSagas = 0;
  int _compensatedSagas = 0;

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;

    // 注册预定义的Saga
    _registerBuiltInSagas();

    _initialized = true;

    if (kDebugMode) {
      debugPrint('SagaOrchestrator initialized');
    }
  }

  /// 注册Saga定义
  void registerSaga(SagaDefinition definition) {
    _definitions[definition.name] = definition;
  }

  /// 执行Saga
  Future<SagaInstance> execute(
    String sagaName, {
    Map<String, dynamic>? initialContext,
    String? sagaId,
  }) async {
    final definition = _definitions[sagaName];
    if (definition == null) {
      throw SagaNotFoundException(sagaName);
    }

    final instance = SagaInstance(
      id: sagaId ?? _uuid.v4(),
      name: sagaName,
      context: Map.from(initialContext ?? {}),
    );

    _instances[instance.id] = instance;
    _totalSagas++;

    try {
      await _executeSaga(instance, definition);
      return instance;
    } catch (e) {
      instance.error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// 获取Saga实例
  SagaInstance? getInstance(String sagaId) => _instances[sagaId];

  /// 获取统计信息
  SagaStats getStats() {
    return SagaStats(
      total: _totalSagas,
      completed: _completedSagas,
      failed: _failedSagas,
      compensated: _compensatedSagas,
      active: _instances.values
          .where((i) => i.status == SagaStatus.running ||
              i.status == SagaStatus.compensating)
          .length,
    );
  }

  // ==================== 内部执行逻辑 ====================

  Future<void> _executeSaga(
    SagaInstance instance,
    SagaDefinition definition,
  ) async {
    instance.status = SagaStatus.running;
    instance.updatedAt = DateTime.now();

    final completedSteps = <String, dynamic>{};

    try {
      // 执行超时保护
      await Future.any([
        _executeSteps(instance, definition, completedSteps),
        Future.delayed(definition.timeout).then((_) {
          throw TimeoutException('Saga execution timed out');
        }),
      ]);

      // 所有步骤成功
      instance.status = SagaStatus.completed;
      instance.completedAt = DateTime.now();
      _completedSagas++;

      if (kDebugMode) {
        debugPrint('Saga ${instance.id} completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Saga ${instance.id} failed: $e');
      }

      instance.error = e.toString();

      // 执行补偿
      await _compensate(instance, definition, completedSteps);
    }

    // 移至历史
    _instances.remove(instance.id);
    _addToHistory(instance);
  }

  Future<void> _executeSteps(
    SagaInstance instance,
    SagaDefinition definition,
    Map<String, dynamic> completedSteps,
  ) async {
    for (var i = 0; i < definition.steps.length; i++) {
      final step = definition.steps[i];
      instance.currentStepIndex = i;
      instance.updatedAt = DateTime.now();

      // 检查依赖
      if (!_checkDependencies(step, instance.stepResults)) {
        if (step.skippable) {
          instance.stepResults[step.id] = SagaStepResult(
            stepId: step.id,
            status: SagaStepStatus.skipped,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          );
          continue;
        } else {
          throw SagaDependencyException(step.id, step.dependsOn);
        }
      }

      // 执行步骤
      final result = await _executeStep(step, instance);
      instance.stepResults[step.id] = result;

      if (result.status == SagaStepStatus.completed) {
        completedSteps[step.id] = result.result;
        instance.context['_step_${step.id}_result'] = result.result;
      } else if (!step.skippable) {
        throw SagaStepFailedException(step.id, result.error);
      }
    }
  }

  Future<SagaStepResult> _executeStep(
    SagaStep step,
    SagaInstance instance,
  ) async {
    final startTime = DateTime.now();
    var retryCount = 0;

    while (retryCount <= step.maxRetries) {
      try {
        instance.stepResults[step.id] = SagaStepResult(
          stepId: step.id,
          status: SagaStepStatus.running,
          startTime: startTime,
          retryCount: retryCount,
        );

        final result = await step.execute(instance.context).timeout(step.timeout);

        return SagaStepResult(
          stepId: step.id,
          status: SagaStepStatus.completed,
          result: result,
          startTime: startTime,
          endTime: DateTime.now(),
          retryCount: retryCount,
        );
      } catch (e) {
        retryCount++;

        if (retryCount > step.maxRetries) {
          return SagaStepResult(
            stepId: step.id,
            status: SagaStepStatus.failed,
            error: e.toString(),
            startTime: startTime,
            endTime: DateTime.now(),
            retryCount: retryCount - 1,
          );
        }

        if (kDebugMode) {
          debugPrint('Step ${step.id} failed (attempt $retryCount): $e');
        }

        await Future.delayed(step.retryDelay * retryCount);
      }
    }

    return SagaStepResult(
      stepId: step.id,
      status: SagaStepStatus.failed,
      error: 'Max retries exceeded',
      startTime: startTime,
      endTime: DateTime.now(),
      retryCount: retryCount,
    );
  }

  bool _checkDependencies(SagaStep step, Map<String, SagaStepResult> results) {
    for (final depId in step.dependsOn) {
      final depResult = results[depId];
      if (depResult == null || depResult.status != SagaStepStatus.completed) {
        return false;
      }
    }
    return true;
  }

  Future<void> _compensate(
    SagaInstance instance,
    SagaDefinition definition,
    Map<String, dynamic> completedSteps,
  ) async {
    instance.status = SagaStatus.compensating;
    instance.updatedAt = DateTime.now();

    final stepsToCompensate = _getStepsToCompensate(
      definition,
      completedSteps.keys.toList(),
    );

    var compensationSuccess = true;

    for (final step in stepsToCompensate) {
      if (step.compensate == null) continue;

      final result = completedSteps[step.id];
      if (result == null) continue;

      try {
        final stepResult = instance.stepResults[step.id];
        if (stepResult != null) {
          instance.stepResults[step.id] = stepResult.copyWith(
            status: SagaStepStatus.compensating,
          );
        }

        await step.compensate!(result, instance.context);

        if (stepResult != null) {
          instance.stepResults[step.id] = stepResult.copyWith(
            status: SagaStepStatus.compensated,
          );
        }

        if (kDebugMode) {
          debugPrint('Compensated step ${step.id}');
        }
      } catch (e) {
        compensationSuccess = false;

        final stepResult = instance.stepResults[step.id];
        if (stepResult != null) {
          instance.stepResults[step.id] = stepResult.copyWith(
            status: SagaStepStatus.compensationFailed,
            error: e.toString(),
          );
        }

        if (kDebugMode) {
          debugPrint('Compensation failed for step ${step.id}: $e');
        }
      }
    }

    if (compensationSuccess) {
      instance.status = SagaStatus.compensated;
      _compensatedSagas++;
    } else {
      instance.status = SagaStatus.partiallyCompleted;
      _failedSagas++;
    }

    instance.completedAt = DateTime.now();
  }

  List<SagaStep> _getStepsToCompensate(
    SagaDefinition definition,
    List<String> completedStepIds,
  ) {
    switch (definition.compensationStrategy) {
      case CompensationStrategy.backward:
        // 反向顺序
        return definition.steps
            .where((s) => completedStepIds.contains(s.id) && s.compensate != null)
            .toList()
            .reversed
            .toList();

      case CompensationStrategy.all:
        // 所有已完成步骤
        return definition.steps
            .where((s) => completedStepIds.contains(s.id) && s.compensate != null)
            .toList()
            .reversed
            .toList();

      case CompensationStrategy.selective:
        // 只补偿关键步骤（有compensate方法的）
        return definition.steps
            .where((s) => completedStepIds.contains(s.id) && s.compensate != null)
            .toList()
            .reversed
            .toList();
    }
  }

  void _addToHistory(SagaInstance instance) {
    _history.add(instance);
    while (_history.length > _maxHistorySize) {
      _history.removeFirst();
    }
  }

  void _registerBuiltInSagas() {
    // 记账事务Saga
    registerSaga(SagaDefinition(
      name: 'transaction_create',
      steps: [
        SagaStep<String>(
          id: 'validate_input',
          name: '验证输入',
          execute: (ctx) async {
            // 验证交易数据
            return 'validated';
          },
        ),
        SagaStep<String>(
          id: 'check_balance',
          name: '检查余额',
          execute: (ctx) async {
            // 检查账户余额
            return 'balance_ok';
          },
          dependsOn: ['validate_input'],
        ),
        SagaStep<String>(
          id: 'create_transaction',
          name: '创建交易',
          execute: (ctx) async {
            // 创建交易记录
            return 'transaction_id';
          },
          compensate: (result, ctx) async {
            // 删除交易记录
          },
          dependsOn: ['check_balance'],
        ),
        SagaStep<String>(
          id: 'update_balance',
          name: '更新余额',
          execute: (ctx) async {
            // 更新账户余额
            return 'balance_updated';
          },
          compensate: (result, ctx) async {
            // 回滚余额
          },
          dependsOn: ['create_transaction'],
        ),
        SagaStep<String>(
          id: 'update_statistics',
          name: '更新统计',
          execute: (ctx) async {
            // 更新统计数据
            return 'stats_updated';
          },
          compensate: (result, ctx) async {
            // 回滚统计
          },
          dependsOn: ['update_balance'],
          skippable: true,
        ),
        SagaStep<String>(
          id: 'sync_to_server',
          name: '同步服务器',
          execute: (ctx) async {
            // 同步到服务器
            return 'synced';
          },
          dependsOn: ['update_balance'],
          skippable: true,
          maxRetries: 5,
        ),
      ],
    ));

    // 账单导入Saga
    registerSaga(SagaDefinition(
      name: 'bill_import',
      steps: [
        SagaStep<String>(
          id: 'parse_file',
          name: '解析文件',
          execute: (ctx) async => 'parsed',
        ),
        SagaStep<String>(
          id: 'detect_duplicates',
          name: '检测重复',
          execute: (ctx) async => 'duplicates_checked',
          dependsOn: ['parse_file'],
        ),
        SagaStep<String>(
          id: 'create_transactions',
          name: '创建交易',
          execute: (ctx) async => 'transactions_created',
          compensate: (result, ctx) async {
            // 删除导入的交易
          },
          dependsOn: ['detect_duplicates'],
        ),
        SagaStep<String>(
          id: 'update_categories',
          name: '更新分类',
          execute: (ctx) async => 'categories_updated',
          dependsOn: ['create_transactions'],
          skippable: true,
        ),
      ],
      timeout: const Duration(minutes: 10),
    ));
  }

  /// 关闭服务
  Future<void> close() async {
    _instances.clear();
    _history.clear();
    _initialized = false;
  }
}

/// Saga统计信息
class SagaStats {
  final int total;
  final int completed;
  final int failed;
  final int compensated;
  final int active;

  const SagaStats({
    required this.total,
    required this.completed,
    required this.failed,
    required this.compensated,
    required this.active,
  });

  double get successRate => total > 0 ? completed / total : 0.0;
}

/// Saga未找到异常
class SagaNotFoundException implements Exception {
  final String sagaName;

  SagaNotFoundException(this.sagaName);

  @override
  String toString() => 'SagaNotFoundException: Saga "$sagaName" not found';
}

/// Saga步骤失败异常
class SagaStepFailedException implements Exception {
  final String stepId;
  final String? error;

  SagaStepFailedException(this.stepId, this.error);

  @override
  String toString() => 'SagaStepFailedException: Step "$stepId" failed: $error';
}

/// Saga依赖异常
class SagaDependencyException implements Exception {
  final String stepId;
  final List<String> dependencies;

  SagaDependencyException(this.stepId, this.dependencies);

  @override
  String toString() =>
      'SagaDependencyException: Step "$stepId" dependencies not met: $dependencies';
}

/// 全局Saga编排器实例
final sagaOrchestrator = SagaOrchestrator();
