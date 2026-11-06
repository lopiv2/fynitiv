# Intent
Que las fichas de detalle abiertas desde Estudios/Seerr (y cualquier ficha virtual de Seerr) usen el layout del skin activo (Disney/Netflix/Jellyfin) en vez de caer siempre al layout Prime.

# Scope
- `lib/features/library/presentation/item_detail_screen.dart`: añadir `seerrMedia` a `_DisneyMovieBody`, `_NetflixDetailBody`, `_JellyfinDetailBody`; mostrar `_DetailActions` (flujo Solicitar) cuando haya `seerrMedia`; quitar los gates `widget.seerrMedia == null` (líneas ~521/541/559).
- No tocar `PrimeCardBadge` ni posiciones manuales. Textos nuevos (si los hay) vía ARB; debug sin traducir.
- Verificación: `dart analyze` del fichero (sin `flutter build`, sin tests salvo petición).

# Checklist
- [x] Causa: los gates `variant == disney/netflix/jellyfin && widget.seerrMedia == null` dejan fuera a las fichas Seerr (pelis), que caen al fallback Prime. Series Seerr sí usan `_DisneySeriesBody` porque esa rama no tiene gate.
- [x] Añadir `seerrMedia` a los tres cuerpos y renderizar `_DetailActions` como hace `_DisneySeriesBody` (líneas 1995-2011).
- [x] Quitar los tres gates.
- [x] `dart analyze lib/features/library/presentation/item_detail_screen.dart` sin errores.

# Evidence
- Antes: con skin Disney, abrir una peli desde Estudios → cuerpo Prime (título + tabs Relacionado/Detalles). `dart analyze` pendiente tras el cambio.
- Después: `dart analyze lib/features/library/presentation/item_detail_screen.dart` → `No issues found!`. Las pelis/series Seerr usan `_DisneyMovieBody`/`_NetflixDetailBody`/`_JellyfinDetailBody` con `_DetailActions` (Solicitar / chip estado / En tu biblioteca) en vez del botón Ver.
- Patrón a reutilizar: `_DisneySeriesBody` + `_DetailActions._buildSeerrActions` (Solicitar / chip estado / En tu biblioteca).

# Next
- Siguiente paso: aplicar el cambio y pasar `dart analyze`. Después, valorar si compensa extender variantes Disney/Netflix a otros tipos (juegos, personas, libros), hoy Prime por diseño en `detailVariantFor`.
