import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../l10n/app_localizations.dart';

/// Resuelve el badge Prime genérico basado en géneros y rating.
/// Solo backdrop + umbral ≥ 7. Siempre blanco (widget se encarga).
/// Retorna null si no aplica.
String? resolvePrimeBadge(BaseItemDto item, AppLocalizations l10n) {
  final genres = (item.genres ?? [])
      .map((g) => g.trim().toLowerCase())
      .where((g) => g.isNotEmpty)
      .toList();
  if (genres.isEmpty) {
    // Sin géneros no se muestra badge específico, pero si rating muy alto
    // se considera tendencia.
    final rating = _effectiveRating(item);
    if (rating >= 7) return l10n.cardBadgeTrending;
    return null;
  }

  final rating = _effectiveRating(item);
  // Umbral Prime: ≥ 7
  if (rating < 7) return null;

  // Prioridad: rating muy alto → TENDENCIAS (genérico prime)
  if (rating >= 8.5) return l10n.cardBadgeTrending;

  // Mapeo exacto por género (genérico prime)
  if (_hasAny(genres, ['action', 'acción', 'aventura', 'adventure'])) {
    return l10n.cardBadgeBestAction;
  }
  if (_hasAny(genres, ['drama'])) {
    return l10n.cardBadgeBestDrama;
  }
  if (_hasAny(genres, ['comedy', 'comedia'])) {
    return l10n.cardBadgeBestComedy;
  }
  if (_hasAny(genres, ['sci-fi', 'science fiction', 'ciencia ficción', 'sci fi', 'scifi'])) {
    return l10n.cardBadgeBestSciFi;
  }
  if (_hasAny(genres, ['horror', 'terror'])) {
    return l10n.cardBadgeBestHorror;
  }
  if (_hasAny(genres, ['animation', 'animación', 'family', 'familia', 'kids', 'infantil'])) {
    return l10n.cardBadgeFamily;
  }
  // Fallback géneros restantes con rating ≥7 → tendencias
  return l10n.cardBadgeTrending;
}

bool _hasAny(List<String> genres, List<String> targets) {
  for (final g in genres) {
    final ng = g.toLowerCase();
    for (final t in targets) {
      final nt = t.toLowerCase();
      if (ng == nt || ng.contains(nt) || nt.contains(ng)) return true;
    }
  }
  return false;
}

double _effectiveRating(BaseItemDto item) {
  final community = item.communityRating ?? 0;
  final critic = (item.criticRating ?? 0).toDouble();
  // criticRating viene 0-100, lo normalizamos a 0-10
  final critic10 = critic > 10 ? critic / 10 : critic;
  final effective = community > critic10 ? community : critic10;
  // Sin rating en Jellyfin (0) no podemos filtrar: tratamos como 7 para
  // que los badges por género sigan visibles en bibliotecas sin metadatos.
  // Tendencias seguirá requiriendo ≥8.5 real.
  if (effective == 0) return 7;
  return effective;
}
