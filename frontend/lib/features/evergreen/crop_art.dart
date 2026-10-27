import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Original vector illustrations. No downloaded images, fonts or image assets.
class CropIllustration extends StatelessWidget {
  const CropIllustration(this.crop, {super.key, this.size = 100});
  final String crop;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CropPainter(crop)),
    ),
  );
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.crop);
  final String crop;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..isAntiAlias = true;
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, paint..color = color);
    void path(Path path, Color color) =>
        canvas.drawPath(path, paint..color = color);
    oval(const Rect.fromLTWH(16, 85, 70, 7), const Color(0x186E8268));
    if (crop == 'Tomato') {
      oval(const Rect.fromLTWH(15, 27, 72, 60), const Color(0xFFC65D47));
      oval(const Rect.fromLTWH(21, 29, 33, 52), const Color(0xFFDF7756));
      oval(const Rect.fromLTWH(28, 39, 7, 17), const Color(0xFFECA98C));
      final crown = Path()
        ..moveTo(50, 37)
        ..lineTo(29, 23)
        ..lineTo(45, 27)
        ..lineTo(46, 13)
        ..lineTo(53, 27)
        ..lineTo(72, 21)
        ..lineTo(61, 35)
        ..lineTo(70, 39)
        ..lineTo(54, 37)
        ..lineTo(46, 45)
        ..close();
      path(crown, EvergreenColors.forest);
    } else if (crop == 'Maize') {
      path(
        Path()
          ..moveTo(40, 83)
          ..quadraticBezierTo(14, 59, 18, 37)
          ..quadraticBezierTo(45, 50, 58, 89)
          ..close(),
        const Color(0xFF518760),
      );
      oval(const Rect.fromLTWH(35, 10, 35, 75), const Color(0xFFC58B35));
      for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 4; col++) {
          if ((row == 0 || row == 9) && (col == 0 || col == 3)) continue;
          oval(
            Rect.fromLTWH(36 + col * 8.0, 13 + row * 6.9, 7, 6),
            Color.lerp(
              const Color(0xFFE5B449),
              const Color(0xFFF6D279),
              col / 4,
            )!,
          );
        }
      }
      path(
        Path()
          ..moveTo(49, 91)
          ..quadraticBezierTo(62, 43, 88, 31)
          ..quadraticBezierTo(88, 75, 49, 91)
          ..close(),
        EvergreenColors.leaf,
      );
      path(
        Path()
          ..moveTo(55, 85)
          ..quadraticBezierTo(67, 51, 85, 38)
          ..quadraticBezierTo(72, 77, 55, 85)
          ..close(),
        const Color(0xFF7BA276),
      );
    } else if (crop == 'Potato') {
      oval(const Rect.fromLTWH(20, 23, 61, 46), const Color(0xFFAA7851));
      oval(const Rect.fromLTWH(9, 51, 57, 34), const Color(0xFFC69869));
      oval(const Rect.fromLTWH(53, 53, 39, 31), const Color(0xFFD4AA7E));
      for (final point in [
        const Offset(30, 40),
        const Offset(62, 34),
        const Offset(52, 56),
        const Offset(29, 68),
        const Offset(70, 65),
        const Offset(78, 74),
      ]) {
        oval(
          Rect.fromCenter(center: point, width: 3, height: 2),
          const Color(0xFF835938),
        );
      }
    } else if (crop == 'Bell Pepper') {
      path(
        Path()
          ..moveTo(50, 27)
          ..cubicTo(19, 14, 13, 45, 25, 76)
          ..cubicTo(30, 91, 41, 87, 50, 83)
          ..cubicTo(72, 98, 83, 72, 82, 49)
          ..cubicTo(82, 24, 64, 17, 50, 27)
          ..close(),
        const Color(0xFF4F8460),
      );
      oval(const Rect.fromLTWH(27, 31, 18, 44), const Color(0xFF73A472));
      oval(const Rect.fromLTWH(52, 28, 16, 52), const Color(0xFF659867));
      path(
        Path()
          ..moveTo(47, 30)
          ..lineTo(48, 12)
          ..quadraticBezierTo(64, 3, 67, 13)
          ..quadraticBezierTo(56, 12, 55, 32)
          ..close(),
        EvergreenColors.forest,
      );
    } else {
      for (int i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(50, 52);
        canvas.rotate((i - 2) * .36);
        oval(
          const Rect.fromLTWH(-18, -36, 36, 64),
          Color.lerp(EvergreenColors.leaf, EvergreenColors.sage, i / 5)!,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => crop != old.crop;
}

class BotanicalAccent extends StatelessWidget {
  const BotanicalAccent({super.key});
  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: CustomPaint(painter: _BotanicalPainter()));
}

class _BotanicalPainter extends CustomPainter {
  const _BotanicalPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..isAntiAlias = true;
    final stem = Path()
      ..moveTo(s.width * .55, s.height)
      ..cubicTo(
        s.width * .32,
        s.height * .6,
        s.width * .72,
        s.height * .5,
        s.width * .5,
        0,
      );
    canvas.drawPath(
      stem,
      p
        ..color = EvergreenColors.sage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    p.style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(
        s.width * (.5 + .07 * math.sin(i)),
        s.height * (.13 + i * .13),
      );
      canvas.rotate(i.isEven ? -.65 : .75);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -s.width * .4,
          -s.height * .11,
          -s.width * .32,
          -s.height * .25,
          0,
          0,
        )
        ..close();
      canvas.drawPath(
        path,
        p
          ..color = i.isEven
              ? const Color(0xFF729A7D)
              : EvergreenColors.sage.withValues(alpha: .7),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BotanicalPainter old) => false;
}
