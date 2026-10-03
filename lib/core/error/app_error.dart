class AppError {
  final AppErrorType type;
  final String? message;
  final Object? exception;

  const AppError({required this.type, this.message, this.exception});

  factory AppError.unknown(Object? exception, {String? message}) => AppError(
    type: AppErrorType.unknown,
    message: message,
    exception: exception,
  );

  @override
  String toString() => 'AppError(type: $type, message: $message)';
}

enum AppErrorType {
  auth,
  network,
  permission,
  notFound,
  validation,
  rateLimited,
  unknown,
}
