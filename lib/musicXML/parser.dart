import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:music_notes/graphics/render-functions/staff.dart';
import 'package:xml/xml.dart';
import 'dart:io';
import 'data.dart';

XmlDocument loadMusicXMLFile(String filePath) {
  final File file = File(filePath);
  return XmlDocument.parse(file.readAsStringSync());
}

// some musicXML comes with two part each one has one stave
// in this case we merge them into one part
Score mergeTwoPartXml(Score s) {
  if (s.parts.length == 2) {
    if ((s.parts[0].measures.first.attributes!.staves ?? 1) == 1 &&
        (s.parts[1].measures.first.attributes!.staves ?? 1) == 1) {
      List<Measure> mergedMeasures = [];
      Attributes? prevAttributes;
      for (int i = 0; i < s.parts[0].measures.length; i++) {
        var m0 = s.parts[0].measures[i];
        var m1 = s.parts[1].measures[i];
        List<MeasureContent> mergedContents = [];
        if (i == 0) {
          if (m0.attributes != null && m1.attributes != null) {
            var a0 = m0.attributes!;
            var a1 = m1.attributes!;
            List<Clef> mergedClefs = [];
            mergedClefs.add(a0.clefs![0]);
            mergedClefs.add(Clef(2, a1.clefs![0].sign));
            Attributes mergedAttribute =
                a0.copyWithParams(staves: 2, clefs: mergedClefs);
            mergedContents.add(mergedAttribute);
            prevAttributes = mergedAttribute;
          } else {
            print("not both part has attributes in measure 1");
          }
        }

        for (int k = 0; k < m0.contents.length; k++) {
          var c = m0.contents[k];
          if (c is Attributes) {
            if (i == 0 && k == 0) continue;
            mergedContents.add(c.copyWithParams(staves: 2));
          } else {
            mergedContents.add(c);
          }
        }
        // TODO fix the hard code
        mergedContents.add(Backup(72));

        for (int k = 0; k < m1.contents.length; k++) {
          var c = m1.contents[k];
          if (c is Attributes) {
            if (i == 0 && k == 0) continue;
            if (c.clefs != null && c.clefs!.length > 0) {
              mergedContents.add(c.copyWithParams(
                  staves: 2, clefs: [Clef(2, c.clefs![0].sign)]));
            } else {
              mergedContents.add(c);
            }
          } else {
            if (c is Note) {
              mergedContents.add((c as Note).copyWith(staff: 2));
            } else {
              mergedContents.add(c);
            }
          }
        }

        mergedMeasures.add(Measure(mergedContents));
      }
      // use first part's id and info
      Part mergedPart = Part(s.parts[0].id, mergedMeasures);
      mergedPart.info = s.parts[0].info;
      Score newScore = Score([mergedPart]);
      return newScore;
    }
  }
  return s;
}

Score parseMusicXML(XmlDocument document) {
  final scoreParts = document.findAllElements('score-part');
  var scorePartsParsed = scoreParts.map(parseScorePartXML).toList();
  Map<String, ScorePart> scorePartMap = {};
  for (var sp in scorePartsParsed) {
    scorePartMap[sp.partId] = sp;
  }
  final parts = document.findAllElements('part');
  final partsParsed = parts.map(parsePartXML).toList();
  final List<Part> pianoParts = [];
  final List<Part> otherParts = [];
  for (var p in partsParsed) {
    p.info = scorePartMap[p.id];
    // print("instrument ${p.info!.instName.toLowerCase()}");
    if (p.info != null && p.info!.name.toLowerCase().contains("piano")) {
      pianoParts.add(p);
    } else {
      otherParts.add(p);
    }
  }
  final List<Part> sortedParts = [...pianoParts, ...otherParts];

  Score s = Score(sortedParts);
  return mergeTwoPartXml(s);
}

ScorePart parseScorePartXML(XmlElement scorePartXML) {
  var spId = scorePartXML.getAttribute("id");
  if (spId == null) {
    throw FormatException("score part doesnt have id");
  }
  String name = scorePartXML.getElement("part-name")?.text ?? "";
  String abbrev = scorePartXML.getElement("part-abbreviation")?.text ?? "";
  String instName = "";
  final inst = scorePartXML.getElement("score-instrument");
  if (inst != null) {
    instName = inst.getElement("instrument-name")?.text ?? "";
  }
  MidiInstrument midiInstrument = MidiInstrument();
  var midiInstrumentXML = scorePartXML.getElement("midi-instrument");
  if (midiInstrumentXML != null) {
    int channel = int.tryParse(
            midiInstrumentXML.getElement("midi-channel")?.text ?? "1") ??
        1;
    int program = int.tryParse(
            midiInstrumentXML.getElement("midi-program")?.text ?? "1") ??
        1;
    double volume = double.tryParse(
            midiInstrumentXML.getElement("volume")?.text ?? "100") ??
        100.0;
    midiInstrument =
        MidiInstrument(program: program, channel: channel, volume: volume);
  }
  return ScorePart(
      partId: spId,
      name: name,
      abbrev: abbrev,
      instName: instName,
      instrument: midiInstrument);
}

// Attributes? currentAttributes;
Part parsePartXML(XmlElement partXML) {
  final id = partXML.getAttribute("id");
  if (id == null) {
    throw FormatException("part doesnt have id");
  }
  final measures = partXML.findAllElements('measure');
  // currentAttributes = null;
  final parsedMeasures = measures.map(parseMeasureXML).toList();

  if (parsedMeasures.isNotEmpty &&
      (parsedMeasures.first.attributes == null ||
          !parsedMeasures.first.attributes!.isValidForFirstMeasure)) {
    throw new FormatException(
        'The first measure of a part must include Attributes');
  }
  return Part(id, parsedMeasures);
}

Measure parseMeasureXML(XmlElement measureXML) {
  final childElements = measureXML.children.whereType<XmlElement>();

  final List<MeasureContent> contents = [];

  MeasureContent? prev = null;
  for (var child in childElements) {
    MeasureContent? current;
    switch (child.name.qualified) {
      case 'attributes':
        Attributes? a = parseAttributesXML(child);
        // if (a != null) currentAttributes = a;
        current = a;
        break;
      case 'barline':
        current = parseBarlineXML(child);
        break;
      case 'direction':
        current = parseDirectionXML(child);
        break;
      case 'note':
        current = parseNoteXML(child);
        break;
      case 'backup':
        current = parseBackupXML(child);
        break;
      case 'forward':
        current = parseForwardXML(child);
        break;
      default:
        current = null;
    }
    // we delay adding attributes because we want to
    // merge consecutive attributes into one
    if (current is Attributes) {
      if (prev is Attributes) {
        prev = prev.copyWithObject(current);
      } else {
        prev = current;
      }
    } else {
      if (prev is Attributes) {
        contents.add(prev);
      }
      if (current != null) {
        contents.add(current);
      }
      prev = current;
    }
  }

  return Measure(contents);
}

Attributes? parseAttributesXML(XmlElement attributesXML) {
  final divisionsElmt = attributesXML.getElement('divisions');
  final int? divisions =
      divisionsElmt != null ? int.parse(divisionsElmt.innerText) : null;

  final keyElmt = attributesXML.getElement('key');
  MusicalKey? key;
  if (keyElmt != null) {
    final fifthElmt = keyElmt.getElement('fifths');
    final int? fifth =
        fifthElmt != null ? int.parse(fifthElmt.innerText) : null;

    final modeElmt = keyElmt.getElement('mode');
    final String? modeString = modeElmt?.innerText;
    final KeyMode? mode = modeString != null
        ? KeyMode.values
            .firstWhere((e) => e.toString() == 'KeyMode.$modeString')
        : null;

    if (fifth != null) {
      key = MusicalKey(fifth, mode);
    }
  }

  final stavesElmt = attributesXML.getElement('staves');
  // int staves = stavesElmt != null ? int.parse(stavesElmt.innerText) : 1;
  int? staves;
  if (stavesElmt != null) {
    staves = int.parse(stavesElmt.innerText);
  }

  final clefElmts = attributesXML.findAllElements('clef');
  List<Clef>? clefs;
  if (clefElmts.isNotEmpty) {
    clefs = clefElmts
        .map((clefElmt) {
          final signElmt = clefElmt.getElement('sign');
          final String? signString = signElmt?.innerText;
          final Clefs? sign = signString != null
              ? Clefs.values
                  .firstWhere((e) => e.toString() == 'Clefs.$signString')
              : null;

          final int number = int.parse(clefElmt.getAttribute('number') ?? '1');

          if (sign != null) {
            return Clef(number, sign);
          } else
            return null;
        })
        .whereType<Clef>()
        .toList();
  }
  // merge with current attributes
  // lets not merge it here, but use the MeasureContext
  /*

  List<Clef>? measureClefs = clefs;
  if (staves > 0 && ((clefs?.length ?? 0) < staves)) {
    List<Clef> mergedClefs = [];
    for (int i = 1; i <= staves; i++) {
      bool added = false;
      for (var c in clefs ?? <Clef>[]) {
        if (c.staffNumber == i) {
          mergedClefs.add(c);
          added = true;
          break;
        }
      }
      if (!added) {
        if (currentAttributes != null && currentAttributes!.clefs != null) {
          for (var c in currentAttributes!.clefs!) {
            if (c.staffNumber == i) {
              mergedClefs.add(c);
              added = true;
              break;
            }
          }
        }
      }
    }
    clefs = mergedClefs;
  }
  */

  /*
  if (staves != (clefs != null ? clefs.length : 0)) {
    throw new FormatException(
        'The number of staves has to meet the number of clefs');

    // tao: set staves equal to clefs for now
    // staves = (clefs != null ? clefs.length : 0);
  }
  */

  final timeElmt = attributesXML.getElement('time');
  Time? time;
  if (timeElmt != null) {
    final beatsElmt = timeElmt.getElement('beats');
    final int? beats =
        beatsElmt != null ? int.parse(beatsElmt.innerText) : null;

    final beatTypeElmt = timeElmt.getElement('beat-type');
    final int? beatType =
        beatTypeElmt != null ? int.parse(beatTypeElmt.innerText) : null;

    if (beats != null && beatType != null) {
      time = Time(beats, beatType);
    }
  }

  var a = Attributes(
      divisions: divisions,
      key: key,
      staves: staves,
      clefs: clefs,
      // measureClefs: measureClefs,
      time: time);

  /*
  if (currentAttributes != null) {
    return currentAttributes!.copyWithObject(a);
  }*/
  return a;
}

Barline parseBarlineXML(XmlElement barlineXML) {
  final String? barStyleString = barlineXML.getElement('bar-style')?.innerText;
  final BarLineTypes sign;
  switch (barStyleString) {
    case 'dashed':
      sign = BarLineTypes.dashed;
      break;
    case 'heavy':
      sign = BarLineTypes.heavy;
      break;
    case 'heavy-heavy':
      sign = BarLineTypes.heavyHeavy;
      break;
    case 'heavy-light':
      sign = BarLineTypes.heavyLight;
      break;
    case 'light-heavy':
      sign = BarLineTypes.lightHeavy;
      break;
    case 'light-light':
      sign = BarLineTypes.lightLight;
      break;
    default:
      sign = BarLineTypes.regular;
  }

  return Barline(sign);
}

Direction? parseDirectionXML(XmlElement directionXML) {
  final typeElmt = directionXML.getElement('direction-type');
  DirectionType? type;
  switch (typeElmt?.innerText) {
    case 'octave-shift':
      type = parseOctaveShiftXML(typeElmt!);
      break;
    case 'wedge':
      type = parseWedgeXML(typeElmt!);
      break;
    case 'words':
      type = parseWordsXML(typeElmt!);
      break;
    case null:
      {
        throw new AssertionError(
            'direction-type element missing in direction.');
      }
    default:
      {
        // return null;
        type = DirectionType();
      }
  }
  final String? placementString = directionXML.getAttribute('placement');
  final PlacementValue? placement = placementString != null
      ? PlacementValue.values
          .firstWhere((e) => e.toString() == 'PlacementValue.$placementString')
      : null;

  final staffElmt = directionXML.getElement('staff');
  final int? staff = staffElmt != null ? int.parse(staffElmt.innerText) : null;

  final soundElmt = directionXML.getElement('sound');
  final int tempo =
      soundElmt != null ? int.parse(soundElmt.getAttribute("tempo") ?? "0") : 0;

  if (type != null && staff != null) {
    return Direction(type, staff, placement: placement, tempo: tempo);
  } else {
    return null;
  }
}

OctaveShift? parseOctaveShiftXML(XmlElement octaveShiftXML) {
  final int number = int.parse(octaveShiftXML.getAttribute('number') ?? '1');

  final String? typeString = octaveShiftXML.getAttribute('type');
  final UpDownStopCont? type = typeString != null
      ? UpDownStopCont.values
          .firstWhere((e) => e.toString() == 'UpDownStopCont.$typeString')
      : null;

  final sizeAttr = octaveShiftXML.getAttribute('size');
  final int? size = sizeAttr != null ? int.parse(sizeAttr) : null;

  if (type != null) {
    return OctaveShift(number, type, size);
  } else {
    return null;
  }
}

Wedge? parseWedgeXML(XmlElement wedgeXML) {
  final int number = int.parse(wedgeXML.getAttribute('number') ?? '1');

  final String? typeString = wedgeXML.getAttribute('type');
  final WedgeType? type = typeString != null
      ? WedgeType.values
          .firstWhere((e) => e.toString() == 'WedgeType.$typeString')
      : null;

  if (type != null) {
    return Wedge(number, type);
  } else {
    return null;
  }
}

Words? parseWordsXML(XmlElement wordsXML) {
  final String content = wordsXML.innerText;

  final fontFamily = wordsXML.getAttribute('font-family');

  final fontSizeString = wordsXML.getAttribute('font-size');
  final double? fontSize =
      fontSizeString != null ? double.parse(fontSizeString) : null;

  final String? fontStyleString = wordsXML.getAttribute('font-styles');
  final FontStyle? fontStyle = fontStyleString != null
      ? FontStyle.values
          .firstWhere((e) => e.toString() == 'FontStyle.$fontStyleString')
      : null;

  final String? fontWeightString = wordsXML.getAttribute('font-weight');
  final FontWeight? fontWeight;
  switch (fontWeightString) {
    case 'normal':
      fontWeight = FontWeight.normal;
      break;
    case 'bold':
      fontWeight = FontWeight.bold;
      break;
    default:
      fontWeight = null;
  }

  if (content.length > 0) {
    return Words(content,
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontStyle: fontStyle,
        fontWeight: fontWeight);
  } else {
    return null;
  }
}

PlacementValue? parsePlacementAttr(XmlElement someXML) {
  final String? placementString = someXML.getAttribute('placement');
  return placementString != null
      ? PlacementValue.values
          .firstWhere((e) => e.toString() == 'PlacementValue.$placementString')
      : null;
}

Note? parseNoteXML(XmlElement noteXML) {
  final defaultX =
      double.tryParse(noteXML.getAttribute("default-x") ?? "0") ?? 0;

  final pitchElmt = noteXML.getElement('pitch');
  final pitch = pitchElmt != null ? parsePitchXML(pitchElmt) : null;

  final rest = noteXML.getElement('rest') != null;

  final durationElmt = noteXML.getElement('duration');
  final int? duration =
      durationElmt != null ? int.parse(durationElmt.innerText) : null;

  final voiceElmt = noteXML.getElement('voice');
  final int voice = voiceElmt != null ? int.parse(voiceElmt.innerText) : 1;

  final String? typeString = noteXML.getElement('type')?.innerText;
  final NoteLength? type;
  switch (typeString) {
    case 'whole':
      type = NoteLength.whole;
      break;
    case 'half':
      type = NoteLength.half;
      break;
    case 'quarter':
      type = NoteLength.quarter;
      break;
    case 'eighth':
      type = NoteLength.eighth;
      break;
    case '16th':
      type = NoteLength.sixteenth;
      break;
    case '32nd':
      type = NoteLength.thirtysecond;
      break;
    default:
      type = null;
  }

  final String? stemString = noteXML.getElement('stem')?.innerText;
  final StemValue? stem = stemString != null
      ? StemValue.values
          .firstWhere((e) => e.toString() == 'StemValue.$stemString')
      : null;

  final staffElmt = noteXML.getElement('staff');
  int? staff = staffElmt != null ? int.parse(staffElmt.innerText) : 1;

  final beamElmts = noteXML.findAllElements('beam');
  final beams = beamElmts.map(parseBeamXML).whereType<Beam>().toList();

  final notationElmts = noteXML.findAllElements('notations');
  final notations =
      notationElmts.map(parseNotationXML).expand((e) => e).toList();

  final dots = noteXML.findAllElements('dot').length;

  final chord = noteXML.getElement('chord') != null;

  if (rest && duration != null && staff != null) {
    return RestNote(duration, voice, staff, notations);
  } else if (pitch != null &&
      duration != null &&
      type != null &&
      stem != null &&
      staff != null) {
    return PitchNote(
        duration, voice, staff, notations, pitch, type, stem, beams,
        dots: dots, chord: chord, defaultX: defaultX);
  } else {
    return null;
  }
}

Pitch? parsePitchXML(XmlElement pitchXML) {
  final stepElmt = pitchXML.getElement('step');
  final String? stepString = stepElmt?.innerText;
  final BaseTones? step = stepString != null
      ? BaseTones.values
          .firstWhere((e) => e.toString() == 'BaseTones.$stepString')
      : null;

  final octaveElmt = pitchXML.getElement('octave');
  final int? octave =
      octaveElmt != null ? int.parse(octaveElmt.innerText) : null;

  final alterElmt = pitchXML.getElement('alter');
  final int? alter = alterElmt != null ? int.parse(alterElmt.innerText) : null;

  if (step != null && octave != null) {
    // tao: why - 2 here, undo this seems to break other things
    return Pitch(step, octave - 2, alter: alter ?? 0);
  } else {
    return null;
  }
}

int currentBeamId = 0;
int beamStructsOpen = 0;

Map<String, BeamValue> stringBeamValueMap = {
  "continue": BeamValue.continued,
  "backward hook": BeamValue.backward,
  "forward hook": BeamValue.forward,
  "begin": BeamValue.begin,
  "end": BeamValue.end,
};

BeamValue? stringToBeamValue(String s) {}
Beam? parseBeamXML(XmlElement beamXML) {
  final String? valueString = beamXML.innerText;
  final BeamValue? value =
      valueString != null ? stringBeamValueMap[valueString] : null;
  if (value == BeamValue.begin) {
    beamStructsOpen++;
  } else if (value == BeamValue.end) {
    beamStructsOpen--;
  }

  final int number = int.parse(beamXML.getAttribute('number') ?? '1');

  if (value != null) {
    return Beam(
        beamStructsOpen > 0 || value == BeamValue.forward
            ? currentBeamId
            : currentBeamId++,
        number,
        value);
  } else {
    return null;
  }
}

Iterable<Notation> parseNotationXML(XmlElement notationXML) {
  final List<Notation> result = [];

  final fingeringElmt = notationXML.findAllElements('fingering');
  final String? fingering =
      fingeringElmt.length >= 1 ? fingeringElmt.first.innerText : null;
  if (fingering != null) {
    result.add(Fingering(fingering, parsePlacementAttr(fingeringElmt.first)));
  }

  final tiedElements = notationXML.findAllElements('tied');
  if (!tiedElements.isEmpty) {
    for (var tiedElement in tiedElements) {
      final Tied? tied = parseTiedXML(tiedElement);
      if (tied != null) {
        result.add(tied);
      }
    }
  }

  final slurElement = notationXML.getElement('slur');
  final Slur? slur = slurElement != null ? parseSlurXML(slurElement) : null;
  if (slur != null) {
    result.add(slur);
  }

  final staccatoElmt = notationXML.findAllElements('staccato');
  final bool staccato = staccatoElmt.length >= 1;
  if (staccato) {
    result.add(Staccato(parsePlacementAttr(staccatoElmt.first)));
  }

  final accentElmt = notationXML.findAllElements('accent');
  final bool accent = accentElmt.length >= 1;
  if (accent) {
    result.add(Accent(parsePlacementAttr(accentElmt.first)));
  }

  final dynamicsElmt = notationXML.getElement('dynamics');
  final String? dynamicString = dynamicsElmt?.firstElementChild?.name.qualified;
  final DynamicType? dynamic = dynamicString != null
      ? DynamicType.values
          .firstWhere((e) => e.toString() == 'DynamicType.$dynamicString')
      : null;
  if (dynamicsElmt != null && dynamic != null) {
    result.add(Dynamics(dynamic, parsePlacementAttr(dynamicsElmt)));
  }

  return result;
}

Tied? parseTiedXML(XmlElement tiedXML) {
  final PlacementValue? placement = parsePlacementAttr(tiedXML);

  final String? typeString = tiedXML.getAttribute('type');
  final StCtStpValue? type = typeString != null
      ? StCtStpValue.values
          .firstWhere((e) => e.toString() == 'StCtStpValue.$typeString')
      : null;

  final int number = int.parse(tiedXML.getAttribute('number') ?? '1');

  if (type != null) {
    return Tied(number, type, placement);
  } else {
    return null;
  }
}

Slur? parseSlurXML(XmlElement slurXML) {
  final PlacementValue? placement = parsePlacementAttr(slurXML);

  final String? typeString = slurXML.getAttribute('type');
  final StCtStpValue? type = typeString != null
      ? StCtStpValue.values
          .firstWhere((e) => e.toString() == 'StCtStpValue.$typeString')
      : null;

  final int number = int.parse(slurXML.getAttribute('number') ?? '1');

  if (type != null) {
    return Slur(number, type, placement);
  } else {
    return null;
  }
}

Backup? parseBackupXML(XmlElement backupXML) {
  final durationElmt = backupXML.getElement('duration');
  final int? duration =
      durationElmt != null ? int.parse(durationElmt.innerText) : null;
  return duration != null ? Backup(duration) : null;
}

Forward? parseForwardXML(XmlElement forwardXML) {
  final durationElmt = forwardXML.getElement('duration');
  final int? duration =
      durationElmt != null ? int.parse(durationElmt.innerText) : null;
  return duration != null ? Forward(duration) : null;
}
