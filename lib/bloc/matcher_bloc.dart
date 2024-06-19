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
  NoteId(
      {required this.measure,
      required this.column,
      required this.index,
      required this.midiKey,
      required this.fromPlay});
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
    on<MatcherAddPlayNoteEvent>((event, emit) {
      List<MatchCandidate> newScoreNotes = [];
      Map<NoteId, String> matchStatus = Map.from(state.matchStatus);
      bool matched = false;
      for (var c in state.scoreNotes) {
        if (matched) {
          newScoreNotes.add(c);
          continue;
        }
        if (c.pitch == event.pitch) {
          matched = true;
          matchStatus[event.noteId] = "matched";
          matchStatus[c.noteId!] = "matched";
        } else {
          newScoreNotes.add(c);
        }
      }
      List<MatchCandidate> newPlayNotes = List.from(state.playNotes);
      if (!matched) {
        newPlayNotes
            .add(MatchCandidate(pitch: event.pitch, noteId: event.noteId));
      }
      emit(state.copyWith(
          matched: matched ? state.matched + 1 : state.matched,
          scoreNotes: newScoreNotes,
          playNotes: newPlayNotes,
          matchStatus: matchStatus));
    });
    on<MatcherAddScoreNoteEvent>((event, emit) {
      List<MatchCandidate> newPlayNotes = [];
      Map<NoteId, String> matchStatus = Map.from(state.matchStatus);

      bool matched = false;
      for (var c in state.playNotes) {
        if (matched) {
          newPlayNotes.add(c);
          continue;
        }
        if (c.pitch == event.pitch) {
          matched = true;
          matchStatus[event.noteId] = "matched";
          matchStatus[c.noteId!] = "matched";
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
          matchStatus: matchStatus));
    });
    on<MatcherAddDivisionEvent>((event, emit) {
      List<MatchCandidate> newScoreNotes = [];
      Map<NoteId, String> matchStatus = Map.from(state.matchStatus);

      int unmatchedScore = 0;
      for (var c in state.scoreNotes) {
        if (c.ageInDivision < maxAgeInDivision)
          newScoreNotes.add(c.copyWith(ageInDivision: c.ageInDivision + 1));
        else {
          unmatchedScore++;
          matchStatus[c.noteId!] = "unmatched";
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
          matchStatus[c.noteId!] = "unmatched";
        }
      }
      emit(state.copyWith(
          scoreNotes: newScoreNotes,
          playNotes: newPlayNotes,
          unmatchedPlayNotes: state.unmatchedPlayNotes + unmatchedPlay,
          unmatchedScoreNotes: state.unmatchedScoreNotes + unmatchedScore,
          matchStatus: matchStatus));
    });
    on<MatcherSetPlayingEvent>((event, emit) {
      emit(state.copyWith(playing: event.playing));
    });
    on<MatcherResetEvent>((event, emit) {
      emit(MatcherState());
    });
  }
}
