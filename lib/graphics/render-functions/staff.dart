import 'package:flutter/material.dart';
import 'package:music_notes/graphics/generated/glyph-range-definitions.dart';
import '../music-line.dart';
import 'glyph.dart';
import 'note.dart';
import '../notes.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';
import '../generated/engraving-defaults.dart';
import '../../musicXML/data.dart';

/// Advances to the end of the lines
paintStaffLines(DrawingContext drawC, bool noAdvance) {
  final lineSpacing = drawC.lineSpacing;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

  final lineWidth = drawC.size.width - drawC.canvas.getTranslation().dx;

  drawC.canvas.drawLine(Offset(0, 0), Offset(lineWidth, 0), paint);
  drawC.canvas.drawLine(
      Offset(0, lineSpacing * 1), Offset(lineWidth, lineSpacing * 1), paint);
  drawC.canvas.drawLine(
      Offset(0, lineSpacing * 2), Offset(lineWidth, lineSpacing * 2), paint);
  drawC.canvas.drawLine(
      Offset(0, lineSpacing * 3), Offset(lineWidth, lineSpacing * 3), paint);
  drawC.canvas.drawLine(
      Offset(0, lineSpacing * 4), Offset(lineWidth, lineSpacing * 4), paint);

  if (!noAdvance) {
    drawC.canvas.translate(lineWidth, 0);
  }
}

enum BarLineTypes {
  regular,
  lightLight,
  heavyHeavy,
  heavyLight,
  lightHeavy,
  heavy,
  dashed,
  repeatRight,
  repeatLeft
}

paintBarNumber(DrawingContext drawC, MusicLineOptions options, bool noAdvance) {
  if (options.noBarNumber) return;
  if (noAdvance) {
    drawC.canvas.save();
  }

  final textStyle = TextStyle(
    color: Colors.black,
    fontSize: 20,
  );

  int measure = options.firstBar + drawC.currentMeasure + 1;
  final textSpan = TextSpan(
    text: "${measure}",
    style: textStyle,
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  textPainter.layout(
    minWidth: 0,
    maxWidth: 100,
  );

  textPainter.paint(drawC.canvas, Offset(0, -35));

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

/// Does translate to after its width
paintBarLine(DrawingContext drawC, Barline barline, bool noAdvance) {
  final lS = drawC.lineSpacing;
  final paint = Paint()..color = Colors.black;
  final staves = drawC.latestAttributes.staves!;

  final startOffset = Offset(0, 0);
  final endOffset = Offset(
      0,
      staves > 1
          ? drawC.staffHeight * 2 + drawC.staffsSpacing
          : drawC.staffHeight);

  if (noAdvance) {
    drawC.canvas.save();
  }

  if (barline.barStyle == BarLineTypes.regular) {
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(
        lS * ENGRAVING_DEFAULTS.barlineSeparation +
            lS * ENGRAVING_DEFAULTS.thinBarlineThickness,
        0);
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if (barline.barStyle == BarLineTypes.lightHeavy) {
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(
        lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
            lS * ENGRAVING_DEFAULTS.thinBarlineThickness,
        0);
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas
        .translate(lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas
        .translate(lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paintGlyph(drawC, Glyph.repeatDots);
    drawC.canvas.translate(lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!, 0);
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    paintGlyph(drawC, Glyph.repeatDots);
    drawC.canvas.translate(
        lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]! +
            lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation,
        0);
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(
        lS * ENGRAVING_DEFAULTS.thinBarlineThickness +
            lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation,
        0);
    paint.strokeWidth = lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  }

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

calculateBarlineWidth(DrawingContext drawC, Barline barline) {
  final lS = drawC.lineSpacing;
  double width = 0;

  if (barline.barStyle == BarLineTypes.regular) {
    width = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    width = lS * ENGRAVING_DEFAULTS.barlineSeparation +
        lS * ENGRAVING_DEFAULTS.thinBarlineThickness +
        lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.heavyHeavy) {
    width = lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        lS * ENGRAVING_DEFAULTS.thinBarlineThickness +
        lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    width = lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation +
        lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!;
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    width = lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]! +
        lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation +
        lS * ENGRAVING_DEFAULTS.thinBarlineThickness +
        lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
  }

  return width;
}

/// Returns true if something was actually drawn
bool paintAccidentalsForTone(DrawingContext drawC, Clefs staff, Fifths tone,
    {bool noAdvance = false}) {
  if (noAdvance) {
    drawC.canvas.save();
  }

  bool didDrawSomething = false;

  double lineSpacing = drawC.lineSpacing;
  final accidentals = staff == Clefs.F
      ? mainToneAccidentalsMapForFClef[tone]!
      : mainToneAccidentalsMapForGClef[tone]!;
  accidentals.forEach((note) {
    if (note.accidental != Accidentals.none) {
      paintGlyph(
        drawC,
        accidentalGlyphMap[note.accidental]!,
        yOffset: (lineSpacing / 2) *
            calculateYOffsetForNote(staff, note.positionalValue()),
      );
      didDrawSomething = true;
    }
  });

  if (noAdvance) {
    drawC.canvas.restore();
  }

  return didDrawSomething;
}

double calculateAccidentalsForToneWidth(DrawingContext drawC, Fifths tone) {
  double width = 0;
  final accidentals = mainToneAccidentalsMapForFClef[tone]!;
  accidentals.forEach((note) {
    if (note.accidental != Accidentals.none) {
      width += calculateGlyphWidth(drawC, accidentalGlyphMap[note.accidental]!);
    }
  });
  return width;
}

paintTimeSignature(DrawingContext drawC, Attributes attributes,
    {bool noAdvance = false}) {
  paintGlyph(drawC,
      GLYPHRANGE_MAP[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beats],
      yOffset: -drawC.lineSpacing, noAdvance: true);
  paintGlyph(
      drawC,
      GLYPHRANGE_MAP[GlyphRange.timeSignatures]!
          .glyphs[attributes.time!.beatType],
      yOffset: drawC.lineSpacing,
      noAdvance: noAdvance);
}

calculateTimeSignatureWidth(DrawingContext drawC, Attributes attributes) {
  return calculateGlyphWidth(
      drawC,
      GLYPHRANGE_MAP[GlyphRange.timeSignatures]!
          .glyphs[attributes.time!.beatType]);
}
