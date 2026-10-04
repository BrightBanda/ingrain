import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a screen that sits at the bottom of the navigation stack.
///
/// The system back button never pops such a screen. The first press only
/// raises a hint, and the app closes when back is pressed again while that
/// hint is still on screen. Screens that were pushed on top keep their own
/// back behaviour, because a [PopScope] only vetoes pops on its own route.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child});

  final Widget child;

  /// How long the first press stays armed before the hint is forgotten.
  static const promptDuration = Duration(seconds: 2);

  static const message = 'Press back again to exit';

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  Timer? _armedTimer;

  @override
  void dispose() {
    _armedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }

  void _handleBack() {
    if (_armedTimer?.isActive ?? false) {
      _armedTimer!.cancel();
      _armedTimer = null;
      SystemNavigator.pop();
      return;
    }

    _armedTimer = Timer(DoubleBackToExit.promptDuration, () {
      _armedTimer = null;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(DoubleBackToExit.message),
        duration: DoubleBackToExit.promptDuration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
