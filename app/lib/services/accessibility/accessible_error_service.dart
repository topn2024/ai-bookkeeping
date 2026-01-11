import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// 错误严重级别
enum ErrorSeverity {
  /// 信息 - 不影响操作
  info,

  /// 警告 - 可能影响操作
  warning,

  /// 错误 - 影响当前操作
  error,

  /// 严重 - 需要立即处理
  critical,
}

/// 错误类型
enum ErrorType {
  /// 验证错误
  validation,

  /// 网络错误
  network,

  /// 权限错误
  permission,

  /// 数据错误
  data,

  /// 系统错误
  system,

  /// 业务错误
  business,

  /// 输入错误
  input,
}

/// 错误上下文
class ErrorContext {
  /// 错误发生的字段/组件ID
  final String? fieldId;

  /// 错误发生的表单ID
  final String? formId;

  /// 错误发生的页面路由
  final String? route;

  /// 额外数据
  final Map<String, dynamic>? extra;

  const ErrorContext({
    this.fieldId,
    this.formId,
    this.route,
    this.extra,
  });
}

/// 无障碍错误信息
class AccessibleError {
  /// 错误ID（用于关联）
  final String id;

  /// 错误消息（用户可读）
  final String message;

  /// 详细描述
  final String? description;

  /// 解决建议
  final List<String> suggestions;

  /// 错误类型
  final ErrorType type;

  /// 严重级别
  final ErrorSeverity severity;

  /// 错误上下文
  final ErrorContext? context;

  /// 关联的字段FocusNode
  final FocusNode? focusNode;

  /// 是否可恢复
  final bool recoverable;

  /// 恢复操作回调
  final VoidCallback? onRecover;

  /// 创建时间
  final DateTime createdAt;

  AccessibleError({
    required this.id,
    required this.message,
    this.description,
    this.suggestions = const [],
    this.type = ErrorType.validation,
    this.severity = ErrorSeverity.error,
    this.context,
    this.focusNode,
    this.recoverable = false,
    this.onRecover,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取完整的语义化错误消息
  String get semanticMessage {
    final parts = <String>[];

    // 严重级别前缀
    switch (severity) {
      case ErrorSeverity.critical:
        parts.add('严重错误');
        break;
      case ErrorSeverity.error:
        parts.add('错误');
        break;
      case ErrorSeverity.warning:
        parts.add('警告');
        break;
      case ErrorSeverity.info:
        parts.add('提示');
        break;
    }

    // 主消息
    parts.add(message);

    // 详细描述
    if (description != null && description!.isNotEmpty) {
      parts.add(description!);
    }

    // 建议
    if (suggestions.isNotEmpty) {
      parts.add('建议：${suggestions.first}');
    }

    return parts.join('，');
  }

  /// 获取简短消息
  String get shortMessage => message;

  /// 获取第一个建议
  String? get primarySuggestion =>
      suggestions.isNotEmpty ? suggestions.first : null;
}

/// 表单验证结果
class FormValidationResult {
  /// 是否有效
  final bool isValid;

  /// 错误列表
  final List<AccessibleError> errors;

  /// 警告列表
  final List<AccessibleError> warnings;

  const FormValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// 获取所有问题
  List<AccessibleError> get allIssues => [...errors, ...warnings];

  /// 获取第一个错误
  AccessibleError? get firstError => errors.isNotEmpty ? errors.first : null;

  /// 获取总结消息
  String get summaryMessage {
    if (isValid) {
      return '验证通过';
    }

    final errorCount = errors.length;
    final warningCount = warnings.length;

    if (errorCount > 0 && warningCount > 0) {
      return '发现$errorCount个错误和$warningCount个警告';
    } else if (errorCount > 0) {
      return '发现$errorCount个错误';
    } else {
      return '发现$warningCount个警告';
    }
  }
}

/// 无障碍错误服务
/// 提供清晰、可访问的错误提示，确保所有用户都能理解和处理错误
class AccessibleErrorService {
  static final AccessibleErrorService _instance =
      AccessibleErrorService._internal();
  factory AccessibleErrorService() => _instance;
  AccessibleErrorService._internal();

  /// 当前活动错误
  final Map<String, AccessibleError> _activeErrors = {};

  /// 表单错误
  final Map<String, Map<String, AccessibleError>> _formErrors = {};

  /// 错误变更监听器
  final List<void Function(List<AccessibleError>)> _errorListeners = [];

  /// 是否自动播报错误
  bool autoAnnounce = true;

  /// 播报延迟（毫秒）
  final int _announceDelay = 100;

  /// 获取所有活动错误
  List<AccessibleError> get activeErrors => _activeErrors.values.toList();

  /// 获取按严重级别排序的错误
  List<AccessibleError> get sortedErrors {
    final errors = activeErrors;
    errors.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return errors;
  }

  // ==================== 错误管理 ====================

  /// 添加错误
  void addError(AccessibleError error) {
    _activeErrors[error.id] = error;
    _notifyListeners();

    if (autoAnnounce) {
      _announceError(error);
    }
  }

  /// 移除错误
  void removeError(String errorId) {
    _activeErrors.remove(errorId);
    _notifyListeners();
  }

  /// 清除所有错误
  void clearErrors() {
    _activeErrors.clear();
    _notifyListeners();
  }

  /// 清除特定类型的错误
  void clearErrorsByType(ErrorType type) {
    _activeErrors.removeWhere((_, error) => error.type == type);
    _notifyListeners();
  }

  /// 清除特定上下文的错误
  void clearErrorsByContext({String? fieldId, String? formId}) {
    _activeErrors.removeWhere((_, error) {
      if (fieldId != null && error.context?.fieldId == fieldId) {
        return true;
      }
      if (formId != null && error.context?.formId == formId) {
        return true;
      }
      return false;
    });
    _notifyListeners();
  }

  /// 获取特定字段的错误
  AccessibleError? getFieldError(String fieldId) {
    try {
      return _activeErrors.values
          .firstWhere((e) => e.context?.fieldId == fieldId);
    } catch (_) {
      return null;
    }
  }

  /// 检查是否有错误
  bool hasErrors({ErrorSeverity? minSeverity}) {
    if (minSeverity == null) {
      return _activeErrors.isNotEmpty;
    }
    return _activeErrors.values
        .any((e) => e.severity.index >= minSeverity.index);
  }

  // ==================== 表单验证 ====================

  /// 设置表单错误
  void setFormErrors(String formId, List<AccessibleError> errors) {
    _formErrors[formId] = {for (var e in errors) e.context?.fieldId ?? e.id: e};
    _notifyListeners();

    if (autoAnnounce && errors.isNotEmpty) {
      _announceFormErrors(formId, errors);
    }
  }

  /// 设置字段错误
  void setFieldError(String formId, String fieldId, AccessibleError? error) {
    _formErrors.putIfAbsent(formId, () => {});

    if (error != null) {
      _formErrors[formId]![fieldId] = error;
      if (autoAnnounce) {
        _announceError(error);
      }
    } else {
      _formErrors[formId]!.remove(fieldId);
    }

    _notifyListeners();
  }

  /// 获取表单错误
  List<AccessibleError> getFormErrors(String formId) {
    return _formErrors[formId]?.values.toList() ?? [];
  }

  /// 获取字段错误
  AccessibleError? getFormFieldError(String formId, String fieldId) {
    return _formErrors[formId]?[fieldId];
  }

  /// 清除表单错误
  void clearFormErrors(String formId) {
    _formErrors.remove(formId);
    _notifyListeners();
  }

  /// 验证表单并返回结果
  FormValidationResult validateForm(
    String formId,
    Map<String, String?> validators,
  ) {
    final errors = <AccessibleError>[];
    final warnings = <AccessibleError>[];

    for (final entry in validators.entries) {
      final fieldId = entry.key;
      final errorMessage = entry.value;

      if (errorMessage != null) {
        final error = AccessibleError(
          id: '${formId}_$fieldId',
          message: errorMessage,
          type: ErrorType.validation,
          severity: ErrorSeverity.error,
          context: ErrorContext(fieldId: fieldId, formId: formId),
        );
        errors.add(error);
      }
    }

    setFormErrors(formId, errors);

    return FormValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  // ==================== 错误播报 ====================

  /// 播报错误
  void _announceError(AccessibleError error) {
    Future.delayed(Duration(milliseconds: _announceDelay), () {
      SemanticsService.announce(error.semanticMessage, TextDirection.ltr);
    });
  }

  /// 播报表单错误
  void _announceFormErrors(String formId, List<AccessibleError> errors) {
    if (errors.isEmpty) return;

    Future.delayed(Duration(milliseconds: _announceDelay), () {
      final message = errors.length == 1
          ? errors.first.semanticMessage
          : '表单验证失败，共${errors.length}个错误。第一个错误：${errors.first.message}';

      SemanticsService.announce(message, TextDirection.ltr);
    });
  }

  /// 手动播报消息
  void announce(String message, {ErrorSeverity? severity}) {
    String prefix = '';
    if (severity != null) {
      switch (severity) {
        case ErrorSeverity.critical:
          prefix = '严重错误，';
          break;
        case ErrorSeverity.error:
          prefix = '错误，';
          break;
        case ErrorSeverity.warning:
          prefix = '警告，';
          break;
        case ErrorSeverity.info:
          prefix = '提示，';
          break;
      }
    }
    SemanticsService.announce('$prefix$message', TextDirection.ltr);
  }

  // ==================== 焦点管理 ====================

  /// 聚焦到第一个错误字段
  bool focusFirstError() {
    final errors = sortedErrors;
    if (errors.isEmpty) return false;

    final firstError = errors.first;
    if (firstError.focusNode != null && firstError.focusNode!.canRequestFocus) {
      firstError.focusNode!.requestFocus();
      return true;
    }

    return false;
  }

  /// 聚焦到特定错误字段
  bool focusError(String errorId) {
    final error = _activeErrors[errorId];
    if (error?.focusNode != null && error!.focusNode!.canRequestFocus) {
      error.focusNode!.requestFocus();
      return true;
    }
    return false;
  }

  /// 聚焦到表单的第一个错误
  bool focusFirstFormError(String formId) {
    final errors = getFormErrors(formId);
    if (errors.isEmpty) return false;

    final firstError = errors.first;
    if (firstError.focusNode != null && firstError.focusNode!.canRequestFocus) {
      firstError.focusNode!.requestFocus();
      return true;
    }

    return false;
  }

  // ==================== 监听器 ====================

  /// 添加错误监听器
  void addErrorListener(void Function(List<AccessibleError>) listener) {
    _errorListeners.add(listener);
  }

  /// 移除错误监听器
  void removeErrorListener(void Function(List<AccessibleError>) listener) {
    _errorListeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    final allErrors = [...activeErrors];
    for (final formErrors in _formErrors.values) {
      allErrors.addAll(formErrors.values);
    }

    for (final listener in _errorListeners) {
      listener(allErrors);
    }
  }

  // ==================== 错误消息生成 ====================

  /// 生成验证错误消息
  static AccessibleError validationError({
    required String fieldId,
    required String message,
    String? formId,
    List<String> suggestions = const [],
    FocusNode? focusNode,
  }) {
    return AccessibleError(
      id: '${formId ?? 'field'}_$fieldId',
      message: message,
      type: ErrorType.validation,
      severity: ErrorSeverity.error,
      suggestions: suggestions,
      context: ErrorContext(fieldId: fieldId, formId: formId),
      focusNode: focusNode,
    );
  }

  /// 生成网络错误消息
  static AccessibleError networkError({
    required String message,
    String? description,
    bool recoverable = true,
    VoidCallback? onRetry,
  }) {
    return AccessibleError(
      id: 'network_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      description: description,
      type: ErrorType.network,
      severity: ErrorSeverity.error,
      suggestions: recoverable ? ['请检查网络连接后重试'] : [],
      recoverable: recoverable,
      onRecover: onRetry,
    );
  }

  /// 生成权限错误消息
  static AccessibleError permissionError({
    required String permission,
    required String message,
    VoidCallback? onRequestPermission,
  }) {
    return AccessibleError(
      id: 'permission_$permission',
      message: message,
      type: ErrorType.permission,
      severity: ErrorSeverity.warning,
      suggestions: ['请在设置中授予相应权限'],
      recoverable: true,
      onRecover: onRequestPermission,
    );
  }

  /// 生成必填字段错误
  static AccessibleError requiredFieldError({
    required String fieldId,
    required String fieldName,
    String? formId,
    FocusNode? focusNode,
  }) {
    return validationError(
      fieldId: fieldId,
      message: '$fieldName不能为空',
      formId: formId,
      suggestions: ['请输入$fieldName'],
      focusNode: focusNode,
    );
  }

  /// 生成格式错误
  static AccessibleError formatError({
    required String fieldId,
    required String fieldName,
    required String expectedFormat,
    String? formId,
    FocusNode? focusNode,
  }) {
    return validationError(
      fieldId: fieldId,
      message: '$fieldName格式不正确',
      formId: formId,
      suggestions: ['请输入正确的$expectedFormat格式'],
      focusNode: focusNode,
    );
  }

  /// 生成范围错误
  static AccessibleError rangeError({
    required String fieldId,
    required String fieldName,
    double? min,
    double? max,
    String? formId,
    FocusNode? focusNode,
  }) {
    String message;
    String suggestion;

    if (min != null && max != null) {
      message = '$fieldName必须在$min到$max之间';
      suggestion = '请输入$min到$max之间的值';
    } else if (min != null) {
      message = '$fieldName不能小于$min';
      suggestion = '请输入不小于$min的值';
    } else if (max != null) {
      message = '$fieldName不能大于$max';
      suggestion = '请输入不大于$max的值';
    } else {
      message = '$fieldName超出有效范围';
      suggestion = '请输入有效的值';
    }

    return validationError(
      fieldId: fieldId,
      message: message,
      formId: formId,
      suggestions: [suggestion],
      focusNode: focusNode,
    );
  }
}

/// 错误提示组件
class AccessibleErrorWidget extends StatelessWidget {
  final AccessibleError error;
  final bool showSuggestions;
  final bool showDescription;
  final VoidCallback? onDismiss;
  final VoidCallback? onRecover;

  const AccessibleErrorWidget({
    super.key,
    required this.error,
    this.showSuggestions = true,
    this.showDescription = false,
    this.onDismiss,
    this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    IconData icon;

    switch (error.severity) {
      case ErrorSeverity.critical:
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        iconColor = Colors.red.shade700;
        icon = Icons.error;
        break;
      case ErrorSeverity.error:
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade600;
        icon = Icons.error_outline;
        break;
      case ErrorSeverity.warning:
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        iconColor = Colors.orange.shade700;
        icon = Icons.warning_amber;
        break;
      case ErrorSeverity.info:
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        iconColor = Colors.blue.shade700;
        icon = Icons.info_outline;
        break;
    }

    return Semantics(
      liveRegion: true,
      label: error.semanticMessage,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (showDescription &&
                      error.description != null &&
                      error.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      error.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: iconColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (showSuggestions && error.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...error.suggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(color: iconColor),
                              ),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: iconColor.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (error.recoverable &&
                      (error.onRecover != null || onRecover != null)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRecover ?? error.onRecover,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重试'),
                      style: TextButton.styleFrom(
                        foregroundColor: iconColor,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: iconColor, size: 18),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '关闭',
              ),
          ],
        ),
      ),
    );
  }
}

/// 表单字段错误提示组件
class FieldErrorText extends StatelessWidget {
  final String? errorMessage;
  final String? suggestion;

  const FieldErrorText({
    super.key,
    this.errorMessage,
    this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 2),
              Text(
                suggestion!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
