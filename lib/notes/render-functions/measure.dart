import 'package:music_notes_2/notes/generated/engraving-defaults.dart';
import 'package:music_notes_2/notes/render-functions/glyph.dart';
import 'package:music_notes_2/notes/render-functions/note.dart';

import '../music-line.dart';
import '../notes.dart';
import '../render-functions/staff.dart';
import '../../musicXML/data.dart';
import 'package:collection/collection.dart';

paintMeasure(Measure measure, DrawingContext drawC) {
  bool paintedBarline = false;

  final grid = createGridForMeasure(measure, drawC);

  grid.forEachIndexed((columnIndex, column) {
    column.forEachIndexed((index, measureContent) {
      bool isLastElement = index == column.length-1;
      switch(measureContent.runtimeType) {
        case Barline: {
          paintBarLine(drawC, measureContent as Barline, false);
          drawC.canvas.translate(drawC.lineSpacing * 1, 0);
          paintedBarline = true;
          break;
        }
        case Attributes: {
          paintMeasureAttributes(measureContent as Attributes, drawC); break;
        }
        case Direction: {
          paintDirection(measureContent as Direction, drawC); break;
        }
        case PitchNote: {
          paintPitchNote(drawC, measureContent as PitchNote, noAdvance: !isLastElement); break;
        }
        case RestNote: {
          paintRestNote(drawC, measureContent as RestNote, noAdvance: !isLastElement); break;
        }
        default: {
          throw new FormatException('${measureContent.runtimeType} is an invalid MeasureContent type');
        }
      }
    });

    // TODO: Spacing between columns, currently static, probably needs to be dynamic
    // to justify measures for the whole line
    if(column.length > 0) {
      drawC.canvas.translate(drawC.lineSpacing * 1, 0);
    }
  });

  if(!paintedBarline) {
    paintBarLine(drawC, Barline(BarLineTypes.regular), false);
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }
}

List<List<MeasureContent>> createGridForMeasure(Measure measure, DrawingContext drawC) {

  final columnsOnFourFour = drawC.latestAttributes.divisions! * 4;
  final currentTimeFactor = drawC.latestAttributes.time!.beats / drawC.latestAttributes.time!.beatType;
  final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
  if(columnsOnCurrentTime % 1 != 0) {
    // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
    throw new FormatException('Found divisions of ${drawC.latestAttributes.divisions} on a Time of ${drawC.latestAttributes.time!.beats}/${drawC.latestAttributes.time!.beatType}, which does not work.');
  }
  final List<List<MeasureContent>> grid = List.generate(columnsOnCurrentTime.toInt()+1, (i) => []);
  int currentColumnPointer = 0;
  int? chordDuration;
  List<MeasureContent> currentColumn = grid[currentColumnPointer];
  measure.contents.forEachIndexed((index, element) {
    if(currentColumnPointer >= grid.length) {
      throw new FormatException('currentColumnPointer can only beyond end of grid length, if next element is Backup. But was: ${element.runtimeType.toString()}');
    } else {
      currentColumn = grid[currentColumnPointer];
    }
    switch(element.runtimeType) {
      case Barline: currentColumn.add(element); break;
      case Attributes: {
        currentColumn.insert(0, element); break;
      }
      case Direction: {
        currentColumn.add(element); break;
      }
      case RestNote:
      case PitchNote: {
        currentColumn.add(element);
        if(element is Note && index < measure.contents.length - 1) {
          final nextElement = measure.contents.elementAt(index + 1);
          if(element is PitchNote && nextElement is PitchNote) {
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
                if(chordDuration == null) {
                  throw new FormatException('End of a chord reached, should have chordDuration, but is null.');
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
      case Forward: {
        if(element is Forward) {
          currentColumnPointer += element.duration;
        }
        break;
      }
      case Backup: {
        if(element is Backup) {
          currentColumnPointer -= element.duration;
        }
        break;
      }
      default: {
        throw new FormatException('${element.runtimeType} is an unknown MeasureContent type');
      }
    }
  });
  return grid;
}

paintMeasureAttributes(Attributes attributes, DrawingContext drawC) {
  final fifths = attributes.key?.fifths;
  final staves = attributes.staves;
  final clefs = attributes.clefs;
  final lineSpacing = drawC.lineSpacing;

  if(fifths != null && staves != null && clefs != null) {
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      paintGlyph(
          drawC,
          clefToGlyphMap[clef.sign]!,
          yOffset: (drawC.staffHeight + drawC.staffsSpacing)*(clef.staffNumber-1)
              + (lineSpacing*clefToPositionOffsetMap[clef.sign]!),
          noAdvance: index < (clefs.length-1)
      );
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }

  if(fifths != null && staves != null && clefs != null) {
    bool didDrawSomething = false;
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing)*(clef.staffNumber-1));
      didDrawSomething |= paintAccidentalsForTone(drawC, clef.sign, fifths, noAdvance: index < (clefs.length-1));
      drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing)*(clef.staffNumber-1));
    });
    if(didDrawSomething) drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }

  if(attributes.time != null && staves != null && clefs != null) {
    clefs
        .sorted((a, b) => a.staffNumber - b.staffNumber)
        .forEachIndexed((index, clef) {
      drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing)*(clef.staffNumber-1));
      paintTimeSignature(drawC, attributes, noAdvance: index < (clefs.length-1));
      drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing)*(clef.staffNumber-1));
    });
    drawC.canvas.translate(drawC.lineSpacing * 1, 0);
  }
}

calculateMeasureAttributesWidth(Attributes attributes, DrawingContext drawC) {
  return (attributes.key != null ? calculateAccidentalsForToneWidth(drawC, attributes.key!.fifths) : 0)
      + (attributes.key != null && attributes.time != null ? drawC.lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2 : 0)
      + (attributes.time != null ? calculateTimeSignatureWidth(drawC, attributes) : 0);
}

paintDirection(Direction direction, DrawingContext drawC) {

}

paintForward(Forward forward, DrawingContext drawC) {

}

paintBackup(Backup backup, DrawingContext drawC) {

}