import 'package:ingrain/core/error/app_error.dart';

class Result<T> {
  final T? value;
  final AppError? error;

  const Result.success(this.value) : error = null;

  const Result.failure(this.error) : value = null;

  bool get isSuccess => error == null;

  bool get isFailure => error != null;

  R fold<R>(R Function(AppError) onFailure, R Function(T) onSuccess) {
    if (isFailure) {
      return onFailure(error!);
    }
    return onSuccess(value as T);
  }
}
