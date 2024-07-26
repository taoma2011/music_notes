import 'dart:math';
import 'dart:core';
import 'package:music_notes/musicXML/parser.dart';
import 'package:music_notes/graphics/generated/engraving-defaults.dart';
import 'package:music_notes/graphics/render-functions/glyph.dart';
import 'package:music_notes/graphics/render-functions/note.dart';
import 'package:music_notes/bloc/matcher_bloc.dart';
import 'package:flutter/material.dart';
import '../music-line.dart';
import '../notes.dart';
import '../render-functions/staff.dart';
import '../../musicXML/data.dart';
import 'package:collection/collection.dart';

// get the length of measure so we can decide how many to put in a single line
Rect getMeasureLength(Measure measure, MeasureContext mc, DrawingContext drawC,
    MusicLineOptions options) {
  final grid = createGridForMeasure(measure, drawC);
  final layoutResult = layoutGrid(grid, mc, drawC, options);
  /*
  double left = 0, right = 0;

  grid.forEachIndexed((columnIndex, column) {
    final measurements = column
        .whereType<PitchNote>()
        .map((element) => calculateNoteWidth(drawC, mc, element));

    // check if we have defaultX
    double defaultX = 0;
    for (var pn in column.whereType<PitchNote>()) {
      if (pn.defaultX != 0) {
        if (defaultX == 0) {
          defaultX = pn.defaultX;
        } else if (pn.defaultX != defaultX) {
          print("different default x in same column");
          defaultX = 0;
          break;
        }
      }
    }

    double attributeWidth = 0;

    for (var content in column) {
      if (content is Attributes) {
        // hopefully there is only one attribute in the column
        if (content.clefs != null && (!mc.isFirstBar || columnIndex != 0)) {
          attributeWidth = (20 + drawC.lineSpacing).toDouble();
        } else {
          attributeWidth =
              calculateMeasureAttributesWidth(content, drawC, mc).toDouble();
        }
        print("adding attribute width $attributeWidth");
      }
    }
    right += attributeWidth;
    final alignmentOffset = calculateColumnAlignment(drawC, measurements);
    right += alignmentOffset.left.abs() + alignmentOffset.right;

    if (defaultX != 0) {
      right = defaultX + alignmentOffset.right;
    }

    if (!column.isEmpty && column.last is RestNote) {
      right += drawC.lineSpacing;
    }
    if (column.length > 0) right += drawC.lineSpacing;
  });
  right += drawC.lineSpacing;

  */

  // return Rect.fromLTRB(left, 0, right, 0);

  return Rect.fromLTRB(0, 0,
      layoutResult.layouts.isEmpty ? 0 : layoutResult.layouts.last.right, 0);
}

// this process a range which contains one or many rest note
// the output is it put layout hint to the layoutMap
void processRun(List<MeasureContent> column, int runStart, int runEnd,
    double startOffset, double endOffset, Map<int, double> layoutMap) {
  int nRestNote = 0;
  for (int k = runStart; k < runEnd; k++) {
    if (column[k] is RestNote) {
      nRestNote++;
    }
  }
  print("layoutmap numrest note = ${nRestNote}");
  int count = 1;
  // evenly divide the space between the rest note
  for (int k = runStart; k < runEnd; k++) {
    if (column[k] is RestNote) {
      var interNoteDistance = (endOffset - startOffset) / (nRestNote + 1);
      if (interNoteDistance < 10) {
        // if we don't have room, just dont show it
        layoutMap[k] = -1;
      } else {
        var yOffset = startOffset + count * interNoteDistance;
        print("set layoutmap ${k} to ${yOffset}");
        // for multiple rest note within a run, we currently cannot display it well
        // so we just display only the first one for now
        layoutMap[k] = yOffset;
      }

      count++;
    }
  }
}

// chord start/end (end is inclusive)
// output hint
// for note without beam and which is part of chord, we maintain a table of
// status, its either
// "no-stem", "stem", "stem-flag"

class NoteTag {
  int index;
  int midiNote;
  NoteTag({required this.index, required this.midiNote});
}

void processChord(List<MeasureContent> column, int chordStart, int chordEnd,
    Map<int, String> chordHintMap, Map<int, double> xAdjustmentMap) {
  List<NoteTag> tags = [];
  bool isUp = false;
  bool noStem = false;
  for (int i = chordStart; i <= chordEnd; i++) {
    if (column[i] is PitchNote) {
      var pn = column[i] as PitchNote;
      if (i == chordStart) {
        isUp = (pn.stem == StemValue.up);
        if (pn.type == NoteLength.whole || pn.type == NoteLength.half) {
          noStem = true;
        }
      }

      tags.add(NoteTag(index: i, midiNote: PitchToMidiNote(pn.pitch)));
    }
  }
  if (noStem) {
    tags.forEach((element) {
      chordHintMap[element.index] = "no-stem";
    });
    return;
  }
  if (isUp) {
    tags.sortByCompare<int>((element) => element.midiNote, (a, b) => a - b);
  } else {
    tags.sortByCompare<int>((element) => element.midiNote, (a, b) => b - a);
  }

  processTooCloseNote(column, tags, xAdjustmentMap);

  tags.forEach((element) {
    chordHintMap[element.index] = "stem";
  });
  chordHintMap[tags.first.index] = "stem-flag";
}

void processTooCloseNote(List<MeasureContent> column, List<NoteTag> tags,
    Map<int, double> xAdjustmentMap) {
  double xAdjustMag = 10;
  // walk the notes see if any two of them are closed
  for (int i = 1; i < tags.length; i++) {
    var thisNote = column[tags[i].index] as PitchNote;
    var prevNote = column[tags[i - 1].index] as PitchNote;
    if ((thisNote.notePosition.positionalValue() -
                prevNote.notePosition.positionalValue())
            .abs() ==
        1) {
      if (xAdjustmentMap[tags[i - 1].index] == null) {
        // print("xadjustment of ${tags[i].index}");
        xAdjustmentMap[tags[i].index] =
            xAdjustMag * (thisNote.stem == StemValue.down ? -1 : 1);
      }
    }
  }
}

//
// find which one is the "highest point" in a chord, the direction is
// the stem direction
//
void processBeamChord(
    List<MeasureContent> column,
    int chordStart,
    int chordEnd,
    DrawingContext drawC,
    MeasureContext mc,
    Map<int, BeamChordHint> beamChordHintMap,
    Map<int, String> chordHintMap,
    Map<int, double> xAdjustmentMap) {
  List<NoteTag> tags = [];
  bool isUp = false;
  for (int i = chordStart; i <= chordEnd; i++) {
    if (column[i] is PitchNote) {
      var pn = column[i] as PitchNote;
      if (i == chordStart) {
        isUp = (pn.stem == StemValue.up);
      } else {
        chordHintMap[i] = "no-stem";
      }
      tags.add(NoteTag(index: i, midiNote: PitchToMidiNote(pn.pitch)));
    }
  }
  if (isUp) {
    tags.sortByCompare<int>((element) => element.midiNote, (a, b) => a - b);
  } else {
    tags.sortByCompare<int>((element) => element.midiNote, (a, b) => b - a);
  }

  processTooCloseNote(column, tags, xAdjustmentMap);

  var noteOffset = (PitchNote note) {
    Clefs staff = getNoteStaffWithContext(mc, note.staff);

    // int offset =
    // calculateYOffsetForNote(staff, note.notePosition.positionalValue());
    int offset = note.notePosition.positionalValue();
    return offset;
  };

  int startOffset = noteOffset(column[chordStart] as PitchNote);
  int endOffset = noteOffset(column[chordEnd] as PitchNote);

  double adjust =
      (endOffset - startOffset).abs().toDouble() * (drawC.lineSpacing / 2);
  if (tags.first.index == chordStart) {
    // the chord grows same to the stem direction
    beamChordHintMap[chordStart] =
        BeamChordHint(posAdjustment: adjust, negAdjustment: 0);
  } else {
    beamChordHintMap[chordStart] =
        BeamChordHint(posAdjustment: adjust, negAdjustment: adjust);
  }
}

paintMeasure(
    Measure measure,
    DrawingContext drawC,
    MeasureContext mc,
    MusicLineOptions options,
    CurrentPlay currentPlay,
    MatcherState matcherState) {
  bool paintedBarline = false;

  final grid = createGridForMeasure(measure, drawC);
  // print('paint measure');

  final layoutData = layoutGrid(grid, mc, drawC, options);

  var measureStartTranslation = drawC.canvas.getTranslation();

  grid.forEachIndexed((columnIndex, column) {
    final measurements = column
        .whereType<PitchNote>()
        .map((element) => calculateNoteWidth(drawC, mc, element));
    final alignmentOffset = calculateColumnAlignment(drawC, measurements);

    double pitchNoteLeftOffset = alignmentOffset.left.abs();

    var layouts = layoutData.layouts[columnIndex];

    bool playingThisMeasure =
        (drawC.currentMeasure == currentPlay.currentMeasure);
    /*
    if (currentPlay.currentColumn == columnIndex &&
        ) {
      print("use red color for note");
      noteColor = Colors.red;
    }*/

    // TODO: do a column layout here
    /*
    for rest note, need to find space so that they dont overlap with each other
    for pitch note, use this formula to compute the offset
    (lineSpacing / 2) *
          calculateYOffsetForNote(staff, notePosition.positionalValue())
          */
    Map<int, double> verticalLayoutMap = {};

    int currentStaff = 1;
    int runStart = -1;
    double startOffset = double.nan;

    int roomForRestNote = 10;
    var staffTop = (int staff) =>
        (drawC.lineSpacing / 2) *
        calculateYOffsetForNote(
            getNoteStaffWithContext(mc, staff),
            topStaffLineOffset(getNoteStaffWithContext(mc, staff)) +
                roomForRestNote);

    var staffBottom = (int staff) =>
        (drawC.lineSpacing / 2) *
        calculateYOffsetForNote(
            getNoteStaffWithContext(mc, staff),
            bottomStaffLineOffset(getNoteStaffWithContext(mc, staff)) -
                roomForRestNote);

    for (int i = 0; i < column.length; i++) {
      var measureContent = column[i];

      // try to find a pitch note to end the run
      if (measureContent is PitchNote) {
        var pn = measureContent;

        double thisOffset = (drawC.lineSpacing / 2) *
            calculateYOffsetForNote(getNoteStaffWithContext(mc, pn.staff),
                pn.notePosition.positionalValue());
        if (runStart >= 0) {
          // process the run
          processRun(
              column,
              runStart,
              i,
              !startOffset.isNaN ? startOffset : staffTop(currentStaff),
              // if we switch staff, we will terminate the run at previous staff end
              (pn.staff != currentStaff)
                  ? staffBottom(currentStaff)
                  : thisOffset,
              verticalLayoutMap);
          runStart = -1;
        }

        startOffset = thisOffset;
        currentStaff = pn.staff;
      } else if (measureContent is RestNote) {
        var rn = measureContent;
        if (runStart < 0) {
          runStart = i;
          currentStaff = rn.staff;
        } else if (rn.staff != currentStaff) {
          processRun(
              column,
              runStart,
              i,
              !startOffset.isNaN ? startOffset : staffTop(currentStaff),
              staffBottom(currentStaff),
              verticalLayoutMap);
          runStart = i;
          currentStaff = rn.staff;
          startOffset = double.nan;
        }
      }
    }

    if (runStart >= 0 && runStart != column.length - 1) {
      // still have some left over content
      processRun(
          column,
          runStart,
          column.length,
          startOffset >= 0 ? startOffset : staffTop(currentStaff),
          staffBottom(currentStaff),
          verticalLayoutMap);
    }

    //
    // another preprocess for a column, if its a chord, we figure out which one should be painted with stem/flag
    // for note without beam and which is part of chord, we maintain a table of
    // status, its either
    // "no-stem", "stem", "stem-flag"
    //
    Map<int, String> chordHintMap = {};
    Map<int, BeamChordHint> beamChordHintMap = {};
    Map<int, double> xAdjustmentMap = {};
    int prevNote = -1;
    int chordStart = -1;

    for (int i = 0; i < column.length; i++) {
      var measureContent = column[i];
      if (measureContent is PitchNote) {
        var pn = measureContent;
        if (pn.chord) {
          if (chordStart < 0) {
            chordStart = prevNote;
          }
        } else {
          if (chordStart >= 0) {
            // chord end at prevNote
            // we first check if the chord start has beam, if so we don't need to process it
            if ((column[chordStart] as PitchNote).beams.isEmpty) {
              processChord(
                  column, chordStart, prevNote, chordHintMap, xAdjustmentMap);
            } else {
              processBeamChord(column, chordStart, prevNote, drawC, mc,
                  beamChordHintMap, chordHintMap, xAdjustmentMap);
            }
            chordStart = -1;
          }
        }
        prevNote = i;
      }
    }
    // if we still have a left over chord, process it
    if (chordStart >= 0) {
      if ((column[chordStart] as PitchNote).beams.isEmpty) {
        processChord(
            column, chordStart, prevNote, chordHintMap, xAdjustmentMap);
      } else {
        processBeamChord(column, chordStart, prevNote, drawC, mc,
            beamChordHintMap, chordHintMap, xAdjustmentMap);
      }
    }

    bool startsWithAttributes =
        (column.length > 0 && column[0].runtimeType == Attributes);

    drawC.canvas.setTranslation(Offset(
        measureStartTranslation.dx +
            (!layouts.userDefinedX.isNaN
                ? layouts.userDefinedX
                : layouts.layoutX) +
            (!startsWithAttributes ? pitchNoteLeftOffset : drawC.lineSpacing),
        measureStartTranslation.dy));

    column.forEachIndexed((index, measureContent) {
      bool isLastElement = index == column.length - 1;

      switch (measureContent.runtimeType) {
        case Barline:
          {
            paintBarLine(drawC, measureContent as Barline, false);
            drawC.canvas.translate(drawC.lineSpacing * 1, 0);
            paintedBarline = true;
            break;
          }
        case Attributes:
          {
            // the attributes and the notes are in the same column
            // we use the same spacing as calculated in the
            // calculateMeasureAttributesWidth
            var attributeStartTranslation = drawC.canvas.getTranslation();
            final Attributes a = measureContent as Attributes;
            var attributeLength =
                calculateMeasureAttributesWidth(a, drawC, mc, options);
            paintMeasureAttributes(a, columnIndex, drawC, mc, options);
            // mc.currentAttributes = measureContent;
            mc.mergeAttributes(a);
            drawC.canvas.setTranslation(Offset(
                attributeStartTranslation.dx +
                    attributeLength +
                    pitchNoteLeftOffset,
                attributeStartTranslation.dy));
            break;
          }
        case Direction:
          {
            paintDirection(measureContent as Direction, drawC);
            break;
          }
        case PitchNote:
          {
            /*
            if (defaultX != 0) {
              print(
                  "use defaultX ${defaultX}, compare to ${drawC.canvas.getTranslation().dx + alignmentOffset.left.abs()}");
              // the unit here is "tenth", means 1 is correspond to 1/10 of linespacing
              drawC.canvas.setTranslation(measureStartTranslation +
                  Offset(defaultX * drawC.lineSpacing / 10, 0));
            }
            */

            var pn = measureContent as PitchNote;
            Color noteColor = Colors.black;
            bool isCurrentColumn = false;
            if (playingThisMeasure) {
              // check if this note is active
              int pnStart = columnIndex;
              int pnEnd = pnStart + pn.duration;
              if (currentPlay.currentColumn >= pnStart &&
                  currentPlay.currentColumn < pnEnd) {
                noteColor = Colors.blue;
                isCurrentColumn = true;
              }
            }
            // check if this note is matched by play
            NoteId noteId = NoteId(
                measure: drawC.currentMeasure,
                column: columnIndex,
                index: index,
                midiKey: -1,
                fromPlay: false);
            if (matcherState.matchStatus[noteId] == "matched")
              noteColor = Colors.green;

            paintPitchNote(drawC, mc, pn,
                noAdvance: true,
                color: noteColor,
                stemHint: chordHintMap[index] ?? "",
                beamChordHint: beamChordHintMap[index],
                xAdjustment: xAdjustmentMap[index] ?? 0);

            if (isCurrentColumn) {
              drawC.canvas.save();
              drawC.canvas.translate(0, 0);
              drawC.canvas.drawRect(Rect.fromLTWH(0, -40, 15, 100),
                  Paint()..color = Colors.blue.withAlpha(100));
              drawC.canvas.restore();
            }
            break;
          }
        case RestNote:
          {
            // var t = drawC.canvas.getTranslation();

            double yOffset = verticalLayoutMap[index] ?? 0;
            print("rest note current use offset ${yOffset}");
            if (yOffset >= 0)
              paintRestNote(drawC, measureContent as RestNote,
                  noAdvance: !isLastElement,
                  // this seems not accounted for in the getMeasureLength
                  // noAdvance: true,
                  yOffset: yOffset);

            break;
          }
        default:
          {
            throw new FormatException(
                '${measureContent.runtimeType} is an invalid MeasureContent type');
          }
      }
    });

    List<PlayNote> playNote = currentPlay.play
        .where((n) =>
            (n.column == columnIndex && n.measure == drawC.currentMeasure))
        .toList();
    playNote.forEach((element) {
      Color color = Colors.red;
      NoteId noteId = NoteId(
          measure: drawC.currentMeasure,
          column: columnIndex,
          index: -1,
          midiKey: PitchNoteToMidiNote(element.note),
          fromPlay: true);
      // if its matched, we already paint it in score note
      if (matcherState.matchStatus[noteId] == "matched") return;
      if (matcherState.matchStatus[noteId] == "unmatched") color = Colors.red;

      PitchNote? noteCopy;
      // decide which staff to draw it
      if (mc.currentAttributes!.staves == 2) {
        int noteStaff = 1;
        // NOTE: pitchNote's octave is standard octave - 2
        if (element.note.pitch.octave + 2 < 4) {
          noteStaff = 2;
        }
        noteCopy = element.note.copyWith(staff: noteStaff) as PitchNote;
      } else {
        noteCopy = element.note;
      }
      paintPitchNote(drawC, mc, noteCopy!, noAdvance: true, color: color);
    });

    // drawC.canvas.translate(alignmentOffset.right, 0);

    // TODO: Spacing between columns, currently static, probably needs to be dynamic
    // to justify measures for the whole line
    /*
    if (column.length > 0) {
      drawC.canvas.translate(drawC.lineSpacing * 1, 0);
    }
    */
  });

  if (options.heatMap != null && options.heatMap!.length > 0) {
    var measureEndTranslation = drawC.canvas.getTranslation();
    drawC.canvas.setTranslation(measureStartTranslation);

    double heatMapValue = options.heatMap![drawC.currentMeasure];
    if (heatMapValue >= 0) {
      drawC.canvas.drawRect(
          Rect.fromLTWH(
              0, 0, measureEndTranslation.dx - measureStartTranslation.dx, 3),
          Paint()
            ..color = Color.lerp(Colors.red.withAlpha(100),
                Colors.green.withAlpha(100), heatMapValue)!);
    }
    drawC.canvas.setTranslation(measureEndTranslation);
  }

  if (!paintedBarline) {
    paintBarLine(drawC, Barline(BarLineTypes.regular), false);
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }
}

Rect calculateColumnAlignment(
    DrawingContext drawC, Iterable<PitchNoteRenderMeasurements> measurements) {
  final leftOffset = measurements.fold<double>(
      0, (value, element) => min(value, element.boundingBox.left));
  final rightOffset = measurements.fold<double>(
      0, (value, element) => max(value, element.boundingBox.right));

  return Rect.fromLTRB(leftOffset, 0, rightOffset, 0);
}

class Interval {
  double layoutX;
  double userDefinedX;
  double length;
  double get left {
    return userDefinedX.isNaN ? layoutX : userDefinedX;
  }

  double get right {
    return left + length;
  }

  Interval(
      {this.layoutX = double.nan,
      this.userDefinedX = double.nan,
      this.length = 0});
}

class MeasureContentWithLayout {
  List<List<MeasureContent>> contents;
  List<Interval> layouts;
  MeasureContentWithLayout(this.contents, this.layouts);
}

// end is exclusive
void relayout(
    List<Interval> layouts, int start, int end, double startX, double endX) {
  if (startX >= endX) {
    print("invalid relayout $startX, $endX");
    return;
  }
  double origLength = 0;
  double prevLength = 0;
  // we include the previous symbol length too(which has user defined x)
  if (start > 0) {
    prevLength = layouts[start - 1].length;
    origLength += prevLength;
  }

  for (int i = start; i < end; i++) {
    origLength += layouts[i].length;
  }
  double ratio = origLength / (endX - startX);

  double currentLayoutX = startX;
  for (int i = start; i < end; i++) {
    var l = layouts[i];
    if (l.length > 0) {
      l.layoutX = currentLayoutX + prevLength * ratio;
      // prevLength keep track of running length (number before relayout)
      prevLength += l.length;
      l.length = l.length * ratio;
      currentLayoutX = l.layoutX + l.length;
    } else {
      l.layoutX = currentLayoutX;
    }
  }
}

MeasureContentWithLayout layoutGrid(List<List<MeasureContent>> grid,
    MeasureContext mc, DrawingContext drawC, MusicLineOptions options) {
  final List<Interval> layouts = [];
  double currentX = 0;

  // do first round layout
  grid.forEachIndexed((columnIndex, column) {
    double length = 0;
    final measurements = column
        .whereType<PitchNote>()
        .map((element) => calculateNoteWidth(drawC, mc, element));
    if (column.length > 0 && column[0].runtimeType == Attributes) {
      length += drawC.lineSpacing;
    }
    final alignmentOffset = calculateColumnAlignment(drawC, measurements);
    // not clear why we need the abs
    length += alignmentOffset.left.abs() + alignmentOffset.right;

    // check if we have defaultX
    double defaultX = double.nan;
    for (var pn in column.whereType<PitchNote>()) {
      if (pn.defaultX != 0) {
        if (defaultX == 0) {
          defaultX = pn.defaultX;
        } else if (pn.defaultX != defaultX) {
          print("different default x in same column");
          defaultX = double.nan;
          break;
        }
      }
    }
    if (!defaultX.isNaN) {
      // the unit here is "tenth", means 1 is correspond to 1/10 of linespacing
      defaultX = defaultX * drawC.lineSpacing / 10;
    }

    double attributeWidth = 0;

    for (var content in column) {
      if (content is Attributes) {
        // hopefully there is only one attribute in the column
        if (content.clefs != null && (!mc.isFirstBar || columnIndex != 0)) {
          attributeWidth = (20 + drawC.lineSpacing).toDouble();
        } else {
          attributeWidth =
              calculateMeasureAttributesWidth(content, drawC, mc, options)
                  .toDouble();
        }
        // print("adding attribute width $attributeWidth");
      }
    }

    length += attributeWidth;

    if (!column.isEmpty && column.last is RestNote) {
      length += drawC.lineSpacing;
    }
    if (column.length > 0) length += drawC.lineSpacing;

    layouts.add(
        Interval(layoutX: currentX, userDefinedX: defaultX, length: length));

    currentX += length;
  });

  // identify run of columns between two column with has user layout
  int runStart = -1;
  double lastUserDefinedX = 0;
  for (int i = 0; i < grid.length; i++) {
    if (!layouts[i].userDefinedX.isNaN) {
      if (runStart >= 0) {
        relayout(
            layouts, runStart, i, lastUserDefinedX, layouts[i].userDefinedX);
        runStart = -1;
      }
      lastUserDefinedX = layouts[i].userDefinedX;
    } else {
      // no user defined x
      if (runStart < 0) {
        runStart = i;
      }
    }
  }
  return MeasureContentWithLayout(grid, layouts);
}

List<List<MeasureContent>> createGridForMeasure(
    Measure measure, DrawingContext drawC) {
  // print('prepare grid for measure');
  final columnsOnFourFour = drawC.latestAttributes.divisions! * 4;
  final currentTimeFactor = drawC.latestAttributes.time!.beats /
      drawC.latestAttributes.time!.beatType;
  final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
  if (columnsOnCurrentTime % 1 != 0) {
    // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
    throw new FormatException(
        'Found divisions of ${drawC.latestAttributes.divisions} on a Time of ${drawC.latestAttributes.time!.beats}/${drawC.latestAttributes.time!.beatType}, which does not work.');
  }
  final List<List<MeasureContent>> grid =
      List.generate(columnsOnCurrentTime.toInt() + 1, (i) => []);
  int currentColumnPointer = 0;
  int? chordDuration;
  List<MeasureContent> currentColumn = grid[currentColumnPointer];
  measure.contents.forEachIndexed((index, element) {
    if (currentColumnPointer >= grid.length) {
      throw new FormatException(
          'currentColumnPointer can only beyond end of grid length, if next element is Backup. But was: ${element.runtimeType.toString()}');
    } else {
      currentColumn = grid[currentColumnPointer];
    }
    switch (element.runtimeType) {
      case Barline:
        currentColumn.add(element);
        break;
      case Attributes:
        {
          currentColumn.insert(0, element);
          break;
        }
      case Direction:
        {
          currentColumn.add(element);
          break;
        }
      case RestNote:
      case PitchNote:
        {
          currentColumn.add(element);
          if (element is Note && index < measure.contents.length - 1) {
            final nextElement = measure.contents.elementAt(index + 1);
            if (element is PitchNote && nextElement is PitchNote) {
              element.beams.toList(); // is this no op?
              if (!element.chord) {
                if (nextElement.chord) {
                  // next element is chord note, so we save the current
                  chordDuration = element.duration;
                } else {
                  currentColumnPointer += element.duration;
                }
              } else {
                if (!nextElement.chord) {
                  // next element is not a chord note anymore, so apply saved chordDuration
                  if (chordDuration == null) {
                    throw new FormatException(
                        'End of a chord reached, should have chordDuration, but is null.');
                  }
                  currentColumnPointer += chordDuration!;
                  chordDuration = null;
                }
              }
            } else {
              currentColumnPointer += element.duration;
            }
          }
          break;
        }
      case Forward:
        {
          if (element is Forward) {
            currentColumnPointer += element.duration;
          }
          break;
        }
      case Backup:
        {
          if (element is Backup) {
            currentColumnPointer -= element.duration;
            // prevent some crash
            if (currentColumnPointer < 0) {
              print("negative pointer");
              currentColumnPointer = 0;
            }
          }
          break;
        }
      default:
        {
          throw new FormatException(
              '${element.runtimeType} is an unknown MeasureContent type');
        }
    }
  });
  return grid;
}

paintCurrentAttributes(DrawingContext drawC, MeasureContext mc) {
  var currentAttributes = mc.currentAttributes;
  if (currentAttributes != null && currentAttributes!.clefs != null) {
    final lineSpacing = drawC.lineSpacing;
    if (mc.currentAttributes == null) return;
    final clefs = mc.currentAttributes!.clefs!;
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      paintGlyph(drawC, clefToGlyphMap[clef.sign]!,
          yOffset: (drawC.staffHeight + drawC.staffsSpacing) *
                  (clef.staffNumber - 1) +
              (lineSpacing * clefToPositionOffsetMap[clef.sign]!),
          noAdvance: index < (clefs.length - 1));
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);

    final fifths = currentAttributes!.key?.fifths;
    if (fifths != null) {
      bool didDrawSomething = false;
      clefs
          .sorted((a, b) => a.staffNumber - b.staffNumber)
          .forEachIndexed((index, clef) {
        drawC.canvas.translate(0,
            (drawC.staffHeight + drawC.staffsSpacing) * (clef.staffNumber - 1));
        didDrawSomething |= paintAccidentalsForTone(drawC, clef.sign, fifths,
            noAdvance: index < (clefs.length - 1));
        drawC.canvas.translate(
            0,
            -(drawC.staffHeight + drawC.staffsSpacing) *
                (clef.staffNumber - 1));
      });
      if (didDrawSomething) drawC.canvas.translate(drawC.lineSpacing * 1, 0);
    }
  }
}

paintMeasureAttributes(Attributes attributes, int indexInMeasure,
    DrawingContext drawC, MeasureContext mc, MusicLineOptions options) {
  final fifths = attributes.key?.fifths;
  final staves = attributes.staves;
  final clefs = attributes.clefs;
  final lineSpacing = drawC.lineSpacing;

  // clef symbol
  if (fifths != null && staves != null && clefs != null) {
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      paintGlyph(drawC, clefToGlyphMap[clef.sign]!,
          yOffset: (drawC.staffHeight + drawC.staffsSpacing) *
                  (clef.staffNumber - 1) +
              (lineSpacing * clefToPositionOffsetMap[clef.sign]!),
          noAdvance: index < (clefs.length - 1));
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }

  // accidentals
  if (fifths != null && staves != null && clefs != null) {
    bool didDrawSomething = false;
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      drawC.canvas.translate(0,
          (drawC.staffHeight + drawC.staffsSpacing) * (clef.staffNumber - 1));
      didDrawSomething |= paintAccidentalsForTone(drawC, clef.sign, fifths,
          noAdvance: index < (clefs.length - 1));
      drawC.canvas.translate(0,
          -(drawC.staffHeight + drawC.staffsSpacing) * (clef.staffNumber - 1));
    });
    if (didDrawSomething) drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }

  // time signature
  if ((attributes.time != null && !options.noTimeSignature) &&
      staves != null &&
      clefs != null) {
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      drawC.canvas.translate(0,
          (drawC.staffHeight + drawC.staffsSpacing) * (clef.staffNumber - 1));
      paintTimeSignature(drawC, attributes,
          noAdvance: index < (clefs.length - 1));
      drawC.canvas.translate(0,
          -(drawC.staffHeight + drawC.staffsSpacing) * (clef.staffNumber - 1));
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }

  // this is just the clef symbol
  if (attributes.clefs != null && (!mc.isFirstBar || indexInMeasure != 0)) {
    final lineSpacing = drawC.lineSpacing;
    final clefs = attributes.clefs!;
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      paintGlyph(drawC, clefToGlyphMap[clef.sign]!,
          yOffset: (drawC.staffHeight + drawC.staffsSpacing) *
                  (clef.staffNumber - 1) +
              (lineSpacing * clefToPositionOffsetMap[clef.sign]!),
          noAdvance: index < (clefs.length - 1));
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }
}

calculateMeasureAttributesWidth(Attributes attributes, DrawingContext drawC,
    MeasureContext mc, MusicLineOptions options) {
  /*
  return (attributes.key != null
          ? calculateAccidentalsForToneWidth(drawC, attributes.key!.fifths)
          : 0) +
      (attributes.key != null && attributes.time != null
          ? drawC.lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2
          : 0) +
      (attributes.time != null
          ? calculateTimeSignatureWidth(drawC, attributes)
          : 0);
          */
  double length = 0;
  final fifths = attributes.key?.fifths;
  final staves = attributes.staves;
  final clefs = attributes.clefs;
  final lineSpacing = drawC.lineSpacing;
  if (fifths != null && staves != null && clefs != null) {
    // the first term is the clef
    length += (drawC.lineSpacing * 4) + drawC.lineSpacing;

    var accidentals = mainToneAccidentalsMapForFClef[fifths]!;
    // the first factor is the accidental and space between accidentals
    length += (drawC.lineSpacing + drawC.lineSpacing) * accidentals.length;
  }
  // time signature
  if ((attributes.time != null && !options.noTimeSignature) &&
      staves != null &&
      clefs != null) {
    // first term is the time signature
    length += (drawC.lineSpacing * 2) + drawC.lineSpacing;
  }

  return length;
}

paintDirection(Direction direction, DrawingContext drawC) {}
