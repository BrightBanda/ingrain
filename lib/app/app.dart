import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/router.dart';
import 'package:ingrain/app/theme/app_theme.dart';
import 'package:ingrain/core/lifecycle.dart';

class IngrApp extends ConsumerWidget {
  const IngrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ThemeMode.system;
    final router = ref.watch(appRouterProvider);
    ref.watch(appLifecycleObserverProvider);

    return MaterialApp.router(
      title: 'ingrain',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
