import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// 危险操作级别
enum DangerLevel {
  /// 低风险 - 可恢复
  low,

  /// 中风险 - 部分可恢复
  medium,

  /// 高风险 - 难以恢复
  high,

  /// 极高风险 - 不可恢复
  critical,
}

/// 操作类型
enum OperationType {
  /// 删除
  delete,

  /// 清空
  clear,

  /// 重置
  reset,

  /// 导出
  export,

  /// 导入（覆盖）
  importOverwrite,

  /// 批量操作
  batch,

  /// 账户操作
  account,

  /// 支付操作
  payment,

  /// 数据同步
  sync,

  /// 其他
  other,
}

/// 可撤销操作
class UndoableOperation {
  /// 操作ID
  final String id;

  /// 操作描述
  final String description;

  /// 操作类型
  final OperationType type;

  /// 危险级别
  final DangerLevel dangerLevel;

  /// 撤销回调
  final Future<bool> Function() onUndo;

  /// 重做回调
  final Future<bool> Function()? onRedo;

  /// 过期时间（毫秒）
  final int expireMs;

  /// 创建时间
  final DateTime createdAt;

  /// 是否已撤销
  bool isUndone;

  /// 操作数据（用于撤销时恢复）
  final dynamic data;

  UndoableOperation({
    required this.id,
    required this.description,
    required this.type,
    required this.onUndo,
    this.dangerLevel = DangerLevel.medium,
    this.onRedo,
    this.expireMs = 10000, // 默认10秒
    this.data,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        isUndone = false;

  /// 是否已过期
  bool get isExpired {
    return DateTime.now().difference(createdAt).inMilliseconds > expireMs;
  }

  /// 剩余撤销时间（毫秒）
  int get remainingMs {
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
    return (expireMs - elapsed).clamp(0, expireMs);
  }

  /// 剩余撤销时间（秒）
  double get remainingSeconds => remainingMs / 1000;
}

/// 确认对话框配置
class ConfirmationConfig {
  /// 标题
  final String title;

  /// 消息
  final String message;

  /// 危险级别
  final DangerLevel dangerLevel;

  /// 确认按钮文本
  final String confirmText;

  /// 取消按钮文本
  final String cancelText;

  /// 是否需要输入确认文本
  final bool requireTextConfirmation;

  /// 需要输入的确认文本
  final String? confirmationText;

  /// 提示输入的文本
  final String? confirmationHint;

  /// 确认倒计时（秒，0表示不需要）
  final int confirmDelay;

  /// 是否可撤销
  final bool canUndo;

  /// 撤销时间（毫秒）
  final int undoTimeMs;

  const ConfirmationConfig({
    required this.title,
    required this.message,
    this.dangerLevel = DangerLevel.medium,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.requireTextConfirmation = false,
    this.confirmationText,
    this.confirmationHint,
    this.confirmDelay = 0,
    this.canUndo = true,
    this.undoTimeMs = 10000,
  });

  /// 删除确认配置
  factory ConfirmationConfig.delete({
    required String itemName,
    bool canUndo = true,
  }) {
    return ConfirmationConfig(
      title: '确认删除',
      message: '确定要删除"$itemName"吗？${canUndo ? '此操作可在10秒内撤销。' : '此操作不可撤销。'}',
      dangerLevel: canUndo ? DangerLevel.medium : DangerLevel.high,
      confirmText: '删除',
      canUndo: canUndo,
    );
  }

  /// 批量删除确认配置
  factory ConfirmationConfig.batchDelete({
    required int count,
    bool canUndo = false,
  }) {
    return ConfirmationConfig(
      title: '确认批量删除',
      message: '确定要删除选中的$count项吗？${canUndo ? '此操作可撤销。' : '此操作不可撤销！'}',
      dangerLevel: DangerLevel.high,
      confirmText: '删除全部',
      confirmDelay: 3,
      canUndo: canUndo,
    );
  }

  /// 清空数据确认配置
  factory ConfirmationConfig.clearAll({
    required String dataType,
  }) {
    return ConfirmationConfig(
      title: '确认清空',
      message: '确定要清空所有$dataType吗？此操作不可撤销！',
      dangerLevel: DangerLevel.critical,
      confirmText: '清空全部',
      requireTextConfirmation: true,
      confirmationText: '清空',
      confirmationHint: '请输入"清空"以确认',
      confirmDelay: 5,
      canUndo: false,
    );
  }

  /// 重置确认配置
  factory ConfirmationConfig.reset({
    required String targetName,
  }) {
    return ConfirmationConfig(
      title: '确认重置',
      message: '确定要重置$targetName吗？所有自定义设置将丢失。',
      dangerLevel: DangerLevel.high,
      confirmText: '重置',
      confirmDelay: 3,
      canUndo: false,
    );
  }

  /// 账户操作确认配置
  factory ConfirmationConfig.accountOperation({
    required String operation,
  }) {
    return ConfirmationConfig(
      title: '确认$operation',
      message: '确定要$operation吗？此操作将影响您的账户数据。',
      dangerLevel: DangerLevel.critical,
      confirmText: '确认$operation',
      requireTextConfirmation: true,
      confirmationText: '确认',
      confirmationHint: '请输入"确认"以继续',
      confirmDelay: 5,
      canUndo: false,
    );
  }
}

/// 危险操作服务
/// 提供危险操作的确认机制和撤销功能，确保用户不会误操作
class DangerousOperationService {
  static final DangerousOperationService _instance =
      DangerousOperationService._internal();
  factory DangerousOperationService() => _instance;
  DangerousOperationService._internal();

  /// 可撤销操作栈
  final List<UndoableOperation> _undoStack = [];

  /// 重做栈
  final List<UndoableOperation> _redoStack = [];

  /// 最大撤销栈大小
  static const int _maxUndoStackSize = 20;

  /// 操作变更监听器
  final List<void Function()> _listeners = [];

  /// 当前显示的撤销提示Timer
  Timer? _undoToastTimer;

  /// 撤销提示控制器
  final StreamController<UndoableOperation?> _undoToastController =
      StreamController<UndoableOperation?>.broadcast();

  /// 撤销提示流
  Stream<UndoableOperation?> get undoToastStream => _undoToastController.stream;

  /// 获取可撤销操作列表
  List<UndoableOperation> get undoStack =>
      _undoStack.where((op) => !op.isExpired && !op.isUndone).toList();

  /// 是否有可撤销操作
  bool get canUndo => undoStack.isNotEmpty;

  /// 是否有可重做操作
  bool get canRedo => _redoStack.isNotEmpty;

  /// 最近的可撤销操作
  UndoableOperation? get latestUndoable =>
      undoStack.isNotEmpty ? undoStack.last : null;

  // ==================== 确认对话框 ====================

  /// 显示确认对话框
  Future<bool> showConfirmation(
    BuildContext context,
    ConfirmationConfig config,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConfirmationDialog(config: config),
    );
    return result ?? false;
  }

  /// 执行需要确认的操作
  Future<T?> executeWithConfirmation<T>(
    BuildContext context, {
    required ConfirmationConfig config,
    required Future<T> Function() operation,
    Future<bool> Function()? onUndo,
    dynamic undoData,
  }) async {
    final confirmed = await showConfirmation(context, config);
    if (!confirmed) return null;

    final result = await operation();

    // 如果可撤销，添加到撤销栈
    if (config.canUndo && onUndo != null) {
      final undoOp = UndoableOperation(
        id: 'op_${DateTime.now().millisecondsSinceEpoch}',
        description: config.title,
        type: _getOperationType(config),
        dangerLevel: config.dangerLevel,
        onUndo: onUndo,
        expireMs: config.undoTimeMs,
        data: undoData,
      );
      pushUndoOperation(undoOp);
      _showUndoToast(undoOp);
    }

    return result;
  }

  OperationType _getOperationType(ConfirmationConfig config) {
    final title = config.title.toLowerCase();
    if (title.contains('删除')) return OperationType.delete;
    if (title.contains('清空')) return OperationType.clear;
    if (title.contains('重置')) return OperationType.reset;
    if (title.contains('导出')) return OperationType.export;
    if (title.contains('导入')) return OperationType.importOverwrite;
    if (title.contains('账户')) return OperationType.account;
    return OperationType.other;
  }

  // ==================== 撤销/重做操作 ====================

  /// 添加可撤销操作
  void pushUndoOperation(UndoableOperation operation) {
    // 清理过期操作
    _undoStack.removeWhere((op) => op.isExpired || op.isUndone);

    // 添加新操作
    _undoStack.add(operation);

    // 清空重做栈
    _redoStack.clear();

    // 限制栈大小
    while (_undoStack.length > _maxUndoStackSize) {
      _undoStack.removeAt(0);
    }

    _notifyListeners();
  }

  /// 撤销最近的操作
  Future<bool> undo() async {
    final op = latestUndoable;
    if (op == null) return false;

    try {
      final success = await op.onUndo();
      if (success) {
        op.isUndone = true;
        _redoStack.add(op);
        _hideUndoToast();
        _notifyListeners();

        // 播报撤销成功
        SemanticsService.announce('已撤销：${op.description}', TextDirection.ltr);
        return true;
      }
    } catch (e) {
      debugPrint('Undo failed: $e');
    }

    return false;
  }

  /// 重做操作
  Future<bool> redo() async {
    if (_redoStack.isEmpty) return false;

    final op = _redoStack.removeLast();
    if (op.onRedo == null) return false;

    try {
      final success = await op.onRedo!();
      if (success) {
        op.isUndone = false;
        _undoStack.add(op);
        _notifyListeners();

        // 播报重做成功
        SemanticsService.announce('已重做：${op.description}', TextDirection.ltr);
        return true;
      }
    } catch (e) {
      debugPrint('Redo failed: $e');
    }

    return false;
  }

  /// 清空撤销栈
  void clearUndoStack() {
    _undoStack.clear();
    _redoStack.clear();
    _hideUndoToast();
    _notifyListeners();
  }

  // ==================== 撤销提示 ====================

  /// 显示撤销提示
  void _showUndoToast(UndoableOperation operation) {
    _undoToastTimer?.cancel();
    _undoToastController.add(operation);

    // 设置自动隐藏
    _undoToastTimer = Timer(
      Duration(milliseconds: operation.expireMs),
      _hideUndoToast,
    );
  }

  /// 隐藏撤销提示
  void _hideUndoToast() {
    _undoToastTimer?.cancel();
    _undoToastTimer = null;
    _undoToastController.add(null);
  }

  // ==================== 监听器 ====================

  /// 添加监听器
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // ==================== 清理 ====================

  /// 释放资源
  void dispose() {
    _undoToastTimer?.cancel();
    _undoToastController.close();
    _listeners.clear();
  }
}

/// 确认对话框组件
class _ConfirmationDialog extends StatefulWidget {
  final ConfirmationConfig config;

  const _ConfirmationDialog({required this.config});

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  final _textController = TextEditingController();
  int _remainingDelay = 0;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _remainingDelay = widget.config.confirmDelay;
    if (_remainingDelay > 0) {
      _startDelayTimer();
    }
  }

  void _startDelayTimer() {
    _delayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingDelay--;
        if (_remainingDelay <= 0) {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _delayTimer?.cancel();
    super.dispose();
  }

  bool get _canConfirm {
    if (_remainingDelay > 0) return false;
    if (widget.config.requireTextConfirmation) {
      return _textController.text == widget.config.confirmationText;
    }
    return true;
  }

  Color _getDangerColor() {
    switch (widget.config.dangerLevel) {
      case DangerLevel.low:
        return Colors.blue;
      case DangerLevel.medium:
        return Colors.orange;
      case DangerLevel.high:
        return Colors.red;
      case DangerLevel.critical:
        return Colors.red.shade900;
    }
  }

  IconData _getDangerIcon() {
    switch (widget.config.dangerLevel) {
      case DangerLevel.low:
        return Icons.info_outline;
      case DangerLevel.medium:
        return Icons.warning_amber;
      case DangerLevel.high:
        return Icons.warning;
      case DangerLevel.critical:
        return Icons.dangerous;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dangerColor = _getDangerColor();

    return AlertDialog(
      title: Row(
        children: [
          Icon(_getDangerIcon(), color: dangerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.config.title,
              style: TextStyle(color: dangerColor),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(widget.config.message),
          ),
          if (widget.config.requireTextConfirmation) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: widget.config.confirmationHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              autofocus: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.config.cancelText),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _remainingDelay > 0
                ? '${widget.config.confirmText} ($_remainingDelay)'
                : widget.config.confirmText,
          ),
        ),
      ],
    );
  }
}

/// 撤销提示条组件
class UndoSnackBar extends StatefulWidget {
  final UndoableOperation operation;
  final VoidCallback onUndo;
  final VoidCallback? onDismiss;

  const UndoSnackBar({
    super.key,
    required this.operation,
    required this.onUndo,
    this.onDismiss,
  });

  @override
  State<UndoSnackBar> createState() => _UndoSnackBarState();
}

class _UndoSnackBarState extends State<UndoSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.operation.expireMs),
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${widget.operation.description}已完成，点击撤销按钮可撤销',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  widget.operation.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: widget.onUndo,
                child: const Text('撤销'),
              ),
              if (widget.onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 撤销提示覆盖层
class UndoOverlay extends StatelessWidget {
  final Widget child;

  const UndoOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final service = DangerousOperationService();

    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: StreamBuilder<UndoableOperation?>(
            stream: service.undoToastStream,
            builder: (context, snapshot) {
              final operation = snapshot.data;
              if (operation == null) {
                return const SizedBox.shrink();
              }

              return UndoSnackBar(
                operation: operation,
                onUndo: () => service.undo(),
              );
            },
          ),
        ),
      ],
    );
  }
}
