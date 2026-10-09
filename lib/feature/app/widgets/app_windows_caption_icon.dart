import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowsCaptionIcon extends StatelessWidget {
  final WindowsCaptionButton button;
  final bool maximized;
  final Color color;

  const AppWindowsCaptionIcon({
    required this.button,
    required this.maximized,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(10, 10),
    painter: _CaptionIconPainter(
      button: button,
      maximized: maximized,
      color: color,
    ),
  );
}

class _CaptionIconPainter extends CustomPainter {
  final WindowsCaptionButton button;
  final bool maximized;
  final Color color;

  const _CaptionIconPainter({
    required this.button,
    required this.maximized,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    switch (button) {
      case WindowsCaptionButton.minimize:
        canvas.drawLine(const Offset(0, 5.5), const Offset(10, 5.5), paint);
      case WindowsCaptionButton.maximize:
        if (maximized) {
          canvas.drawPath(
            Path()
              ..moveTo(2.5, 2.5)
              ..lineTo(2.5, 0.5)
              ..lineTo(9.5, 0.5)
              ..lineTo(9.5, 7.5)
              ..lineTo(7.5, 7.5),
            paint,
          );
          canvas.drawRect(const Rect.fromLTRB(0.5, 2.5, 7.5, 9.5), paint);
        } else {
          canvas.drawRect(const Rect.fromLTRB(0.5, 0.5, 9.5, 9.5), paint);
        }
      case WindowsCaptionButton.close:
        canvas.drawLine(const Offset(0.5, 0.5), const Offset(9.5, 9.5), paint);
        canvas.drawLine(const Offset(9.5, 0.5), const Offset(0.5, 9.5), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptionIconPainter oldDelegate) =>
      button != oldDelegate.button || maximized != oldDelegate.maximized || color != oldDelegate.color;
}
