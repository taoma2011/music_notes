import 'dart:ui';
import 'package:flutter/material.dart';
import 'common.dart';
import 'glyph.dart';
import '../notes.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../../ExtendedCanvas.dart';
import '../../musicXML/data.dart';

paintLedgers(XCanvas canvas, Size size, double staffHeight, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G: {
      if(note.positionalValue() > topStaffLineNoteGClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteGClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteGClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteGClef.positionalValue()) / 2).floor();
      }
      break;
    }
    case Clefs.F: {
      if(note.positionalValue() > topStaffLineNoteFClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteFClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteFClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteFClef.positionalValue()) / 2).floor();
      }
    }
  }

  double lineSpacing = getLineSpacing(staffHeight);
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length!]!]!*lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for(int i = numLedgersToDraw; i != 0;) {
    if(i < 0) {
      // one staff height because, the visible staff lines begin one staff height below the top y 0.
      // And then another staff height for actual visible staff.
      // TODO: We should not hardwire the space over the staff
      double pos = (-i*2)*(lineSpacing/2) + (staffHeight*2);
      canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i++;
    } else {
      // one staff height because, the visible staff lines begin one staff height below the top y 0.
      // And then another staff height for actual visible staff.
      // TODO: We should not hardwire the space over the staff
      double pos = staffHeight - (i*2)*(lineSpacing/2);
      canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

paintSingleNote(XCanvas canvas, Size size, double staffHeight, Clefs staff, Fifths tone, NotePosition note, {bool? stemUp}) {
  double lineSpacing = getLineSpacing(staffHeight);
  int offset = calculateYOffsetForNote(staff, note);
  bool decideStemUp = stemUp != null ? stemUp : offset < 8;
  paintGlyph(
    canvas,
    size,
    staffHeight,
    // TODO: We should probably draw the stem up or down ourselves
    decideStemUp ? singleNoteUpByLength[note.length!] : singleNoteDownByLength[note.length!],
    offset: Offset(
      0,
      ((lineSpacing/2) * offset),
    ),
    noAdvance: true,
  );

  paintLedgers(canvas, size, staffHeight, staff, tone, note);

  canvas.translate(GLYPH_ADVANCE_WIDTHS[singleNoteUpByLength[note.length!]!]!*lineSpacing, 0);

  List<NotePosition> alreadyAppliedAccidentals = staff == Clefs.G ? mainToneAccidentalsMapForGClef[tone]! : mainToneAccidentalsMapForFClef[tone]!;
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any(
          (accidental) =>
      accidental.tone == note.tone
          && (accidental.accidental == note.accidental || note.accidental == Accidentals.natural)
  );
  if(
  (!alreadyAppliedAccidentalExists && note.accidental != Accidentals.natural)
      ||  (alreadyAppliedAccidentalExists && note.accidental == Accidentals.natural)
  ) {
    canvas.translate(ENGRAVING_DEFAULTS.barlineSeparation*lineSpacing, 0);

    paintGlyph(
      canvas,
      size,
      staffHeight,
      accidentalGlyphMap[note.accidental],
      offset: Offset(
        0,
        ((lineSpacing/2) * calculateYOffsetForNote(staff, note)),
      ),
    );
  }
}

const stdNotePositionGClef = NotePosition(tone: BaseTones.C, octave: 4);
const stdNotePositionFClef = NotePosition(tone: BaseTones.E, octave: 2);

const Map<Clefs, NotePosition> stdNotePosition = {
  Clefs.G: stdNotePositionGClef,
  Clefs.F: stdNotePositionFClef,
};

const topStaffLineNoteGClef = NotePosition(tone: BaseTones.F, octave: 3);
const bottomStaffLineNoteGClef = NotePosition(tone: BaseTones.E, octave: 2);

const topStaffLineNoteFClef = NotePosition(tone: BaseTones.A, octave: 1);
const bottomStaffLineNoteFClef = NotePosition(tone: BaseTones.G, octave: 0);

const Map<Clefs, NotePosition> topStaffLineNote = {
  Clefs.G: topStaffLineNoteGClef,
  Clefs.F: topStaffLineNoteFClef,
};

const Map<Clefs, NotePosition> bottomStaffLineNote = {
  Clefs.G: bottomStaffLineNoteGClef,
  Clefs.F: bottomStaffLineNoteFClef,
};

int calculateYOffsetForNote(Clefs clef, NotePosition note) {
  int diff = 0;
  if(clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue() - note.positionalValue();
  } else if(clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue() - note.positionalValue();
  }
  return diff;
}