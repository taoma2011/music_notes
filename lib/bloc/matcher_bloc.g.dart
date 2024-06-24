// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matcher_bloc.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MatcherStateCWProxy {
  MatcherState matchStatus(Map<NoteId, String> matchStatus);

  MatcherState matched(int matched);

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
    Map<NoteId, String>? matchStatus,
    int? matched,
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
  MatcherState matchStatus(Map<NoteId, String> matchStatus) =>
      this(matchStatus: matchStatus);

  @override
  MatcherState matched(int matched) => this(matched: matched);

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
    Object? matchStatus = const $CopyWithPlaceholder(),
    Object? matched = const $CopyWithPlaceholder(),
    Object? playNotes = const $CopyWithPlaceholder(),
    Object? playing = const $CopyWithPlaceholder(),
    Object? scoreNotes = const $CopyWithPlaceholder(),
    Object? unmatchedPlayNotes = const $CopyWithPlaceholder(),
    Object? unmatchedScoreNotes = const $CopyWithPlaceholder(),
  }) {
    return MatcherState(
      matchStatus:
          matchStatus == const $CopyWithPlaceholder() || matchStatus == null
              ? _value.matchStatus
              // ignore: cast_nullable_to_non_nullable
              : matchStatus as Map<NoteId, String>,
      matched: matched == const $CopyWithPlaceholder() || matched == null
          ? _value.matched
          // ignore: cast_nullable_to_non_nullable
          : matched as int,
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
}
