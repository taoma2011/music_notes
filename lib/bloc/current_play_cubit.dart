import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_notes/musicXML/data.dart';
import 'package:music_notes/graphics/music-line.dart';

class CurrentPlayCubit extends Cubit<CurrentPlay> {
  CurrentPlayCubit() : super(CurrentPlay());
  void setCurrentPlay(CurrentPlay cp) {
    emit(cp);
  }

  void setCurrentMeasureAndColumn(int measure, int column, int division) {
    emit(state.copyWith(
        currentMeasure: measure,
        currentColumn: column,
        currentDivision: division));
  }

  void addNote(int midiKey) {
    List<PlayNote> newPlay = List.from(state.play);
    newPlay.add(PlayNote(
        measure: state.currentMeasure,
        column: state.currentColumn,
        note: midiNoteToPitchNote(midiKey)));
    emit(state.copyWith(play: newPlay));
  }

  void setHeatMap(List<double> heatMap) {
    emit(state.copyWith(heatMap: heatMap));
  }

  void reset() {
    emit(CurrentPlay());
  }
}
