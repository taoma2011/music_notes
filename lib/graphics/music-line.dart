import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_notes/graphics/render-functions/measure.dart';
import 'package:music_notes/bloc/matcher_bloc.dart';
import 'generated/glyph-anchors.dart';
import 'render-functions/common.dart';
import 'render-functions/staff.dart';
import 'render-functions/glyph.dart';
import 'render-functions/note.dart';
import 'generated/glyph-definitions.dart';
import 'generated/engraving-defaults.dart';
import 'generated/glyph-advance-widths.dart';
import '../musicXML/data.dart';
import '../../ExtendedCanvas.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class XmlPitch extends Equatable {
  BaseTones b;
  int alt;
  XmlPitch(this.b, this.alt);
  @override
  List<Object?> get props => [b, alt];
}

List<XmlPitch> midiKeyToXmlPitch = [
  XmlPitch(BaseTones.C, 0),
  XmlPitch(BaseTones.C, 1),
  XmlPitch(BaseTones.D, 0),
  XmlPitch(BaseTones.D, 1),
  XmlPitch(BaseTones.E, 0),
  XmlPitch(BaseTones.F, 0),
  XmlPitch(BaseTones.F, 1),
  XmlPitch(BaseTones.G, 0),
  XmlPitch(BaseTones.G, 1),
  XmlPitch(BaseTones.A, 0),
  XmlPitch(BaseTones.A, 1),
  XmlPitch(BaseTones.B, 0),
];

List<XmlPitch> midiKeyFlatToXmlPitch = [
  XmlPitch(BaseTones.C, 0),
  XmlPitch(BaseTones.D, -1),
  XmlPitch(BaseTones.D, 0),
  XmlPitch(BaseTones.E, -1),
  XmlPitch(BaseTones.E, 0),
  XmlPitch(BaseTones.F, 0),
  XmlPitch(BaseTones.G, -1),
  XmlPitch(BaseTones.G, 0),
  XmlPitch(BaseTones.A, -1),
  XmlPitch(BaseTones.A, 0),
  XmlPitch(BaseTones.B, -1),
  XmlPitch(BaseTones.B, 0),
];
// this convert flat to sharp or regular notes
Map<BaseTones, XmlPitch> flatNormlizedPitch = {
  BaseTones.C: XmlPitch(BaseTones.B, 0),
  BaseTones.D: XmlPitch(BaseTones.C, 1),
  BaseTones.E: XmlPitch(BaseTones.D, 1),
  BaseTones.F: XmlPitch(BaseTones.E, 0),
  BaseTones.G: XmlPitch(BaseTones.F, 1),
  BaseTones.A: XmlPitch(BaseTones.G, 1),
  BaseTones.B: XmlPitch(BaseTones.A, 1),
};

PitchNote midiNoteToPitchNote(int midiNote, {bool useFlat = false}) {
  int i = midiNote % 12;
  var p = useFlat ? midiKeyFlatToXmlPitch[i] : midiKeyToXmlPitch[i];

  // NOTE: pitchNote octave is standard octave - 2
  // int octave = midiNote ~/ 12 - 1;

  int octave = midiNote ~/ 12 - 3;

  return PitchNote(
    1 /* duration */,
    1 /* voice */,
    1 /* staff */,
    [],
    Pitch(p.b, octave, alter: p.alt),
    NoteLength.whole,
    StemValue.none,
    [],
  );
}

Pitch normalizePitch(Pitch p) {
  if (p.alter == -1) {
    var xp = flatNormlizedPitch[p.step]!;
    return Pitch(xp.b, p.octave - ((p.step == BaseTones.C) ? 1 : 0),
        alter: xp.alt);
  }
  return p;
}

int PitchToMidiNote(Pitch p) {
  if (p.alter == -1) {
    var xp = flatNormlizedPitch[p.step]!;
    p = Pitch(xp.b, p.octave - ((p.step == BaseTones.C) ? 1 : 0),
        alter: xp.alt);
  }
  int midiIndex = -1;
  for (int i = 0; i < midiKeyToXmlPitch.length; i++) {
    if (midiKeyToXmlPitch[i] == XmlPitch(p.step, p.alter)) {
      midiIndex = i;
      break;
    }
  }
  // return (p.octave + 1) * 12 + midiIndex;
  return (p.octave + 3) * 12 + midiIndex;
}

int PitchNoteToMidiNote(PitchNote pn) {
  return PitchToMidiNote(pn.pitch);
}

class PlayNote extends Equatable {
  final int measure;
  final int column;
  final PitchNote note;
  PlayNote({required this.measure, required this.column, required this.note});
  @override
  List<Object> get props => [measure, column, note];
}

class CurrentPlay extends Equatable {
  final int currentMeasure;
  final int currentColumn;
  final int currentDivision;
  final List<PlayNote> play;
  final List<double> heatMap;
  CurrentPlay(
      {this.currentMeasure = 0,
      this.currentColumn = 0,
      this.currentDivision = 0,
      this.play = const [],
      this.heatMap = const []});
  CurrentPlay copyWith(
      {int? currentMeasure,
      int? currentColumn,
      int? currentDivision,
      List<PlayNote>? play,
      List<double>? heatMap}) {
    return CurrentPlay(
        currentMeasure: currentMeasure ?? this.currentMeasure,
        currentColumn: currentColumn ?? this.currentColumn,
        currentDivision: currentDivision ?? this.currentDivision,
        play: play ?? this.play,
        heatMap: heatMap ?? this.heatMap);
  }

  @override
  List<Object> get props =>
      [currentMeasure, currentColumn, currentDivision, play, heatMap];
}

class MusicLineOptions {
  MusicLineOptions(this.score, this.staffHeight, double topMarginFactor,
      {this.firstBar = 0,
      this.lastBar = -1,
      this.currentAttributes,
      this.heatMap,
      this.noBarNumber = false,
      this.noTimeSignature = false,
      this.noCurrentNoteLine = false})
      : this.topMargin = staffHeight * topMarginFactor;

  final Score score;
  final double staffHeight;
  final double topMargin;
  final int firstBar;
  final int lastBar;
  final Attributes? currentAttributes;
  final List<double>? heatMap;
  final bool noBarNumber;
  final bool noTimeSignature;
  final bool noCurrentNoteLine;

  @override
  bool operator ==(Object other) {
    return other is MusicLineOptions &&
        other.topMargin == topMargin &&
        other.staffHeight == staffHeight;
  }

  @override
  int get hashCode => staffHeight.hashCode ^ topMargin.hashCode;
}

class MusicLine extends StatefulWidget {
  const MusicLine({Key? key, required this.options}) : super(key: key);

  final MusicLineOptions options;

  @override
  _MusicLineState createState() => _MusicLineState();
}

class _MusicLineState extends State<MusicLine> {
  double staffsSpacing = 0;

  @override
  void initState() {
    super.initState();
    staffsSpacing = widget.options.staffHeight * 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final newWidth = constraints.widthConstraints().maxWidth;
      final newHeight = constraints.heightConstraints().maxHeight;
      return Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            child: CustomPaint(
              size: Size(newWidth, newHeight),
              painter: BackgroundPainter(widget.options, staffsSpacing),
            ),
          ),
          Positioned(
            child: BlocBuilder<MatcherBloc, MatcherState>(
                builder: (context, matcherState) =>
                    BlocBuilder<CurrentPlayCubit, CurrentPlay>(
                        builder: (context, currentPlay) {
                      // print("current measure is ${currentPlay.currentMeasure}");
                      return CustomPaint(
                        size: Size(newWidth, newHeight),
                        painter: ForegroundPainter(widget.options,
                            staffsSpacing, currentPlay, matcherState),
                      );
                    })),
          )
        ],
      );
    });
  }
}

class EmptyScoreException implements Exception {
  final dynamic message;

  EmptyScoreException([this.message]);

  String toString() {
    Object? message = this.message;
    if (message == null) return "EmptyScoreException";
    return "EmptyScoreException: $message";
  }
}

class BeamPoint {
  BeamPoint(this.beam, this.notePosition, this.noteAnchor, this.drawAbove,
      {this.adjustment});

  final bool drawAbove;
  final Beam beam;
  final Offset notePosition;
  final GlyphAnchor noteAnchor;

  final BeamChordHint? adjustment;
}

List<int> getOpenBeams(Map<int, List<BeamPoint>> beamPoints) {
  final List<int> beginList = [];
  final List<int> endOrHookList = [];

  for (final beamPointsForNumber in beamPoints.values) {
    for (final elmt in beamPointsForNumber) {
      switch (elmt.beam.value) {
        case BeamValue.backward:
        case BeamValue.forward:
        case BeamValue.end:
          endOrHookList.add(elmt.beam.number);
          break;
        case BeamValue.begin:
          beginList.add(elmt.beam.number);
          break;
        default:
          break;
      }
    }
  }

  return beginList
      .whereNot((element) => endOrHookList.contains(element))
      .toList(growable: false);
}

class DrawingContext extends MusicLineOptions {
  DrawingContext(
    Score score,
    double staffHeight,
    double topMargin,
    this.canvas,
    this.size,
    this.staffsSpacing,
  )   : _currentAttributes = score.parts.first.measures.first.attributes!,
        super(score, staffHeight, topMargin);

  final XCanvas canvas;
  final Size size;
  final double staffsSpacing;
  get lineSpacing => getLineSpacing(staffHeight);
  int _currentMeasure = 0;
  int currentLine = 0;
  int get currentMeasure => _currentMeasure;
  set currentMeasure(int newMeasure) {
    _currentMeasure = newMeasure;
    final newMeasureAttributes =
        score.parts.first.measures.elementAt(newMeasure).attributes;
    if (newMeasureAttributes != null) {
      _currentAttributes =
          _currentAttributes.copyWithObject(newMeasureAttributes);
    }
  }

  Attributes _currentAttributes;
  Attributes get latestAttributes => _currentAttributes;

  Map<int, Map<int, List<BeamPoint>>> currentBeamPointsPerID = {};

  DrawingContext copyWith(
      {Score? score,
      double? staffHeight,
      double? topMargin,
      XCanvas? canvas,
      Size? size,
      double? staffsSpacing}) {
    return DrawingContext(
      score ?? this.score,
      staffHeight ?? this.staffHeight,
      topMargin ?? this.topMargin,
      canvas ?? this.canvas,
      size ?? this.size,
      staffsSpacing ?? this.staffsSpacing,
    );
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.options, this.staffsSpacing)
      : this.lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    xCanvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height),
        doAntiAlias: false);

    xCanvas.translate(0, options.topMargin);

    final drawC = DrawingContext(options.score, options.staffHeight,
        options.topMargin, xCanvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      paintGlyph(
          drawC.copyWith(staffHeight: options.staffHeight * 2 + staffsSpacing),
          Glyph.brace,
          yOffset: (options.staffHeight * 2 + staffsSpacing) / 2);
      xCanvas.translate(lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarNumber(drawC, options, true);
    paintBarLine(drawC, Barline(BarLineTypes.regular), true);

    paintStaffLines(drawC, true);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      xCanvas.translate(0, options.staffHeight + staffsSpacing);
      paintStaffLines(drawC, false);
      xCanvas.translate(0, -options.staffHeight - staffsSpacing);
    }

    xCanvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return options != oldDelegate.options ||
        staffsSpacing != oldDelegate.staffsSpacing;
  }
}

class ForegroundPainter extends CustomPainter {
  ForegroundPainter(
      this.options, this.staffsSpacing, this.currentPlay, this.matcherState)
      : this.lineSpacing = getLineSpacing(options.staffHeight);

  final CurrentPlay currentPlay;
  final MatcherState matcherState;
  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.translate(0, options.topMargin);

    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

    final drawC = DrawingContext(options.score, options.staffHeight,
        options.topMargin, xCanvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      // The brace in front of the whole music line takes up horizontal space. That
      // space is determined by the width of the brace, which in turn is determined by
      // heights of the staffs and the space between the staff.
      final staffsSpacingLineSpacing = getLineSpacing(staffsSpacing);
      xCanvas.translate(
          GLYPH_ADVANCE_WIDTHS[Glyph.brace]! *
                  (lineSpacing * 2 + staffsSpacingLineSpacing) +
              lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2,
          0);
    }

    MeasureContext mc = MeasureContext();
    mc.currentAttributes = options.currentAttributes;

    options.score.parts.first.measures
        .toList()
        .forEachIndexed((index, measure) {
      drawC.currentMeasure = index;

      // initialize the measure context to the previous measure
      // note the .attributes return the first attribute in the measure
      // its possible there are multiple and we should use the last
      /*
      if (index > 0) {
        var lastAttributes =
            options.score.parts.first.measures.toList()[index - 1].attributes;
        if (lastAttributes != null) mc.currentAttributes = lastAttributes;
      }
      */

      if (index < options.firstBar) return;
      if (options.lastBar >= 0 && index >= options.lastBar) return;

      // if its a first measure in a new line, paint the clef
      if (options.firstBar > 0 && index == options.firstBar) {
        paintCurrentAttributes(drawC, mc);
      }

      if (index == 0 || (options.firstBar > 0 && index == options.firstBar)) {
        mc.isFirstBar = true;
      } else {
        mc.isFirstBar = false;
      }
      paintMeasure(measure, drawC, mc, options, currentPlay, matcherState);
    });
  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return options != oldDelegate.options ||
        staffsSpacing != oldDelegate.staffsSpacing ||
        currentPlay != oldDelegate.currentPlay ||
        matcherState != oldDelegate.matcherState;
  }
}

DrawingContext createDrawingContext(MusicLineOptions options) {
  double staffsSpacing = 100;
  Size size = Size(double.infinity, double.infinity);
  PictureRecorder pr = PictureRecorder();
  Canvas canvas = Canvas(pr);
  XCanvas xCanvas = XCanvas(canvas);

  final drawC = DrawingContext(options.score, options.staffHeight,
      options.topMargin, xCanvas, size, staffsSpacing);
  return drawC;
}

class LayoutResult {
  final List<List<int>> rowMeasureBounds;
  final List<Attributes> rowAttributes;
  LayoutResult(this.rowMeasureBounds, this.rowAttributes);
}

class ScoreLayout {
  ScoreLayout(this.options, this.staffsSpacing)
      : this.lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  // return how many measure can fit in each row
  LayoutResult layout(double maxWidth) {
    List<List<int>> rowMeasureBounds = [];
    List<Attributes> rowAttributes = [];
    /*
    Size size = Size(double.infinity, double.infinity);
    PictureRecorder pr = PictureRecorder();
    Canvas canvas = Canvas(pr);
    XCanvas xCanvas = XCanvas(canvas);

    final drawC = DrawingContext(options.score, options.staffHeight,
        options.topMargin, xCanvas, size, staffsSpacing);
    */
    final drawC = createDrawingContext(options);
    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      // The brace in front of the whole music line takes up horizontal space. That
      // space is determined by the width of the brace, which in turn is determined by
      // heights of the staffs and the space between the staff.
      final staffsSpacingLineSpacing = getLineSpacing(staffsSpacing);
      drawC.canvas.translate(
          GLYPH_ADVANCE_WIDTHS[Glyph.brace]! *
                  (lineSpacing * 2 + staffsSpacingLineSpacing) +
              lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2,
          0);
    }

    int currentMeasureStart = 0;
    int currentMeasureCount = 0;
    double currentMeasureLength = 0;

    MeasureContext mc = MeasureContext();
    mc.currentAttributes = options.score.parts.first.measures[0].attributes!;
    rowAttributes.add(mc.currentAttributes!.copyWithParams());

    options.score.parts.first.measures
        .toList()
        .forEachIndexed((index, measure) {
      drawC.currentMeasure = index;
      // if (index < options.firstBar) return;
      if (options.lastBar >= 0 && index >= options.lastBar) return;
      Rect rect = getMeasureLength(measure, mc, drawC, options);

      currentMeasureLength += rect.right;
      if (currentMeasureLength >
              maxWidth /*||
          index == options.score.parts.first.measures.length - 1*/
          ) {
        if (currentMeasureCount == 0) {
          // we need to put it in anyway
          mc.mergeMeasureAttributes(measure);
          rowMeasureBounds.add([currentMeasureStart, currentMeasureStart + 1]);
          rowAttributes.add(mc.currentAttributes!.copyWithParams());
          currentMeasureLength = 0;
          currentMeasureStart++;
        } else {
          // there is some content in this row, we flush it and start a new row
          rowMeasureBounds.add(
              [currentMeasureStart, currentMeasureStart + currentMeasureCount]);

          currentMeasureStart += currentMeasureCount;
          // see if the measure is biger than one row
          if (rect.right > maxWidth) {
            // yes, we need to start a row with this measure
            rowAttributes.add(mc.currentAttributes!.copyWithParams());
            rowMeasureBounds
                .add([currentMeasureStart, currentMeasureStart + 1]);
            // consume the attribute
            mc.mergeMeasureAttributes(measure);
            // record the start of a new row
            rowAttributes.add(mc.currentAttributes!.copyWithParams());
            currentMeasureStart++;
            currentMeasureCount = 0;
            currentMeasureLength = 0;
          } else {
            rowAttributes.add(mc.currentAttributes!.copyWithParams());
            mc.mergeMeasureAttributes(measure);

            currentMeasureCount = 1;
            currentMeasureLength = rect.right;
          }
        }
      } else {
        mc.mergeMeasureAttributes(measure);
        /*
        if (currentMeasureCount == 0) {
          rowAttributes.add(mc.currentAttributes!.copyWithParams());
        }*/
        currentMeasureCount++;
      }
    });
    if (currentMeasureCount > 0) {
      // add the last row
      rowMeasureBounds.add(
          [currentMeasureStart, currentMeasureStart + currentMeasureCount]);
      // rowAttributes.add(mc.currentAttributes!.copyWithParams());
    }
    return LayoutResult(rowMeasureBounds, rowAttributes);
  }
}
