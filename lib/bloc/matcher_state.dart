part of 'matcher_bloc.dart';

@CopyWith(copyWithNull: true)
class MatcherState extends Equatable {
  final List<MatchCandidate> scoreNotes;
  final List<MatchCandidate> playNotes;
  final bool playing;
  final int matched;
  final int unmatchedScoreNotes;
  final int unmatchedPlayNotes;
  final Map<NoteId, String> matchStatus;
  const MatcherState(
      {this.scoreNotes = const [],
      this.playNotes = const [],
      this.matchStatus = const {},
      this.playing = false,
      this.matched = 0,
      this.unmatchedPlayNotes = 0,
      this.unmatchedScoreNotes = 0});

  @override
  List<Object> get props => [
        scoreNotes,
        playNotes,
        matched,
        unmatchedPlayNotes,
        unmatchedScoreNotes,
        matchStatus,
        playing
      ];
}
