import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

// The building blocks of the app's look: colour fills instead of outlines,
// one accent hue per kind of thing (see `AppColors`), and gradient heroes.

/// A rounded, borderless surface tinted with [color]. Tappable when [onTap]
/// or [onLongPress] is set.
class TintedSurface extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double alpha;

  const TintedSurface({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.alpha = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
  }
}

/// A rounded square holding an icon (or [child]), tinted or [solid].
class IconBadge extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final Widget? child;
  final double size;
  final bool solid;

  const IconBadge({
    super.key,
    required this.color,
    this.icon,
    this.child,
    this.size = 44,
    this.solid = false,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child:
          child ??
          Icon(icon, color: solid ? Colors.white : color, size: size * 0.52),
    );
  }
}

/// The hero treatment: a rounded gradient panel. Text on it should be white.
class GradientPanel extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GradientPanel({
    super.key,
    required this.child,
    this.colors = AppColors.heroGradient,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: SeigaihaPattern()),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// 青海波 (seigaiha), the traditional wave pattern, drawn faintly in white
/// over a coloured surface. It fades in from the left so text there stays
/// clean, and is the app's signature texture on hero panels.
class SeigaihaPattern extends StatelessWidget {
  /// Radius of one wave scale, in logical pixels.
  final double scale;

  /// Strength of the lines at their most visible edge.
  final double opacity;

  const SeigaihaPattern({super.key, this.scale = 22, this.opacity = 0.2});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0xFFFFFFFF)],
          stops: [0.25, 0.55, 1],
        ).createShader(bounds),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _SeigaihaPainter(
              color: Colors.white.withValues(alpha: opacity),
              radius: scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeigaihaPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _SeigaihaPainter({required this.color, required this.radius});

  /// Concentric rings per scale.
  static const _rings = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // Drawn in its own layer: each scale first clears the area it covers, so
    // later (lower) rows overlap earlier ones like real fish scales.
    canvas.saveLayer(bounds, Paint());
    final clear = Paint()..blendMode = BlendMode.clear;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final rowStep = radius / 2;
    var row = 0;
    for (var y = -radius; y <= size.height + radius; y += rowStep, row++) {
      final shift = row.isOdd ? radius : 0.0;
      for (var x = -radius + shift; x <= size.width + radius; x += radius * 2) {
        final centre = Offset(x, y);
        canvas.drawCircle(centre, radius, clear);
        for (var ring = 1; ring <= _rings; ring++) {
          canvas.drawCircle(centre, radius * ring / _rings - 0.6, line);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeigaihaPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// A small rounded label, tinted or [solid].
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;
  final IconData? icon;

  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.solid = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = solid ? onAccent(color) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section title with an optional "See all" style action.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final String actionLabel;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.onAction,
    this.actionLabel = 'See all',
    this.padding = const EdgeInsets.fromLTRB(4, 22, 0, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// The empty / finished state of a screen: a coloured badge, a title, a
/// message and an optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.white, 0.35)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 46, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Text colour that stays readable on a solid [color] fill.
Color onAccent(Color color) =>
    color.computeLuminance() > 0.4 ? AppColors.textPrimary : Colors.white;

/// A filled button in a specific accent colour.
ButtonStyle accentButtonStyle(Color color) => FilledButton.styleFrom(
  backgroundColor: color,
  foregroundColor: onAccent(color),
);
