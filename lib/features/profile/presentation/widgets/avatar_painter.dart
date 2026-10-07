import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';

/// Each character's backdrop: a soft pastel that the character sits on.
extension AvatarCharacterStyle on AvatarCharacter {
  Color get background => switch (this) {
    AvatarCharacter.neko => const Color(0xFFDCE6F7),
    AvatarCharacter.kitsune => const Color(0xFFFFE2C6),
    AvatarCharacter.shiba => const Color(0xFFFFEDD3),
    AvatarCharacter.tanuki => const Color(0xFFEADFCF),
    AvatarCharacter.panda => const Color(0xFFD5F1DF),
    AvatarCharacter.usagi => const Color(0xFFFCE0EC),
    AvatarCharacter.kuma => const Color(0xFFF2E1CC),
    AvatarCharacter.kappa => const Color(0xFFD3EFF5),
    AvatarCharacter.oni => const Color(0xFFFFDFDA),
    AvatarCharacter.ninja => const Color(0xFFDEE2F6),
    AvatarCharacter.daruma => const Color(0xFFFFF0C4),
    AvatarCharacter.onigiri => const Color(0xFFD7EEDF),
  };

  /// A deeper shade of [background], for rings, gradients and accents.
  Color get accent =>
      HSLColor.fromColor(background)
          .withLightness(0.62)
          .withSaturation(0.55)
          .toColor();
}

const _ink = Color(0xFF26232F);
const _blush = Color(0xFFFF8FA3);

/// Draws an [AvatarCharacter] as a head-and-shoulders portrait.
///
/// Everything is laid out on a 100×100 grid and scaled to the canvas, so one
/// drawing serves a 32px chip and a 160px profile hero alike. The backdrop is
/// not painted here: the widget around it owns the shape and colour.
class AvatarPainter extends CustomPainter {
  final AvatarCharacter character;

  const AvatarPainter(this.character);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (character) {
      case AvatarCharacter.neko:
        _neko(canvas);
      case AvatarCharacter.kitsune:
        _kitsune(canvas);
      case AvatarCharacter.shiba:
        _shiba(canvas);
      case AvatarCharacter.tanuki:
        _tanuki(canvas);
      case AvatarCharacter.panda:
        _panda(canvas);
      case AvatarCharacter.usagi:
        _usagi(canvas);
      case AvatarCharacter.kuma:
        _kuma(canvas);
      case AvatarCharacter.kappa:
        _kappa(canvas);
      case AvatarCharacter.oni:
        _oni(canvas);
      case AvatarCharacter.ninja:
        _ninja(canvas);
      case AvatarCharacter.daruma:
        _daruma(canvas);
      case AvatarCharacter.onigiri:
        _onigiri(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) =>
      oldDelegate.character != character;

  // --- Characters ------------------------------------------------------------

  void _neko(Canvas c) {
    const fur = Color(0xFF8E9BB3);
    const light = Color(0xFFF1F3F8);
    const inner = Color(0xFFF7B3C6);
    _body(c, fur, chest: light);
    _ear(
      c,
      const Offset(24, 44),
      const Offset(25, 13),
      const Offset(46, 30),
      fur,
      inner,
    );
    _ear(
      c,
      const Offset(76, 44),
      const Offset(75, 13),
      const Offset(54, 30),
      fur,
      inner,
    );
    _oval(c, 50, 57, 33, 29, fur);
    // Tabby stripes on the forehead.
    for (final (x, h) in [(43.0, 7.0), (50.0, 9.0), (57.0, 7.0)]) {
      _roundRect(c, Rect.fromLTWH(x - 1.6, 29, 3.2, h), 1.6, _shade(fur, 0.18));
    }
    _oval(c, 50, 69, 13, 9, light);
    _eyes(c, y: 55);
    _cheeks(c, y: 65);
    _whiskers(c, y: 67);
    _nose(c, 50, 64, inner, width: 5);
    _catMouth(c, 50, 67);
  }

  void _kitsune(Canvas c) {
    const fur = Color(0xFFF08A3C);
    const light = Color(0xFFFFF4E6);
    const inner = Color(0xFFFFD2AE);
    _body(c, fur, chest: light);
    _ear(
      c,
      const Offset(21, 44),
      const Offset(24, 9),
      const Offset(46, 30),
      fur,
      inner,
    );
    _ear(
      c,
      const Offset(79, 44),
      const Offset(76, 9),
      const Offset(54, 30),
      fur,
      inner,
    );
    // Ear tips dipped in dark fur.
    _triangle(
      c,
      const Offset(23.2, 17),
      const Offset(24, 9),
      const Offset(29.6, 13.6),
      _shade(fur, 0.45),
    );
    _triangle(
      c,
      const Offset(76.8, 17),
      const Offset(76, 9),
      const Offset(70.4, 13.6),
      _shade(fur, 0.45),
    );
    _oval(c, 50, 57, 32, 28, fur);
    // White cheeks sweeping up from the chin.
    final cheeks = Path()
      ..moveTo(18, 60)
      ..quadraticBezierTo(30, 52, 44, 60)
      ..quadraticBezierTo(50, 64, 56, 60)
      ..quadraticBezierTo(70, 52, 82, 60)
      ..quadraticBezierTo(76, 84, 50, 85)
      ..quadraticBezierTo(24, 84, 18, 60)
      ..close();
    c.drawPath(cheeks, Paint()..color = light);
    _eyes(c, y: 52, spread: 12, squint: true);
    _cheeks(c, y: 63, spread: 21);
    _nose(c, 50, 64, _ink, width: 5);
    _smile(c, 50, 67, width: 7);
  }

  void _shiba(Canvas c) {
    const fur = Color(0xFFE09A4F);
    const light = Color(0xFFFFF7EA);
    const inner = Color(0xFFF7CB9E);
    _body(c, fur, chest: light);
    _ear(
      c,
      const Offset(23, 42),
      const Offset(26, 14),
      const Offset(45, 29),
      fur,
      inner,
    );
    _ear(
      c,
      const Offset(77, 42),
      const Offset(74, 14),
      const Offset(55, 29),
      fur,
      inner,
    );
    _oval(c, 50, 57, 33, 29, fur);
    _oval(c, 50, 71, 21, 14, light);
    _oval(c, 37, 62, 9, 8, light);
    _oval(c, 63, 62, 9, 8, light);
    // The shiba's eyebrow dots.
    _oval(c, 40, 45, 3.2, 2.2, light);
    _oval(c, 60, 45, 3.2, 2.2, light);
    _eyes(c, y: 54);
    _cheeks(c, y: 64, spread: 22);
    _oval(c, 50, 64, 4.4, 3.2, _ink);
    _smile(c, 50, 67, width: 8);
    // A little tongue.
    final tongue = Path()
      ..moveTo(47.2, 70.2)
      ..lineTo(52.8, 70.2)
      ..quadraticBezierTo(53, 75.5, 50, 75.5)
      ..quadraticBezierTo(47, 75.5, 47.2, 70.2)
      ..close();
    c.drawPath(tongue, Paint()..color = const Color(0xFFFF7B8E));
  }

  void _tanuki(Canvas c) {
    const fur = Color(0xFF9A7655);
    const light = Color(0xFFF3E6D4);
    const mask = Color(0xFF5B4535);
    _body(c, fur, chest: light);
    _oval(c, 27, 33, 9, 9, fur);
    _oval(c, 73, 33, 9, 9, fur);
    _oval(c, 27, 33, 4.6, 4.6, mask);
    _oval(c, 73, 33, 4.6, 4.6, mask);
    _oval(c, 50, 57, 32, 28, fur);
    _oval(c, 50, 47, 16, 10, light);
    _rotatedOval(c, 38, 56, 10, 7.5, 0.35, mask);
    _rotatedOval(c, 62, 56, 10, 7.5, -0.35, mask);
    _oval(c, 50, 70, 12, 9, light);
    _eyes(c, y: 56, highlight: 1.7);
    _cheeks(c, y: 67, spread: 22);
    _oval(c, 50, 65, 4.2, 3, _ink);
    _smile(c, 50, 68, width: 6);
    // The leaf tanuki wear to shape-shift.
    final leaf = Path()
      ..moveTo(50, 33)
      ..quadraticBezierTo(39, 27, 44, 16)
      ..quadraticBezierTo(55, 19, 50, 33)
      ..close();
    c.drawPath(leaf, Paint()..color = const Color(0xFF4CAF6A));
    c.drawLine(
      const Offset(50, 33),
      const Offset(45.5, 20),
      _stroke(const Color(0xFF2E7D4A), 1.2),
    );
  }

  void _panda(Canvas c) {
    const white = Color(0xFFFBFBFD);
    const black = Color(0xFF2B2B35);
    _body(c, black, chest: white, chestWidth: 22);
    _oval(c, 26, 32, 10, 10, black);
    _oval(c, 74, 32, 10, 10, black);
    _oval(c, 50, 57, 33, 29, white);
    _rotatedOval(c, 38, 56, 7.5, 10, 0.5, black);
    _rotatedOval(c, 62, 56, 7.5, 10, -0.5, black);
    for (final x in [38.5, 61.5]) {
      _oval(c, x, 55.5, 3.8, 3.8, white);
      _oval(c, x, 56, 2.4, 2.6, _ink);
      _oval(c, x + 0.9, 54.8, 0.9, 0.9, white);
    }
    _cheeks(c, y: 66, spread: 23);
    _oval(c, 50, 65, 4.6, 3.2, black);
    _smile(c, 50, 68, width: 7);
  }

  void _usagi(Canvas c) {
    const fur = Color(0xFFF7F3FA);
    const inner = Color(0xFFF7A6C2);
    const outline = Color(0xFFE6DDF0);
    _body(c, fur, chest: const Color(0xFFFFFFFF));
    _rotatedOval(c, 38, 21, 7.5, 21, -0.18, outline);
    _rotatedOval(c, 62, 21, 7.5, 21, 0.18, outline);
    _rotatedOval(c, 38, 21, 6.5, 20, -0.18, fur);
    _rotatedOval(c, 62, 21, 6.5, 20, 0.18, fur);
    _rotatedOval(c, 38, 23, 3.2, 14, -0.18, inner);
    _rotatedOval(c, 62, 23, 3.2, 14, 0.18, inner);
    _oval(c, 50, 60, 32.6, 27.6, outline);
    _oval(c, 50, 60, 31.5, 26.5, fur);
    _eyes(c, y: 58);
    _cheeks(c, y: 67, alpha: 0.6);
    _nose(c, 50, 66, inner, width: 4.6);
    // The rabbit's "Y" mouth.
    final mouth = Path()
      ..moveTo(50, 67.5)
      ..lineTo(50, 70)
      ..moveTo(46.5, 71.5)
      ..quadraticBezierTo(50, 72.5, 50, 70)
      ..quadraticBezierTo(50, 72.5, 53.5, 71.5);
    c.drawPath(mouth, _stroke(_ink, 1.8));
  }

  void _kuma(Canvas c) {
    const fur = Color(0xFF8C5D3B);
    const light = Color(0xFFEAD2B2);
    _body(c, fur, chest: light);
    _oval(c, 26, 33, 10, 10, fur);
    _oval(c, 74, 33, 10, 10, fur);
    _oval(c, 26, 33, 5, 5, light);
    _oval(c, 74, 33, 5, 5, light);
    _oval(c, 50, 57, 33, 29, fur);
    _oval(c, 50, 69, 14, 11, light);
    _eyes(c, y: 54, highlight: 1.7);
    _cheeks(c, y: 64, spread: 22);
    _oval(c, 50, 64, 5.4, 3.8, _ink);
    _smile(c, 50, 68.5, width: 7);
  }

  void _kappa(Canvas c) {
    const skin = Color(0xFF6CC28A);
    const hair = Color(0xFF2F6B4B);
    const beak = Color(0xFFF6B93B);
    _body(c, skin, chest: const Color(0xFFE6F4D7));
    _oval(c, 50, 58, 32, 28, skin);
    // A fringe of spiky hair around the crown.
    final fringe = Path()..moveTo(19, 52);
    const spikes = 9;
    for (var i = 0; i < spikes; i++) {
      final x0 = 19 + i * 62 / spikes;
      final x1 = x0 + 62 / spikes;
      final y = 40 - 10 * math.sin(math.pi * (i + 0.5) / spikes);
      fringe
        ..lineTo((x0 + x1) / 2, y)
        ..lineTo(x1, 47 - 9 * math.sin(math.pi * (i + 1) / spikes));
    }
    fringe
      ..lineTo(81, 52)
      ..quadraticBezierTo(50, 22, 19, 52)
      ..close();
    c.drawPath(fringe, Paint()..color = hair);
    // The water dish on top of the head.
    _oval(c, 50, 31, 16, 6.5, const Color(0xFFDDEBD4));
    _oval(c, 50, 30.4, 13, 4.6, const Color(0xFFF4F9EE));
    _eyes(c, y: 56);
    _cheeks(c, y: 65, spread: 22);
    _oval(c, 50, 69, 10, 6, beak);
    c.drawLine(
      const Offset(41, 69),
      const Offset(59, 69),
      _stroke(_shade(beak, 0.3), 1.4),
    );
  }

  void _oni(Canvas c) {
    const skin = Color(0xFFE85D52);
    const hair = Color(0xFF2E2A3B);
    const horn = Color(0xFFF9D56E);
    _body(
      c,
      const Color(0xFF3F6FD8),
      chest: const Color(0xFFF9D56E),
      chestWidth: 10,
    );
    _oval(c, 50, 58, 32, 28, skin);
    for (final (x, y, r) in [
      (24.0, 45.0, 7.0),
      (30.0, 37.0, 8.0),
      (40.0, 32.0, 8.5),
      (50.0, 30.0, 9.0),
      (60.0, 32.0, 8.5),
      (70.0, 37.0, 8.0),
      (76.0, 45.0, 7.0),
    ]) {
      _oval(c, x, y, r, r, hair);
    }
    _triangle(
      c,
      const Offset(32, 33),
      const Offset(35, 11),
      const Offset(43, 29),
      horn,
    );
    _triangle(
      c,
      const Offset(68, 33),
      const Offset(65, 11),
      const Offset(57, 29),
      horn,
    );
    final bands = _stroke(_shade(horn, 0.25), 1.3);
    c.drawLine(const Offset(34.2, 25), const Offset(40.4, 23.2), bands);
    c.drawLine(const Offset(65.8, 25), const Offset(59.6, 23.2), bands);
    // Bushy brows, friendly tilt.
    c.drawLine(const Offset(34, 47), const Offset(43, 48.5), _stroke(hair, 3));
    c.drawLine(const Offset(66, 47), const Offset(57, 48.5), _stroke(hair, 3));
    _eyes(c, y: 55);
    _cheeks(c, y: 64, alpha: 0.35, color: const Color(0xFFFFC2B8));
    // A wide grin with two little fangs.
    final grin = Path()
      ..moveTo(40, 64)
      ..quadraticBezierTo(50, 75, 60, 64)
      ..close();
    c.drawPath(grin, Paint()..color = const Color(0xFF7A1F2B));
    _triangle(
      c,
      const Offset(43, 65.5),
      const Offset(45.5, 69.6),
      const Offset(47.5, 66.6),
      Colors.white,
    );
    _triangle(
      c,
      const Offset(57, 65.5),
      const Offset(54.5, 69.6),
      const Offset(52.5, 66.6),
      Colors.white,
    );
  }

  void _ninja(Canvas c) {
    const hood = Color(0xFF2F3652);
    const skin = Color(0xFFF6D5B8);
    const band = Color(0xFFE63946);
    _body(c, hood);
    _oval(c, 50, 56, 33, 30, hood);
    _roundRect(c, const Rect.fromLTRB(21, 46, 79, 65), 9.5, skin);
    // Headband, with its knot tails flying off to the right.
    _roundRect(c, const Rect.fromLTRB(17.5, 33.5, 82.5, 42.5), 3, band);
    final tails = Path()
      ..moveTo(80, 36)
      ..quadraticBezierTo(90, 28, 97, 31)
      ..quadraticBezierTo(91, 34, 82, 39)
      ..moveTo(80, 39)
      ..quadraticBezierTo(92, 41, 96, 47)
      ..quadraticBezierTo(89, 45, 81, 41.5);
    c.drawPath(tails, Paint()..color = band);
    _roundRect(
      c,
      const Rect.fromLTRB(43, 33, 57, 43),
      2.4,
      const Color(0xFFCBD3DE),
    );
    _oval(c, 50, 38, 2.2, 2.2, const Color(0xFF8D99AB));
    _eyes(c, y: 55.5, spread: 11, highlight: 1.6);
    _cheeks(c, y: 61, spread: 21, alpha: 0.4);
  }

  void _daruma(Canvas c) {
    const red = Color(0xFFD7263D);
    const face = Color(0xFFFFF4E4);
    const gold = Color(0xFFF2C14E);
    _oval(c, 50, 66, 40, 38, red);
    _oval(c, 50, 54, 23, 19, face);
    // Thick crane-and-turtle brows.
    final brows = _stroke(_ink, 3.2);
    c.drawPath(
      Path()
        ..moveTo(34, 46)
        ..quadraticBezierTo(40, 40, 46, 45),
      brows,
    );
    c.drawPath(
      Path()
        ..moveTo(66, 46)
        ..quadraticBezierTo(60, 40, 54, 45),
      brows,
    );
    // One eye filled in, one waiting: a daruma's wish in progress.
    _oval(c, 41, 53, 4.6, 4.6, _ink);
    _oval(c, 42.4, 51.6, 1.5, 1.5, Colors.white);
    c.drawCircle(const Offset(59, 53), 4.4, _stroke(_ink, 1.6));
    _cheeks(c, y: 61, spread: 15, alpha: 0.4);
    // Moustache.
    final moustache = _stroke(_ink, 2.2);
    c.drawPath(
      Path()
        ..moveTo(50, 62)
        ..quadraticBezierTo(44, 59, 40.5, 63.5),
      moustache,
    );
    c.drawPath(
      Path()
        ..moveTo(50, 62)
        ..quadraticBezierTo(56, 59, 59.5, 63.5),
      moustache,
    );
    _smile(c, 50, 66, width: 4);
    // 福, "good fortune", in gold on the belly.
    final text = TextPainter(
      text: const TextSpan(
        text: '福',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: gold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(c, Offset(50 - text.width / 2, 75));
    c.drawArc(
      const Rect.fromLTRB(16, 32, 84, 100),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      _stroke(gold, 2),
    );
  }

  void _onigiri(Canvas c) {
    const rice = Color(0xFFFFFFFF);
    const nori = Color(0xFF1F2D27);
    final triangle = _roundedTriangle(
      const Offset(50, 12),
      const Offset(90, 86),
      const Offset(10, 86),
      radius: 15,
    );
    c.drawPath(triangle, Paint()..color = rice);
    c.drawPath(triangle, _stroke(const Color(0xFFE2E6EA), 1.6));
    c.save();
    c.clipPath(triangle);
    c.drawRect(const Rect.fromLTRB(33, 66, 67, 100), Paint()..color = nori);
    c.drawRect(
      const Rect.fromLTRB(33, 66, 67, 68.5),
      Paint()..color = _shade(nori, -0.15),
    );
    c.restore();
    // A few grains of sesame.
    for (final (x, y, a) in [
      (42.0, 31.0, 0.5),
      (57.0, 34.0, -0.4),
      (50.0, 26.0, 0.1),
    ]) {
      _rotatedOval(c, x, y, 0.9, 1.8, a, const Color(0xFFCFC6B5));
    }
    _eyes(c, y: 50, spread: 9.5, size: 0.85);
    _cheeks(c, y: 57, spread: 17, alpha: 0.55);
    _smile(c, 50, 57, width: 5);
  }

  // --- Shared features -------------------------------------------------------

  /// Shoulders running off the bottom edge, with an optional chest patch.
  void _body(Canvas c, Color color, {Color? chest, double chestWidth = 16}) {
    _oval(c, 50, 113, 40, 29, color);
    if (chest != null) _oval(c, 50, 106, chestWidth, 13, chest);
  }

  void _ear(
    Canvas c,
    Offset base,
    Offset tip,
    Offset inside,
    Color fur,
    Color inner,
  ) {
    _triangle(c, base, tip, inside, fur);
    final centre = Offset(
      (base.dx + tip.dx + inside.dx) / 3,
      (base.dy + tip.dy + inside.dy) / 3,
    );
    Offset toward(Offset p) => Offset.lerp(centre, p, 0.55)!;
    _triangle(c, toward(base), toward(tip), toward(inside), inner);
  }

  void _eyes(
    Canvas c, {
    required double y,
    double spread = 11,
    double size = 1,
    double highlight = 1.5,
    bool squint = false,
  }) {
    for (final x in [50 - spread, 50 + spread]) {
      if (squint) {
        // Happy closed eyes: upward arcs.
        c.drawPath(
          Path()
            ..moveTo(x - 4.2, y + 1.2)
            ..quadraticBezierTo(x, y - 4.2, x + 4.2, y + 1.2),
          _stroke(_ink, 2.4),
        );
        continue;
      }
      _oval(c, x, y, 3.8 * size, 4.6 * size, _ink);
      _oval(
        c,
        x + 1.3 * size,
        y - 1.7 * size,
        highlight * size,
        highlight * size,
        Colors.white,
      );
    }
  }

  void _cheeks(
    Canvas c, {
    required double y,
    double spread = 20,
    double alpha = 0.45,
    Color color = _blush,
  }) {
    for (final x in [50 - spread, 50 + spread]) {
      _oval(c, x, y, 5, 3, color.withValues(alpha: alpha));
    }
  }

  void _nose(Canvas c, double x, double y, Color color, {double width = 5}) {
    final half = width / 2;
    final path = Path()
      ..moveTo(x - half, y - 1.4)
      ..quadraticBezierTo(x, y - 2.4, x + half, y - 1.4)
      ..quadraticBezierTo(x + half * 0.4, y + 1.8, x, y + 1.9)
      ..quadraticBezierTo(x - half * 0.4, y + 1.8, x - half, y - 1.4)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  void _smile(Canvas c, double x, double y, {double width = 6}) {
    final half = width / 2;
    c.drawPath(
      Path()
        ..moveTo(x - half, y)
        ..quadraticBezierTo(x, y + half * 0.9, x + half, y),
      _stroke(_ink, 1.9),
    );
  }

  /// The cat's "ω" mouth.
  void _catMouth(Canvas c, double x, double y) {
    c.drawPath(
      Path()
        ..moveTo(x - 4.6, y)
        ..quadraticBezierTo(x - 2.3, y + 3.4, x, y)
        ..quadraticBezierTo(x + 2.3, y + 3.4, x + 4.6, y),
      _stroke(_ink, 1.8),
    );
  }

  void _whiskers(Canvas c, {required double y}) {
    final paint = _stroke(_ink.withValues(alpha: 0.45), 1.1);
    for (final side in [-1.0, 1.0]) {
      c.drawLine(
        Offset(50 + side * 15, y - 1),
        Offset(50 + side * 29, y - 4),
        paint,
      );
      c.drawLine(
        Offset(50 + side * 15, y + 2),
        Offset(50 + side * 29, y + 3),
        paint,
      );
    }
  }

  // --- Primitives -------------------------------------------------------------

  void _oval(
    Canvas c,
    double cx,
    double cy,
    double rx,
    double ry,
    Color color,
  ) {
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  void _rotatedOval(
    Canvas c,
    double cx,
    double cy,
    double rx,
    double ry,
    double angle,
    Color color,
  ) {
    c.save();
    c.translate(cx, cy);
    c.rotate(angle);
    _oval(c, 0, 0, rx, ry, color);
    c.restore();
  }

  void _triangle(Canvas c, Offset a, Offset b, Offset d, Color color) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _roundRect(Canvas c, Rect rect, double radius, Color color) {
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  Path _roundedTriangle(
    Offset a,
    Offset b,
    Offset d, {
    required double radius,
  }) {
    final corners = [a, b, d];
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final previous = corners[(i + 2) % 3];
      final corner = corners[i];
      final next = corners[(i + 1) % 3];
      Offset along(Offset from, Offset to) {
        final delta = to - from;
        return from + delta / delta.distance * radius;
      }

      final start = along(corner, previous);
      final end = along(corner, next);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
    }
    return path..close();
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Darker by [amount] (negative lightens), keeping the hue.
  Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
