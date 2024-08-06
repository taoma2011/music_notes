part of 'matcher_bloc.dart';

enum MatchStatus { matched, unmatched }

enum NoteAccuracy { accurate, inaccurate }

class NoteStatus {
  MatchStatus match;
  NoteAccuracy accuracy;
  NoteStatus({required this.match, this.accuracy = NoteAccuracy.accurate});
}

@CopyWith(copyWithNull: true)
class MatcherState extends Equatable {
  final List<MatchCandidate> scoreNotes;
  final List<MatchCandidate> playNotes;
  final bool playing;
  final int matched; // number of play notes matched
  final int unmatchedScoreNotes;
  final int unmatchedPlayNotes;
  final int inaccuratePlayNotes;
  final Map<NoteId, NoteStatus> noteStatus;
  final NoteId? currentPlayNote;
  const MatcherState(
      {this.scoreNotes = const [],
      this.playNotes = const [],
      this.noteStatus = const {},
      this.playing = false,
      this.matched = 0,
      this.unmatchedPlayNotes = 0,
      this.unmatchedScoreNotes = 0,
      this.inaccuratePlayNotes = 0,
      this.currentPlayNote = null});

  @override
  List<Object> get props => [
        scoreNotes,
        playNotes,
        matched,
        unmatchedPlayNotes,
        unmatchedScoreNotes,
        inaccuratePlayNotes,
        noteStatus,
        playing,
      ];
}
