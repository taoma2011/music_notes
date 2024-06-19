import 'package:flutter/material.dart';
import 'package:music_notes/graphics/music-line.dart';
import 'common.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';

/// Advances the width of the glyph
paintGlyph(DrawingContext drawC, Glyph glyph,
    {double yOffset = 0, bool noAdvance = false, Color color = Colors.black}) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: GLYPH_FONTCODE_MAP[glyph],
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: drawC.staffHeight,
        height: 1,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(drawC.canvas, Offset(0, yOffset));

  if (!noAdvance) {
    drawC.canvas.translate(calculateGlyphWidth(drawC, glyph), 0);
  }
}

double calculateGlyphWidth(DrawingContext drawC, Glyph glyph) =>
    GLYPH_ADVANCE_WIDTHS[glyph]! * getLineSpacing(drawC.staffHeight);
