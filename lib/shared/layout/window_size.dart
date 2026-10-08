import 'package:flutter/material.dart';

/// How much room the app has, after Material 3's window size classes.
///
/// Phones and small tablets stay [compact]: the app was designed for them and
/// keeps its bottom bar. Wider windows get a side rail ([medium]) or a full
/// sidebar ([expanded]) and multi-column screens.
enum WindowSize {
  compact,
  medium,
  expanded;

  static const mediumMinWidth = 840.0;
  static const expandedMinWidth = 1280.0;

  static WindowSize of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static WindowSize forWidth(double width) {
    if (width >= expandedMinWidth) return WindowSize.expanded;
    if (width >= mediumMinWidth) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => this == WindowSize.compact;
}

/// Caps [child] at [maxWidth] and centres it, so wide windows get comfortable
/// line lengths instead of content stretched edge to edge. On narrower
/// windows it does nothing.
class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidth({super.key, required this.maxWidth, required this.child});

  /// Reading width: forms, lists and single-column pages.
  static const reading = 760.0;

  /// Page width: multi-column pages inside the app's frame.
  static const page = 1240.0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A full-screen page whose content is capped at [maxWidth]: the background
/// fills the window and the content sits centred on it. For pages pushed
/// over the main frame (study, editors, search), which have no frame of
/// their own to paint the margins.
class PageFrame extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const PageFrame({
    super.key,
    this.maxWidth = MaxWidth.reading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: MaxWidth(maxWidth: maxWidth, child: child),
    );
  }
}
