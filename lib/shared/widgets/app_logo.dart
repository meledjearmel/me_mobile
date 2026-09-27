import 'package:flutter/material.dart';

/// Monogramme « AM » du portfolio, reproduit depuis `me/public/favicon.svg`
/// (viewBox 56 × 40) pour rester net à toutes les tailles sans dépendance SVG.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 40, this.color});

  final double height;

  /// Par défaut : la couleur du texte du thème (encre le jour, crème la nuit).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Armel Meledje',
      image: true,
      child: CustomPaint(
        size: Size(height * 56 / 40, height),
        painter: _LogoPainter(color ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.color);

  final Color color;

  static const _shapes = [
    [Offset(0, 40), Offset(22, 0), Offset(26, 0), Offset(26, 12.7), Offset(22, 12.7), Offset(7, 40)],
    [Offset(9, 26), Offset(25, 26), Offset(25, 32), Offset(9, 32)],
    [Offset(22, 0), Offset(28, 0), Offset(28, 40), Offset(22, 40)],
    [Offset(22, 0), Offset(28, 0), Offset(39, 16.8), Offset(50, 0), Offset(56, 0), Offset(39, 26)],
    [Offset(50, 0), Offset(56, 0), Offset(56, 40), Offset(50, 40)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 56, size.height / 40);
    final paint = Paint()..color = color;
    for (final shape in _shapes) {
      canvas.drawPath(Path()..addPolygon(shape, true), paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.color != color;
}
