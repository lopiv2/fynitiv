import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_chart_source.dart';

const _kMusicChartSourceKey = 'jellyfin.music_chart_source';

class MusicChartSourceController extends Notifier<MusicChartSource> {
  @override
  MusicChartSource build() {
    _load();
    return MusicChartSource.deezer; // default global
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMusicChartSourceKey);
    if (raw != null) {
      final found = MusicChartSource.values.asNameMap()[raw];
      if (found != null) state = found;
    }
  }

  Future<void> setSource(MusicChartSource source) async {
    state = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMusicChartSourceKey, source.name);
  }
}

final musicChartSourceControllerProvider =
    NotifierProvider<MusicChartSourceController, MusicChartSource>(
        MusicChartSourceController.new);
