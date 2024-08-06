// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matcher_bloc.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MatcherStateCWProxy {
  MatcherState currentPlayNote(NoteId? currentPlayNote);

  MatcherState inaccuratePlayNotes(int inaccuratePlayNotes);

  MatcherState matched(int matched);

  MatcherState noteStatus(Map<NoteId, NoteStatus> noteStatus);

  MatcherState playNotes(List<MatchCandidate> playNotes);

  MatcherState playing(bool playing);

  MatcherState scoreNotes(List<MatchCandidate> scoreNotes);

  MatcherState unmatchedPlayNotes(int unmatchedPlayNotes);

  MatcherState unmatchedScoreNotes(int unmatchedScoreNotes);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MatcherState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MatcherState(...).copyWith(id: 12, name: "My name")
  /// ````
  MatcherState call({
    NoteId? currentPlayNote,
    int? inaccuratePlayNotes,
    int? matched,
    Map<NoteId, NoteStatus>? noteStatus,
    List<MatchCandidate>? playNotes,
    bool? playing,
    List<MatchCandidate>? scoreNotes,
    int? unmatchedPlayNotes,
    int? unmatchedScoreNotes,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMatcherState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMatcherState.copyWith.fieldName(...)`
class _$MatcherStateCWProxyImpl implements _$MatcherStateCWProxy {
  final MatcherState _value;

  const _$MatcherStateCWProxyImpl(this._value);

  @override
  MatcherState currentPlayNote(NoteId? currentPlayNote) =>
      this(currentPlayNote: currentPlayNote);

  @override
  MatcherState inaccuratePlayNotes(int inaccuratePlayNotes) =>
      this(inaccuratePlayNotes: inaccuratePlayNotes);

  @override
  MatcherState matched(int matched) => this(matched: matched);

  @override
  MatcherState noteStatus(Map<NoteId, NoteStatus> noteStatus) =>
      this(noteStatus: noteStatus);

  @override
  MatcherState playNotes(List<MatchCandidate> playNotes) =>
      this(playNotes: playNotes);

  @override
  MatcherState playing(bool playing) => this(playing: playing);

  @override
  MatcherState scoreNotes(List<MatchCandidate> scoreNotes) =>
      this(scoreNotes: scoreNotes);

  @override
  MatcherState unmatchedPlayNotes(int unmatchedPlayNotes) =>
      this(unmatchedPlayNotes: unmatchedPlayNotes);

  @override
  MatcherState unmatchedScoreNotes(int unmatchedScoreNotes) =>
      this(unmatchedScoreNotes: unmatchedScoreNotes);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MatcherState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MatcherState(...).copyWith(id: 12, name: "My name")
  /// ````
  MatcherState call({
    Object? currentPlayNote = const $CopyWithPlaceholder(),
    Object? inaccuratePlayNotes = const $CopyWithPlaceholder(),
    Object? matched = const $CopyWithPlaceholder(),
    Object? noteStatus = const $CopyWithPlaceholder(),
    Object? playNotes = const $CopyWithPlaceholder(),
    Object? playing = const $CopyWithPlaceholder(),
    Object? scoreNotes = const $CopyWithPlaceholder(),
    Object? unmatchedPlayNotes = const $CopyWithPlaceholder(),
    Object? unmatchedScoreNotes = const $CopyWithPlaceholder(),
  }) {
    return MatcherState(
      currentPlayNote: currentPlayNote == const $CopyWithPlaceholder()
          ? _value.currentPlayNote
          // ignore: cast_nullable_to_non_nullable
          : currentPlayNote as NoteId?,
      inaccuratePlayNotes:
          inaccuratePlayNotes == const $CopyWithPlaceholder() ||
                  inaccuratePlayNotes == null
              ? _value.inaccuratePlayNotes
              // ignore: cast_nullable_to_non_nullable
              : inaccuratePlayNotes as int,
      matched: matched == const $CopyWithPlaceholder() || matched == null
          ? _value.matched
          // ignore: cast_nullable_to_non_nullable
          : matched as int,
      noteStatus:
          noteStatus == const $CopyWithPlaceholder() || noteStatus == null
              ? _value.noteStatus
              // ignore: cast_nullable_to_non_nullable
              : noteStatus as Map<NoteId, NoteStatus>,
      playNotes: playNotes == const $CopyWithPlaceholder() || playNotes == null
          ? _value.playNotes
          // ignore: cast_nullable_to_non_nullable
          : playNotes as List<MatchCandidate>,
      playing: playing == const $CopyWithPlaceholder() || playing == null
          ? _value.playing
          // ignore: cast_nullable_to_non_nullable
          : playing as bool,
      scoreNotes:
          scoreNotes == const $CopyWithPlaceholder() || scoreNotes == null
              ? _value.scoreNotes
              // ignore: cast_nullable_to_non_nullable
              : scoreNotes as List<MatchCandidate>,
      unmatchedPlayNotes: unmatchedPlayNotes == const $CopyWithPlaceholder() ||
              unmatchedPlayNotes == null
          ? _value.unmatchedPlayNotes
          // ignore: cast_nullable_to_non_nullable
          : unmatchedPlayNotes as int,
      unmatchedScoreNotes:
          unmatchedScoreNotes == const $CopyWithPlaceholder() ||
                  unmatchedScoreNotes == null
              ? _value.unmatchedScoreNotes
              // ignore: cast_nullable_to_non_nullable
              : unmatchedScoreNotes as int,
    );
  }
}

extension $MatcherStateCopyWith on MatcherState {
  /// Returns a callable class that can be used as follows: `instanceOfMatcherState.copyWith(...)` or like so:`instanceOfMatcherState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MatcherStateCWProxy get copyWith => _$MatcherStateCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `MatcherState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MatcherState(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  MatcherState copyWithNull({
    bool currentPlayNote = false,
  }) {
    return MatcherState(
      currentPlayNote: currentPlayNote == true ? null : this.currentPlayNote,
      inaccuratePlayNotes: inaccuratePlayNotes,
      matched: matched,
      noteStatus: noteStatus,
      playNotes: playNotes,
      playing: playing,
      scoreNotes: scoreNotes,
      unmatchedPlayNotes: unmatchedPlayNotes,
      unmatchedScoreNotes: unmatchedScoreNotes,
    );
  }
}
