import 'package:flutter/material.dart';
import 'package:ingrain/core/error/app_error.dart';

enum AsyncStateStatus { loading, empty, error, success }

class AsyncStateView<T> extends StatelessWidget {
  final AsyncStateStatus status;
  final T? data;
  final AppError? error;
  final Widget Function(BuildContext context, T data) builder;
  final String? emptyMessage;

  const AsyncStateView({
    super.key,
    required this.status,
    this.data,
    this.error,
    required this.builder,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AsyncStateStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AsyncStateStatus.error:
        return _buildError(context);
      case AsyncStateStatus.empty:
        return _buildEmpty(context);
      case AsyncStateStatus.success:
        if (data is List && (data as List).isEmpty) {
          return _buildEmpty(context);
        }
        return builder(context, data as T);
    }
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              error?.message ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No data available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
