import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../theme.dart';

/// The shield, speech bubble and envelope from the mock-ups, drawn in code so
/// it stays sharp at any size and works on light and dark backgrounds.
class SmishieldLogo extends StatelessWidget {
  const SmishieldLogo({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.94,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  static const _rim = Color(0xFF2473B5);
  static const _inner = Color(0xFF122B63);
  static const _outline = Color(0xFF0A184C);
  static const _bubbleLight = Color(0xFF9DBCE4);
  static const _bubbleDark = Color(0xFF376EAE);
  static const _dots = Color(0xFF3A0F6E);
  static const _envelope = Color(0xFF3D6DAB);

  @override
  void paint(Canvas canvas, Size size) {
    // Designed on a 100 x 94 grid.
    canvas.scale(size.width / 100, size.height / 94);

    Path shield(double inset) {
      final l = 8 + inset, r = 74 - inset, top = 5 + inset * 1.1;
      final mid = (l + r) / 2;
      return Path()
        ..moveTo(mid, top)
        ..cubicTo(mid + 10, top + 6, r - 8, top + 9, r, top + 9)
        ..lineTo(r, 44)
        ..cubicTo(r, 64 - inset * 0.3, mid + 14, 76 - inset, mid, 84 - inset)
        ..cubicTo(mid - 14, 76 - inset, l, 64 - inset * 0.3, l, 44)
        ..lineTo(l, top + 9)
        ..cubicTo(l + 8, top + 9, mid - 10, top + 6, mid, top)
        ..close();
    }

    canvas.drawPath(shield(0), Paint()..color = _rim);
    canvas.drawPath(shield(6), Paint()..color = _inner);

    // Speech bubble with a tail to the lower left.
    final bubble = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(42, 40), width: 44, height: 31),
      )
      ..moveTo(28, 50)
      ..quadraticBezierTo(25, 55, 19, 57.5)
      ..quadraticBezierTo(30, 57, 36, 54)
      ..close();
    final bubbleRect = const Rect.fromLTWH(19, 24, 45, 34);
    canvas.drawPath(
      bubble,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_bubbleLight, _bubbleDark],
        ).createShader(bubbleRect),
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    for (final x in [34.0, 42.0, 50.0]) {
      canvas.drawCircle(Offset(x, 40), 3, Paint()..color = _dots);
    }

    // Envelope in the lower right.
    final envelope = RRect.fromRectAndRadius(
      const Rect.fromLTWH(51, 55, 43, 31),
      const Radius.circular(4),
    );
    canvas.drawRRect(envelope, Paint()..color = _envelope);
    final stroke = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(envelope, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(53, 58)
        ..lineTo(72.5, 73)
        ..lineTo(92, 58),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "SMISH" + "SHIELD" with the tag line underneath.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.strings, this.scale = 1});

  final Strings strings;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final first = context.isDark ? Colors.white : Palette.navy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 38 * scale,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: 'SMISH',
                  style: TextStyle(color: first),
                ),
                const TextSpan(
                  text: 'SHIELD',
                  style: TextStyle(color: Palette.brandBlue),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          strings.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: first,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
