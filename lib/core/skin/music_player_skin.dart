import 'package:material_ui/material_ui.dart';

import 'skin.dart';

/// Scroll configurable exclusivo del music player (análogo a HomeScroll).
class MusicScroll {
  const MusicScroll({
    required this.titleKey,
    this.genres = const [],
    this.includeItemTypes = const ['MusicAlbum', 'Audio'],
    this.limit = 20,
  });

  final String titleKey;
  final List<String> genres;
  final List<String> includeItemTypes;
  final int limit;

  Map<String, dynamic> toJson() => {
        'titleKey': titleKey,
        'genres': genres,
        'includeItemTypes': includeItemTypes,
        'limit': limit,
      };

  factory MusicScroll.fromJson(Map<String, dynamic> json) => MusicScroll(
        titleKey: json['titleKey'] as String,
        genres: (json['genres'] as List?)?.cast<String>() ?? const [],
        includeItemTypes:
            (json['includeItemTypes'] as List?)?.cast<String>() ??
                const ['MusicAlbum', 'Audio'],
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );

  @override
  bool operator ==(Object other) =>
      other is MusicScroll &&
      other.titleKey == titleKey &&
      other.limit == limit &&
      other.genres.join(',') == genres.join(',') &&
      other.includeItemTypes.join(',') == includeItemTypes.join(',');

  @override
  int get hashCode => Object.hash(titleKey, genres.join(','), includeItemTypes.join(','), limit);
}

/// Skin exclusivo del music player: colores y layout solo para música.
/// No toca sidebar ni nada global.
class MusicPlayerSkin {
  const MusicPlayerSkin({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.textPrimary,
    required this.textSecondary,
    this.cardRadius = 10,
    this.waveformEffect = AudioWaveformEffect.equalizer,
    this.headerStyle = MusicHeaderStyle.classic,
    this.listDensity = MusicListDensity.comfortable,
    this.showWaveform = true,
    this.musicScrolls = const [],
  });

  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color textPrimary;
  final Color textSecondary;
  final double cardRadius;
  final AudioWaveformEffect waveformEffect;
  final MusicHeaderStyle headerStyle;
  final MusicListDensity listDensity;
  final bool showWaveform;
  final List<MusicScroll> musicScrolls;

  MusicPlayerSkin copyWith({
    String? id,
    String? name,
    Color? primary,
    Color? accent,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? textPrimary,
    Color? textSecondary,
    double? cardRadius,
    AudioWaveformEffect? waveformEffect,
    MusicHeaderStyle? headerStyle,
    MusicListDensity? listDensity,
    bool? showWaveform,
    List<MusicScroll>? musicScrolls,
  }) {
    return MusicPlayerSkin(
      id: id ?? this.id,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardRadius: cardRadius ?? this.cardRadius,
      waveformEffect: waveformEffect ?? this.waveformEffect,
      headerStyle: headerStyle ?? this.headerStyle,
      listDensity: listDensity ?? this.listDensity,
      showWaveform: showWaveform ?? this.showWaveform,
      musicScrolls: musicScrolls ?? this.musicScrolls,
    );
  }

  factory MusicPlayerSkin.fromJson(Map<String, dynamic> json) {
    return MusicPlayerSkin(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      primary: _colorFromString(json['primary'] as String? ?? ''),
      accent: _colorFromString(json['accent'] as String? ?? ''),
      backgroundTop: _colorFromString(json['backgroundTop'] as String? ?? ''),
      backgroundBottom: _colorFromString(json['backgroundBottom'] as String? ?? ''),
      textPrimary: _colorFromString(json['textPrimary'] as String? ?? ''),
      textSecondary: _colorFromString(json['textSecondary'] as String? ?? ''),
      cardRadius: (json['cardRadius'] as num?)?.toDouble() ?? 10,
      waveformEffect: _waveformFromString(json['waveformEffect'] as String?),
      headerStyle: _headerFromString(json['headerStyle'] as String?),
      listDensity: _densityFromString(json['listDensity'] as String?),
      showWaveform: json['showWaveform'] as bool? ?? true,
      musicScrolls: (json['musicScrolls'] as List?)
              ?.map((e) => MusicScroll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary': _colorToString(primary),
        'accent': _colorToString(accent),
        'backgroundTop': _colorToString(backgroundTop),
        'backgroundBottom': _colorToString(backgroundBottom),
        'textPrimary': _colorToString(textPrimary),
        'textSecondary': _colorToString(textSecondary),
        'cardRadius': cardRadius,
        'waveformEffect': waveformEffect.name,
        'headerStyle': headerStyle.name,
        'listDensity': listDensity.name,
        'showWaveform': showWaveform,
        'musicScrolls': musicScrolls.map((s) => s.toJson()).toList(),
      };

  static Color _colorFromString(String s) {
    final hex = s.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF000000;
    return Color(value);
  }

  static AudioWaveformEffect _waveformFromString(String? s) =>
      AudioWaveformEffect.values.asNameMap()[s] ?? AudioWaveformEffect.equalizer;

  static MusicHeaderStyle _headerFromString(String? s) =>
      MusicHeaderStyle.values.asNameMap()[s] ?? MusicHeaderStyle.classic;

  static MusicListDensity _densityFromString(String? s) =>
      MusicListDensity.values.asNameMap()[s] ?? MusicListDensity.comfortable;

  static String _colorToString(Color c) {
    final argb = (c.toARGB32() & 0xFFFFFFFF);
    return '#${argb.toRadixString(16).padLeft(8, '0')}';
  }
}

enum MusicHeaderStyle { classic, compact, largeArt, minimal }

enum MusicListDensity { compact, comfortable, spacious }
