part of 'matcher_bloc.dart';

abstract class MatcherEvent extends Equatable {
  const MatcherEvent();

  @override
  List<Object> get props => [];
}

class MatcherRemoveAllPlayNoteEvent extends MatcherEvent {
  MatcherRemoveAllPlayNoteEvent();
}

class MatcherAddPlayNoteEvent extends MatcherEvent {
  final Pitch pitch;
  final NoteId noteId;
  MatcherAddPlayNoteEvent({required this.pitch, required this.noteId});
}

// add a note from score
class MatcherAddScoreNoteEvent extends MatcherEvent {
  final Pitch pitch;
  final int duration;
  final NoteId noteId;
  MatcherAddScoreNoteEvent(
      {required this.pitch, required this.duration, required this.noteId});
}

class MatcherAddDivisionEvent extends MatcherEvent {}

class MatcherResetEvent extends MatcherEvent {}

class MatcherSetPlayingEvent extends MatcherEvent {
  final bool playing;
  MatcherSetPlayingEvent(this.playing);
}
