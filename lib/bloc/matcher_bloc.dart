import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:music_notes/musicXML/data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
//import 'package:mxtpiano/screen/preference.dart';
part 'matcher_bloc.g.dart';
part 'matcher_event.dart';
part 'matcher_state.dart';

int maxAgeInDivision = 4;

// the input is the "divisions" number from musicxml,
// which is how many division unit are in a quarter note

void updatePracticeTolerance(int divisions) {
  // TODO
  /*
  var pt = PrefService.getString("practice_tolerance");
  switch (pt) {
    case "1/4 note":
      maxAgeInDivision = divisions;
      break;
    case "1/8 note":
      maxAgeInDivision = divisions ~/ 2;
      break;
    case "1/16 note":
      maxAgeInDivision = divisions ~/ 4;
      break;
    default:
      maxAgeInDivision = divisions;
  }
  print("update max age in divisions to ${maxAgeInDivision}");
  */
}

//
// This is actually all the properties of a note, not an id
// the problem with this is, for play note, it could be that
// the same pitch has been played twice, if we use
// the current id it cannot distinguish
//
class NoteId extends Equatable {
  final int measure;
  final int column;
  // for note coming from score, the index is the index among
  // the note in the same column, as written in score
  final int index;
  // for note coming from play, the above index is -1
  // and the midiKey is the key played
  final int midiKey;
  final bool fromPlay;
  final bool inaccurate;
  final double accuracy; // [-0.5, 0.5]
  NoteId(
      {required this.measure,
      required this.column,
      required this.index,
      required this.midiKey,
      required this.fromPlay,
      this.inaccurate = false,
      this.accuracy = 0});
  // NoteId.invalid() : this(measure: -1, column: -1, index: -1);
  @override
  List<Object?> get props => [measure, column, index, midiKey, fromPlay];
}

class MatchCandidate {
  final Pitch pitch;
  final int ageInDivision;
  // if its coming from score, the note id, this is used to later
  // mark the note as matched in ui
  final NoteId? noteId;
  MatchCandidate({required this.pitch, this.ageInDivision = 0, this.noteId});
  MatchCandidate copyWith({Pitch? pitch, int? ageInDivision, NoteId? noteId}) {
    return MatchCandidate(
        pitch: pitch ?? this.pitch,
        ageInDivision: ageInDivision ?? this.ageInDivision,
        noteId: noteId ?? this.noteId);
  }
}

class MatcherBloc extends Bloc<MatcherEvent, MatcherState> {
  Future<void> waitForScoreNoteMatched() async {
    if (state.scoreNotes.isEmpty || !state.playing) return;
    await for (var state in stream) {
      if (state.scoreNotes.isEmpty || !state.playing) return;
    }
  }

  MatcherBloc() : super(MatcherState()) {
    on<MatcherRemoveAllPlayNoteEvent>((event, emit) {
      emit(state.copyWith(
        playNotes: [],
      ));
    });
    on<MatcherAddPlayNoteEvent>((event, emit) {
      // TODO, even if its inaccurate, should still try to match it with
      // score note to see if its correct or wrong
      /*
      if (event.inaccurate) {
        emit(state.copyWith(
            currentPlayNote: event.noteId,
            inaccuratePlayNotes: state.inaccuratePlayNotes + 1));
        return;
      }*/
      List<MatchCandidate> newScoreNotes = [];
      Map<NoteId, NoteStatus> noteStatus = Map.from(state.noteStatus);
      bool matched = false;
      for (var c in state.scoreNotes) {
        if (matched) {
          newScoreNotes.add(c);
          continue;
        }
        if (c.pitch == event.pitch) {
          matched = true;
          noteStatus[event.noteId] = NoteStatus(
              match: MatchStatus.matched,
              accuracy: event.inaccurate
                  ? NoteAccuracy.inaccurate
                  : NoteAccuracy.accurate);
          noteStatus[c.noteId!] = NoteStatus(match: MatchStatus.matched);
        } else {
          newScoreNotes.add(c);
        }
      }
      List<MatchCandidate> newPlayNotes = List.from(state.playNotes);
      if (!matched) {
        newPlayNotes
            .add(MatchCandidate(pitch: event.pitch, noteId: event.noteId));
        noteStatus[event.noteId] = NoteStatus(
            match: MatchStatus.unmatched,
            accuracy: event.inaccurate
                ? NoteAccuracy.inaccurate
                : NoteAccuracy.accurate);
      }
      emit(state.copyWith(
          currentPlayNote: event.noteId,
          matched: matched ? state.matched + 1 : state.matched,
          scoreNotes: newScoreNotes,
          playNotes: newPlayNotes,
          noteStatus: noteStatus));
    });
    on<MatcherAddScoreNoteEvent>((event, emit) {
      List<MatchCandidate> newPlayNotes = [];
      Map<NoteId, NoteStatus> noteStatus = Map.from(state.noteStatus);

      bool matched = false;
      for (var c in state.playNotes) {
        if (matched) {
          newPlayNotes.add(c);
          continue;
        }
        if (c.pitch == event.pitch) {
          matched = true;
          noteStatus[event.noteId] = NoteStatus(match: MatchStatus.matched);
          noteStatus[c.noteId!] = NoteStatus(match: MatchStatus.matched);
        } else {
          newPlayNotes.add(c);
        }
      }
      List<MatchCandidate> newScoreNotes = List.from(state.scoreNotes);
      if (!matched) {
        newScoreNotes
            .add(MatchCandidate(pitch: event.pitch, noteId: event.noteId));
      }
      emit(state.copyWith(
          matched: matched ? state.matched + 1 : state.matched,
          scoreNotes: newScoreNotes,
          playNotes: newPlayNotes,
          noteStatus: noteStatus));
    });
    on<MatcherAddDivisionEvent>((event, emit) {
      List<MatchCandidate> newScoreNotes = [];
      Map<NoteId, NoteStatus> noteStatus = Map.from(state.noteStatus);

      int unmatchedScore = 0;
      for (var c in state.scoreNotes) {
        if (c.ageInDivision < maxAgeInDivision)
          newScoreNotes.add(c.copyWith(ageInDivision: c.ageInDivision + 1));
        else {
          unmatchedScore++;
          noteStatus[c.noteId!] = NoteStatus(match: MatchStatus.unmatched);
        }
      }
      List<MatchCandidate> newPlayNotes = [];
      int unmatchedPlay = 0;
      for (var c in state.playNotes) {
        // should we always keep all the play notes?
        if (c.ageInDivision < maxAgeInDivision)
          newPlayNotes.add(c.copyWith(ageInDivision: c.ageInDivision + 1));
        else {
          unmatchedPlay++;
          noteStatus[c.noteId!] = NoteStatus(match: MatchStatus.unmatched);
        }
      }
      emit(state.copyWith(
          scoreNotes: newScoreNotes,
          playNotes: newPlayNotes,
          unmatchedPlayNotes: state.unmatchedPlayNotes + unmatchedPlay,
          unmatchedScoreNotes: state.unmatchedScoreNotes + unmatchedScore,
          noteStatus: noteStatus));
    });
    on<MatcherSetPlayingEvent>((event, emit) {
      emit(state.copyWith(playing: event.playing));
    });
    on<MatcherResetEvent>((event, emit) {
      emit(MatcherState());
    });
  }
}
