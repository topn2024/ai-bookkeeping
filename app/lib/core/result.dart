/// 统一的操作结果类型
/// 用于替代异常处理，提供类型安全的错误处理机制
sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(AppError error) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T> s => s.data,
        Failure<T> _ => null,
      };

  AppError? get errorOrNull => switch (this) {
        Success<T> _ => null,
        Failure<T> f => f.error,
      };

  /// 模式匹配处理结果
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) =>
      switch (this) {
        Success<T> s => success(s.data),
        Failure<T> f => failure(f.error),
      };

  /// 成功时转换数据
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success<T> s => Result.success(transform(s.data)),
        Failure<T> f => Result.failure(f.error),
      };

  /// 成功时异步转换数据
  Future<Result<R>> mapAsync<R>(Future<R> Function(T data) transform) async =>
      switch (this) {
        Success<T> s => Result.success(await transform(s.data)),
        Failure<T> f => Result.failure(f.error),
      };

  /// 获取数据或抛出异常
  T getOrThrow() => switch (this) {
        Success<T> s => s.data,
        Failure<T> f => throw f.error,
      };

  /// 获取数据或返回默认值
  T getOrElse(T defaultValue) => switch (this) {
        Success<T> s => s.data,
        Failure<T> _ => defaultValue,
      };
}

/// 成功结果
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success($data)';
}

/// 失败结果
class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}

/// 统一错误基类
sealed class AppError implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// 网络错误
class NetworkError extends AppError {
  final int? statusCode;
  final String? responseBody;

  const NetworkError(
    super.message, {
    this.statusCode,
    this.responseBody,
    super.cause,
    super.stackTrace,
  });

  bool get isTimeout => statusCode == null && message.contains('timeout');
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// 数据库错误
class DatabaseError extends AppError {
  final String? operation;
  final String? table;

  const DatabaseError(
    super.message, {
    this.operation,
    this.table,
    super.cause,
    super.stackTrace,
  });
}

/// 验证错误
class ValidationError extends AppError {
  final Map<String, String>? fieldErrors;

  const ValidationError(
    super.message, {
    this.fieldErrors,
    super.cause,
    super.stackTrace,
  });

  bool hasFieldError(String field) => fieldErrors?.containsKey(field) ?? false;
  String? getFieldError(String field) => fieldErrors?[field];
}

/// 认证错误
class AuthError extends AppError {
  final bool isTokenExpired;
  final bool requiresLogin;

  const AuthError(
    super.message, {
    this.isTokenExpired = false,
    this.requiresLogin = false,
    super.cause,
    super.stackTrace,
  });
}

/// 资源未找到错误
class NotFoundError extends AppError {
  final String? resourceType;
  final String? resourceId;

  const NotFoundError(
    super.message, {
    this.resourceType,
    this.resourceId,
    super.cause,
    super.stackTrace,
  });
}

/// 业务逻辑错误
class BusinessError extends AppError {
  final String? code;

  const BusinessError(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });
}

/// 未知错误
class UnknownError extends AppError {
  const UnknownError(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  factory UnknownError.fromException(Object e, [StackTrace? st]) {
    return UnknownError(e.toString(), cause: e, stackTrace: st);
  }
}

/// Result 扩展方法
extension ResultExtensions<T> on Future<T> {
  /// 将 Future 转换为 Result
  Future<Result<T>> toResult() async {
    try {
      return Result.success(await this);
    } catch (e, st) {
      if (e is AppError) {
        return Result.failure(e);
      }
      return Result.failure(UnknownError.fromException(e, st));
    }
  }
}

/// 错误映射工具
class ErrorMapper {
  /// 将任意异常映射为 AppError
  static AppError mapException(Object e, [StackTrace? st]) {
    if (e is AppError) return e;

    final message = e.toString();

    // 网络相关错误
    if (message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('DioException')) {
      return NetworkError(message, cause: e, stackTrace: st);
    }

    // 数据库相关错误
    if (message.contains('DatabaseException') ||
        message.contains('SqliteException')) {
      return DatabaseError(message, cause: e, stackTrace: st);
    }

    return UnknownError(message, cause: e, stackTrace: st);
  }
}
