import 'package:flutter/material.dart';

import '../../musicXML/data.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-anchors.dart';
import '../generated/glyph-bboxes.dart';
import '../generated/glyph-range-definitions.dart';
import '../music-line.dart';
import '../notes.dart';
import 'beam.dart';
import 'glyph.dart';
import 'dart:math';

paintLedgers(
    DrawingContext drawC, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G:
      {
        if (note.positionalValue() >
            topStaffLineNoteGClef.positionalValue() + 1) {
          numLedgersToDraw = ((note.positionalValue() -
                      topStaffLineNoteGClef.positionalValue()) /
                  2)
              .floor();
        } else if (note.positionalValue() <
            bottomStaffLineNoteGClef.positionalValue() - 1) {
          numLedgersToDraw = ((note.positionalValue() -
                      bottomStaffLineNoteGClef.positionalValue()) /
                  2)
              .ceil();
        }
        break;
      }
    case Clefs.F:
      {
        if (note.positionalValue() >
            topStaffLineNoteFClef.positionalValue() + 1) {
          numLedgersToDraw = ((note.positionalValue() -
                      topStaffLineNoteFClef.positionalValue()) /
                  2)
              .floor();
        } else if (note.positionalValue() <
            bottomStaffLineNoteFClef.positionalValue() - 1) {
          numLedgersToDraw = ((note.positionalValue() -
                      bottomStaffLineNoteFClef.positionalValue()) /
                  2)
              .ceil();
        }
      }
  }

  double lineSpacing = drawC.lineSpacing;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth =
      GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length]!]! * lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for (int i = numLedgersToDraw; i != 0;) {
    if (i < 0) {
      double pos = (-i * 2) * (lineSpacing / 2) + drawC.staffHeight;
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i++;
    } else {
      double pos = -(i * 2) * (lineSpacing / 2);
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

class PitchNoteRenderMeasurements {
  PitchNoteRenderMeasurements(this.boundingBox, this.noteAnchors);

  final Rect boundingBox;
  final GlyphAnchor noteAnchors;
}

class StemLengthReturn {
  final double startLength;
  final double endLength;
  StemLengthReturn(this.startLength, this.endLength);
}

// keep in mind the canvas y coordinate is up is - and down is +
StemLengthReturn computeStemLengthFromBeam(
    List<BeamPoint> bpList, bool up, DrawingContext drawC) {
  double defaultStemLength = drawC.lineSpacing * 2; //(drawC.staffHeight / 2);
  double minStemLength = (drawC.staffHeight / 4);
  double sign = up ? -1 : 1;

  double startStemLength = defaultStemLength +
      (bpList.first.adjustment?.posAdjustment ?? 0) -
      (bpList.first.adjustment?.negAdjustment ?? 0);
  double endStemLength = defaultStemLength +
      (bpList.last.adjustment?.posAdjustment ?? 0) -
      (bpList.first.adjustment?.negAdjustment ?? 0);

  /*
  if (bpList.first.yAdjustment != 0) {
    print("non empty y adjustment");
  }
  */

  Offset startP = drawC.canvas.globalToLocal(Offset(
      bpList.first.notePosition.dx +
          (up
                  ? bpList.first.noteAnchor.stemUpSE.dx
                  : bpList.first.noteAnchor.stemDownNW.dx) *
              drawC.lineSpacing,
      bpList.first.notePosition.dy + sign * (startStemLength)));

  Offset endP = drawC.canvas.globalToLocal(Offset(
      bpList.last.notePosition.dx +
          (up
                  ? bpList.last.noteAnchor.stemUpSE.dx
                  : bpList.last.noteAnchor.stemDownNW.dx) *
              drawC.lineSpacing,
      bpList.last.notePosition.dy + sign * (endStemLength)));

  // find the slope using the two end point
  double slope = (endP.dy - startP.dy) / (endP.dx - startP.dx);
  // intercept with each stem to see if we need to make the stem at end point longer
  // the line equation is
  // y - start.y / x - start.x = slope
  // set x = x0, we can get the y

  double maxDelta = 0;
  for (int i = 0; i < bpList.length; i++) {
    var p = drawC.canvas.globalToLocal(Offset(
        bpList[i].notePosition.dx +
            (up
                    ? bpList[i].noteAnchor.stemUpSE.dx
                    : bpList[i].noteAnchor.stemDownNW.dx) *
                drawC.lineSpacing,
        bpList[i].notePosition.dy));
    double y = slope * (p.dx - startP.dx) + startP.dy;
    double dist = (y - p.dy) * sign;
    if (dist < minStemLength) {
      double delta = minStemLength - dist;
      if (delta > maxDelta) {
        maxDelta = delta;
      }
    }
  }

  return StemLengthReturn(startStemLength + maxDelta, endStemLength + maxDelta);
}

Clefs getNoteStaffWithContext(MeasureContext mc, int numberStaff) {
  Clefs staff;
  try {
    // staff = drawC.latestAttributes.clefs!
    staff = mc.currentAttributes!.clefs!
        .firstWhere((clef) => clef.staffNumber == numberStaff)
        .sign;
  } catch (e) {
    staff = Clefs.G;
  }
  return staff;
}

class BeamChordHint {
  // adjustment along the stem direction
  double posAdjustment;
  // adjustment reverse to the stem direction
  double negAdjustment;

  BeamChordHint({required this.posAdjustment, required this.negAdjustment});
}

double intersectVerticalLine(Offset p1, Offset p2, double x) {
  if (p2.dx == p1.dx) return double.nan;
  double slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
  return (x - p1.dx) * slope + p1.dy;
}

paintPitchNote(DrawingContext drawC, MeasureContext mc, PitchNote note,
    {bool noAdvance = false,
    Color color = Colors.black,
    String stemHint = "",
    BeamChordHint? beamChordHint = null,
    double xAdjustment = 0

    // the adjustment along x direction
    // this is because two note in a chord is too close vertically
    }) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lineSpacing;
  final tone = drawC.latestAttributes.key!.fifths;
  Clefs staff = getNoteStaffWithContext(mc, note.staff);

  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue());
  // if its a chord, we only draw the note flag once
  // we might need to draw stem, but don't draw the flag
  // but currently I don't know how to control this
  bool drawNoteWithStem = note.beams.isEmpty;
  NoteLength noteLength = notePosition.length;

  if (stemHint != "") {
    if (stemHint == "no-stem") drawNoteWithStem = false;
    // if we draw only stem, no flag, we draw the note as quater note
    if (stemHint == "stem") noteLength = NoteLength.quarter;
  }

  if (xAdjustment != 0) {
    drawNoteWithStem = false;
  }
  if (noAdvance) {
    drawC.canvas.save();
  }

  drawC.canvas.translate(
    0,
    (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  final noteGlyph = drawNoteWithStem
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[noteLength]!
          : singleNoteDownByLength[noteLength]!)
      : singleNoteHeadByLength[noteLength]!;

  double yOffset = (lineSpacing / 2) * offset;

  double widthAdj = calculateGlyphWidth(drawC, noteGlyph);
  // check if we need to paint tie
  for (var notation in note.notations) {
    if (notation is Tied) {
      if (notation.type == StCtStpValue.start) {
        double x = drawC.canvas.getTranslation().dx;
        mc.startTie(note, x, yOffset);
      } else if (notation.type == StCtStpValue.stop) {
        double x = drawC.canvas.getTranslation().dx;
        var tc = mc.stopTie(note);
        if (tc != null) {
          // print("stop tie y = ${tc.y}");
          // print("transform 2 = ${drawC.canvas.getTranslation()}");
          // XXX somehow the tie is painted high, we hard code this adjust here
          double yAdjust = 3.0 * (lineSpacing / 2);
          // double yAdjust = 0;
          paintTie(
              drawC,
              // relative to current x
              Offset(tc.x - x + widthAdj, tc.y + yAdjust),
              Offset(0, yOffset + yAdjust));
        }
      }
    }
  }

  // paint dot if needed
  if (note.dots > 0) {
    // lets paint only one dot first
    // if note is on the line, we raise it by half interval
    double dotYOffset = yOffset;

    if ((offset % 2) == 0) {
      dotYOffset -= (lineSpacing / 2);
    }
    dotYOffset += 18; // XXX no idea why we need this
    paintDot(drawC, dotYOffset);
  }

  // print("transform 1 = ${drawC.canvas.getTranslation()}");

  if (xAdjustment != 0) {
    drawC.canvas.translate(xAdjustment, 0);
  }
  paintGlyph(
    drawC,
    noteGlyph,
    yOffset: yOffset,
    noAdvance: true,
    color: color,
  );
  if (xAdjustment != 0) {
    drawC.canvas.translate(-xAdjustment, 0);
  }

  if (note.beams.isNotEmpty) {
    final noteAnchor = GLYPH_ANCHORS[noteGlyph];

    final currentBeamPointMapForThisId =
        drawC.currentBeamPointsPerID[note.beams.first.id] ?? {};
    drawC.currentBeamPointsPerID[note.beams.first.id] =
        currentBeamPointMapForThisId;

    final beamAbove = currentBeamPointMapForThisId.isNotEmpty
        ? currentBeamPointMapForThisId[1]!.first.drawAbove
        : note.stem == StemValue.up;
    for (final elmt in note.beams) {
      if (currentBeamPointMapForThisId[elmt.number] == null) {
        currentBeamPointMapForThisId[elmt.number] = [];
      }
      print("measure ${drawC.currentMeasure} beam ${elmt.number}");
      /*
      if (beamChordHint != null) {
        print("beamcord ${beamChordHint}");
      }
      */
      currentBeamPointMapForThisId[elmt.number]!.add(
        BeamPoint(
          elmt,
          drawC.canvas.localToGlobal(Offset(0, (lineSpacing / 2) * offset)),
          noteAnchor!,
          beamAbove,
          adjustment: beamChordHint,
        ),
      );
    }

    final openBeams = getOpenBeams(currentBeamPointMapForThisId);

    if (openBeams.isEmpty) {
      bool hasPrevOffset = false;
      Offset prevStartOffset = Offset(0, 0);
      Offset prevEndOffset = Offset(0, 0);

      int nBeam = 0;
      StemLengthReturn? ret;
      for (final beamPoints in currentBeamPointMapForThisId.entries) {
        final BeamPoint start = beamPoints.value.first;
        final BeamPoint end = beamPoints.value.last;

        final beamOrderFromBottom =
            (currentBeamPointMapForThisId.length - nBeam);
        nBeam++;

        // change beamPoints.key -> beamOrderFromBottom
        // it seems usually the outermost beam is specified first
        // so the beamOrderFromBottom above is the index counting from the
        // note
        /*
        final double steamLength = lineSpacing * 2 +
            // beamPoints.key *
            beamOrderFromBottom *
                (ENGRAVING_DEFAULTS.beamThickness * lineSpacing +
                    ENGRAVING_DEFAULTS.beamSpacing * lineSpacing);
                    */

        Offset startOffset, endOffset;

        //
        // TODO: some stem are too short because of beam
        // problem is this code use constant length from start and end
        // probably should compute the length to guarantee the stem not too short
        //
        // by reading the code, the y coordinate seems to be
        // (always need to add staffHeight/2)
        // negative is up
        //
        if (ret == null) {
          ret = computeStemLengthFromBeam(
              beamPoints.value, start.drawAbove, drawC);

          final startStemLength = ret.startLength +
              beamOrderFromBottom *
                  (ENGRAVING_DEFAULTS.beamThickness * lineSpacing +
                      ENGRAVING_DEFAULTS.beamSpacing * lineSpacing);
          final endStemLength = ret.endLength +
              beamOrderFromBottom *
                  (ENGRAVING_DEFAULTS.beamThickness * lineSpacing +
                      ENGRAVING_DEFAULTS.beamSpacing * lineSpacing);
          if (start.drawAbove) {
            startOffset = drawC.canvas.globalToLocal(Offset(
              start.notePosition.dx +
                  start.noteAnchor.stemUpSE.dx * lineSpacing,
              start.notePosition.dy +
                  (drawC.staffHeight / 2) -
                  /* steamLength */ startStemLength -
                  (ENGRAVING_DEFAULTS.beamThickness * lineSpacing) +
                  start.noteAnchor.stemUpSE.dy * lineSpacing,
            ));
            endOffset = drawC.canvas.globalToLocal(Offset(
              end.notePosition.dx + end.noteAnchor.stemUpSE.dx * lineSpacing,
              end.notePosition.dy +
                  (drawC.staffHeight / 2) -
                  /* steamLength */ endStemLength -
                  (ENGRAVING_DEFAULTS.beamThickness * lineSpacing) +
                  end.noteAnchor.stemUpSE.dy * lineSpacing,
            ));
          } else {
            startOffset = drawC.canvas.globalToLocal(Offset(
              start.notePosition.dx +
                  start.noteAnchor.stemDownNW.dx * lineSpacing,
              start.notePosition.dy +
                  (drawC.staffHeight / 2) +
                  /* steamLength */ startStemLength +
                  start.noteAnchor.stemDownNW.dy * lineSpacing,
            ));
            endOffset = drawC.canvas.globalToLocal(Offset(
              end.notePosition.dx + end.noteAnchor.stemDownNW.dx * lineSpacing,
              end.notePosition.dy +
                  (drawC.staffHeight / 2) +
                  /*steamLength*/ endStemLength +
                  end.noteAnchor.stemDownNW.dy * lineSpacing,
            ));
          }
        } else {
          // calculate new startOffset, endOffset based on prevStartOffset, prevEndOffset
          // a line between prevStartOffset, prevEndOffset intersect with current x
          double startX;
          double endX;
          if (start.drawAbove) {
            startX = drawC.canvas
                .globalToLocal(Offset(
                    start.notePosition.dx +
                        start.noteAnchor.stemUpSE.dx * lineSpacing,
                    0))
                .dx;

            endX = drawC.canvas
                .globalToLocal(Offset(
                    end.notePosition.dx +
                        end.noteAnchor.stemUpSE.dx * lineSpacing,
                    0))
                .dx;
          } else {
            startX = drawC.canvas
                .globalToLocal(Offset(
                    start.notePosition.dx +
                        start.noteAnchor.stemDownNW.dx * lineSpacing,
                    0))
                .dx;

            endX = drawC.canvas
                .globalToLocal(Offset(
                    end.notePosition.dx +
                        end.noteAnchor.stemDownNW.dx * lineSpacing,
                    0))
                .dx;
          }
          if (startX.isNaN || endX.isNaN) {
            continue;
          }
          startOffset = Offset(
              startX,
              intersectVerticalLine(prevStartOffset, prevEndOffset, startX) +
                  (start.drawAbove ? 1 : -1) *
                      (ENGRAVING_DEFAULTS.beamThickness * lineSpacing +
                          ENGRAVING_DEFAULTS.beamSpacing * lineSpacing));
          endOffset = Offset(
              endX,
              intersectVerticalLine(prevStartOffset, prevEndOffset, endX) +
                  (start.drawAbove ? 1 : -1) *
                      (ENGRAVING_DEFAULTS.beamThickness * lineSpacing +
                          ENGRAVING_DEFAULTS.beamSpacing * lineSpacing));
        }
        if (end.beam.value == BeamValue.backward) {
          // need to draw backward hook
          if (hasPrevOffset) {
            double prevSlope = (prevEndOffset.dy - prevStartOffset.dy) /
                (prevEndOffset.dx - prevStartOffset.dx);
            double hookXLen = (prevEndOffset.dx - prevStartOffset.dx) / 2;
            startOffset = Offset(
                endOffset.dx - hookXLen, endOffset.dy - hookXLen * prevSlope);
          }
        }
        hasPrevOffset = true;
        prevStartOffset = startOffset;
        prevEndOffset = endOffset;
        print("draw beam ${startOffset} ${endOffset}");
        paintBeam(drawC, startOffset, endOffset);

        for (final beamPoint in beamPoints.value) {
          Offset stemOffsetStart, stemOffsetEnd;
          double stemOffsetYEnd = 0;
          if (beamPoint.drawAbove) {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx +
                  beamPoint.noteAnchor.stemUpSE.dx * lineSpacing,
              beamPoint.notePosition.dy +
                  (drawC.staffHeight / 2) +
                  beamPoint.noteAnchor.stemUpSE.dy * lineSpacing +
                  (beamPoint.adjustment?.negAdjustment ?? 0),
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            stemOffsetYEnd = ((endOffsetGlobal.dx - startOffsetGlobal.dx) == 0
                    ? 0
                    : ((beamPoint.notePosition.dx +
                                beamPoint.noteAnchor.stemUpSE.dx *
                                    lineSpacing) -
                            startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) /
                            (endOffsetGlobal.dx - startOffsetGlobal.dx))) +
                startOffsetGlobal.dy;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx +
                  beamPoint.noteAnchor.stemUpSE.dx * lineSpacing,
              stemOffsetYEnd,
            ));
          } else {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx +
                  beamPoint.noteAnchor.stemDownNW.dx * lineSpacing,
              beamPoint.notePosition.dy +
                  (drawC.staffHeight / 2) +
                  beamPoint.noteAnchor.stemDownNW.dy * lineSpacing -
                  (beamPoint.adjustment?.negAdjustment ?? 0),
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            stemOffsetYEnd = ((endOffsetGlobal.dx - startOffsetGlobal.dx) == 0
                    ? 0
                    : ((beamPoint.notePosition.dx +
                                beamPoint.noteAnchor.stemDownNW.dx *
                                    lineSpacing) -
                            startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) /
                            (endOffsetGlobal.dx - startOffsetGlobal.dx))) +
                startOffsetGlobal.dy +
                ENGRAVING_DEFAULTS.beamThickness * lineSpacing;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx +
                  beamPoint.noteAnchor.stemDownNW.dx * lineSpacing,
              stemOffsetYEnd,
            ));
          }

          paintStem(drawC, stemOffsetStart, stemOffsetEnd);
        }
      }

      // Everything has been drawn, now it is time to reset the
      // beam context list, so that it is ready for the next
      // beam group that might come.
      drawC.currentBeamPointsPerID.remove(note.beams.first.id);
    }
  }

  paintLedgers(drawC, staff, tone, notePosition);

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;

    drawC.canvas.translate(
        -GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lineSpacing -
            ENGRAVING_DEFAULTS.barlineSeparation * lineSpacing,
        0);

    paintGlyph(
      drawC,
      accidentalGlyph,
      yOffset: (lineSpacing / 2) *
          calculateYOffsetForNote(staff, notePosition.positionalValue()),
      noAdvance: true,
    );
  }

  drawC.canvas.translate(
    0,
    -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

double logBase(num x, num base) => log(x) / log(base);
double log2(num x) => logBase(x, 2);

double durationToRestLengthIndex(DrawingContext drawC, int duration) {
  // return ((drawC.latestAttributes.divisions! * 4) / duration) / 2;
  return log2(drawC.latestAttributes.divisions! * 4 / duration);
}

paintRestNote(DrawingContext drawC, RestNote note,
    {bool noAdvance = false, double yOffset = 0}) {
  drawC.canvas.translate(
      0, (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));

  var restGlyph = GLYPHRANGE_MAP[GlyphRange.rests]!.glyphs[
      durationToRestLengthIndex(drawC, note.duration).round() +
          3]; // whole rest begins at index 3

  paintGlyph(drawC, restGlyph, noAdvance: noAdvance, yOffset: yOffset);

  drawC.canvas.translate(
      0, -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));
}

bool shouldPaintAccidental(
    DrawingContext drawC, Clefs staff, NotePosition note) {
  if (note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;
  List<NotePosition> alreadyAppliedAccidentals = staff == Clefs.G
      ? mainToneAccidentalsMapForGClef[tone]!
      : mainToneAccidentalsMapForFClef[tone]!;
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any(
      (accidental) =>
          accidental.tone == note.tone &&
          (accidental.accidental == note.accidental ||
              note.accidental == Accidentals.natural));
  return (!alreadyAppliedAccidentalExists &&
          note.accidental != Accidentals.natural) ||
      (alreadyAppliedAccidentalExists &&
          note.accidental == Accidentals.natural);
}

PitchNoteRenderMeasurements calculateNoteWidth(
    DrawingContext drawC, MeasureContext mc, PitchNote note) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lineSpacing;
  Clefs staff;

  try {
    // staff = drawC.latestAttributes.clefs!
    staff = mc.currentAttributes!.clefs!
        .firstWhere((clef) => clef.staffNumber == note.staff)
        .sign;
  } catch (e) {
    // return PitchNoteRenderMeasurements(Rect.zero, GlyphAnchor());
    staff = Clefs.G;
  }
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue());
  bool drawBeamedNote = note.beams.isEmpty;

  final noteGlyph = drawBeamedNote
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  double leftBorder = 0;
  double rightBorder = GLYPH_ADVANCE_WIDTHS[noteGlyph]! * lineSpacing;
  double topBorder =
      (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;
  double bottomBorder =
      (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;
    leftBorder = -GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lineSpacing -
        ENGRAVING_DEFAULTS.barlineSeparation * lineSpacing;

    final potTopBorder = (lineSpacing / 2) *
            calculateYOffsetForNote(staff, notePosition.positionalValue()) +
        GLYPH_BBOXES[accidentalGlyph]!.northEast.dy;

    final potBottomBorder = (lineSpacing / 2) *
            calculateYOffsetForNote(staff, notePosition.positionalValue()) +
        GLYPH_BBOXES[accidentalGlyph]!.southWest.dy;

    topBorder = potTopBorder < topBorder ? potTopBorder : topBorder;
    bottomBorder =
        potBottomBorder < bottomBorder ? potBottomBorder : bottomBorder;
  }

  return PitchNoteRenderMeasurements(
    Rect.fromLTRB(leftBorder, topBorder, rightBorder, bottomBorder),
    (GLYPH_ANCHORS[noteGlyph] ?? GlyphAnchor())
        .translate(Offset(0, (lineSpacing / 2) * offset)),
  );
}

const stdNotePositionGClef =
    NotePosition(tone: BaseTones.B, octave: 2, length: NoteLength.quarter);
const stdNotePositionFClef =
    NotePosition(tone: BaseTones.D, octave: 1, length: NoteLength.quarter);

const Map<Clefs, NotePosition> stdNotePosition = {
  Clefs.G: stdNotePositionGClef,
  Clefs.F: stdNotePositionFClef,
};

const topStaffLineNoteGClef =
    NotePosition(tone: BaseTones.F, octave: 3, length: NoteLength.quarter);
const bottomStaffLineNoteGClef =
    NotePosition(tone: BaseTones.E, octave: 2, length: NoteLength.quarter);

const topStaffLineNoteFClef =
    NotePosition(tone: BaseTones.A, octave: 1, length: NoteLength.quarter);
const bottomStaffLineNoteFClef =
    NotePosition(tone: BaseTones.G, octave: 0, length: NoteLength.quarter);

const Map<Clefs, NotePosition> topStaffLineNote = {
  Clefs.G: topStaffLineNoteGClef,
  Clefs.F: topStaffLineNoteFClef,
};

const Map<Clefs, NotePosition> bottomStaffLineNote = {
  Clefs.G: bottomStaffLineNoteGClef,
  Clefs.F: bottomStaffLineNoteFClef,
};

int topStaffLineOffset(Clefs clef) {
  if (clef == Clefs.G) {
    return topStaffLineNoteGClef.positionalValue();
  } else {
    return topStaffLineNoteFClef.positionalValue();
  }
}

int bottomStaffLineOffset(Clefs clef) {
  if (clef == Clefs.G) {
    return bottomStaffLineNoteGClef.positionalValue();
  } else {
    return bottomStaffLineNoteFClef.positionalValue();
  }
}

int calculateYOffsetForNote(Clefs clef, int positionalValue) {
  int diff = 0;
  if (clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue() - positionalValue;
  } else if (clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue() - positionalValue;
  }
  return diff;
}
