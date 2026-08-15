import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

/// Fila de contenido configurable por skin: un título y filtros que deciden
/// qué elementos se muestran (géneros y tipos). Permite customizar los scrolls
/// de cada skin sin tocar código de pantalla.
class HomeScroll {
  const HomeScroll({
    required this.titleKey,
    required this.genres,
    this.types = const [BaseItemKind.movie, BaseItemKind.series],
    this.limit = 20,
  });

  /// Clave de localización del título de la fila (AppLocalizations).
  final String titleKey;

  /// Géneros (nombres en inglés de Jellyfin: 'Action', 'Animation', ...).
  /// Se muestran los elementos que tengan cualquiera de estos géneros.
  final List<String> genres;

  /// Tipos de elemento a incluir.
  final List<BaseItemKind> types;

  /// Máximo de elementos de la fila.
  final int limit;

  Map<String, dynamic> toJson() => {
        'titleKey': titleKey,
        'genres': genres,
        'types': types.map((t) => t.name).toList(),
        'limit': limit,
      };

  factory HomeScroll.fromJson(Map<String, dynamic> json) => HomeScroll(
        titleKey: json['titleKey'] as String,
        genres: (json['genres'] as List?)?.cast<String>() ?? const [],
        types: ((json['types'] as List?) ?? const [])
            .map((e) => BaseItemKind.values.asNameMap()[e] ??
                BaseItemKind.movie)
            .toList(),
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );

  @override
  bool operator ==(Object other) =>
      other is HomeScroll &&
      other.titleKey == titleKey &&
      listEquals(other.genres, genres) &&
      listEquals(other.types, types) &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(titleKey, genres, types, limit);
}
