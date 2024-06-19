import 'package:flutter/material.dart';
import 'package:music_notes/graphics/generated/engraving-defaults.dart';
import '../music-line.dart';

paintBeam(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = 0;
  paint.style = PaintingStyle.fill;

  final Path path = Path();
  path.moveTo(start.dx, start.dy);
  path.lineTo(end.dx, end.dy);
  path.lineTo(
      end.dx, end.dy + drawC.lineSpacing * ENGRAVING_DEFAULTS.beamThickness);
  path.lineTo(start.dx,
      start.dy + drawC.lineSpacing * ENGRAVING_DEFAULTS.beamThickness);
  path.close();

  drawC.canvas.drawPath(path, paint);
}

paintDot(DrawingContext drawC, double yOffset) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = 0;
  paint.style = PaintingStyle.fill;
  drawC.canvas.drawCircle(Offset(15, yOffset), 2, paint);
}

paintStem(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = ENGRAVING_DEFAULTS.stemThickness * drawC.lineSpacing;

  drawC.canvas.drawLine(start, end, paint);
}

paintTie(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = 0;
  paint.style = PaintingStyle.fill;

  final Path path = Path();
  double midPointX = (start.dx + end.dx) / 2;
  double midPointY = (start.dy + end.dy) / 2 - 5;

  path.moveTo(start.dx, start.dy);
  path.quadraticBezierTo(midPointX, midPointY, end.dx, end.dy);
  path.quadraticBezierTo(midPointX, midPointY - 5, start.dx, start.dy);

  path.close();

  drawC.canvas.drawPath(path, paint);
}
