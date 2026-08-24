import 'package:material_ui/material_ui.dart';

import 'music_player_skin.dart';
import 'skin.dart';

abstract final class MusicPlayerSkinPresets {
  static const jellyfinClassic = MusicPlayerSkin(
    id: 'jellyfin_classic',
    name: 'Jellyfin Classic',
    primary: Color(0xFF00A4DC),
    accent: Color(0xFF3DDC84),
    backgroundTop: Color(0xFF0A0A0A),
    backgroundBottom: Color(0xFF1A1A1A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    cardRadius: 4,
    waveformEffect: AudioWaveformEffect.equalizer,
    headerStyle: MusicHeaderStyle.largeArt,
    listDensity: MusicListDensity.comfortable,
    musicScrolls: [],
  );

  static const spotify = MusicPlayerSkin(
    id: 'spotify',
    name: 'Spotify',
    primary: Color(0xFF1DB954),
    accent: Color(0xFF1DB954),
    backgroundTop: Color(0xFF121212),
    backgroundBottom: Color(0xFF181818),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB3B3B3),
    cardRadius: 6,
    waveformEffect: AudioWaveformEffect.bars,
    headerStyle: MusicHeaderStyle.compact,
    listDensity: MusicListDensity.compact,
    musicScrolls: [
      MusicScroll(titleKey: 'recentlyPlayed', limit: 20),
      MusicScroll(titleKey: 'madeForYou', genres: ['Pop', 'Hip Hop'], limit: 20),
      MusicScroll(titleKey: 'trending', genres: ['Electronic', 'Dance'], limit: 20),
    ],
  );

  static const appleMusic = MusicPlayerSkin(
    id: 'apple_music',
    name: 'Apple Music',
    primary: Color(0xFFFA1744),
    accent: Color(0xFFFA1744),
    backgroundTop: Color(0xFFF5F5F7),
    backgroundBottom: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF6E6E73),
    cardRadius: 12,
    waveformEffect: AudioWaveformEffect.wave,
    headerStyle: MusicHeaderStyle.classic,
    listDensity: MusicListDensity.spacious,
    musicScrolls: [
      MusicScroll(titleKey: 'topAlbums', limit: 20),
      MusicScroll(titleKey: 'newReleasesMusic', limit: 20),
      MusicScroll(titleKey: 'trending', genres: ['Pop'], limit: 20),
    ],
  );

  static const youtubeMusic = MusicPlayerSkin(
    id: 'youtube_music',
    name: 'YouTube Music',
    primary: Color(0xFFFF0000),
    accent: Color(0xFFFF0000),
    backgroundTop: Color(0xFF030303),
    backgroundBottom: Color(0xFF212121),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFAAAAAA),
    cardRadius: 8,
    waveformEffect: AudioWaveformEffect.mirror,
    headerStyle: MusicHeaderStyle.minimal,
    listDensity: MusicListDensity.comfortable,
    musicScrolls: [
      MusicScroll(titleKey: 'hotlist', genres: ['Hip Hop', 'Pop'], limit: 20),
      MusicScroll(titleKey: 'newReleasesMusic', limit: 20),
      MusicScroll(titleKey: 'trending', limit: 20),
    ],
  );

  static const tidal = MusicPlayerSkin(
    id: 'tidal',
    name: 'Tidal',
    primary: Color(0xFFFFFFFF),
    accent: Color(0xFFFFFFFF),
    backgroundTop: Color(0xFF000000),
    backgroundBottom: Color(0xFF0A0A0A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF999999),
    cardRadius: 2,
    waveformEffect: AudioWaveformEffect.surfer,
    headerStyle: MusicHeaderStyle.minimal,
    listDensity: MusicListDensity.spacious,
    musicScrolls: [
      MusicScroll(titleKey: 'hiFiPicks', genres: ['Jazz', 'Classical'], limit: 20),
      MusicScroll(titleKey: 'trending', limit: 20),
    ],
  );

  static const List<MusicPlayerSkin> all = [
    jellyfinClassic,
    spotify,
    appleMusic,
    youtubeMusic,
    tidal,
  ];
}
