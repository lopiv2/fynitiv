# Intent
La pestaña "Peticiones" de Seerr pasó de `ListTile` plano a un grid de `PosterCard`, pero (1) las carátulas no salen bien —la lista `/request` de Seerr no siempre trae `posterPath` fiable, así que se veía el relleno con la inicial— y (2) el grid no se parece a las filas de scroll del resto de la app. Se quiere que las peticiones se rendericen como los elementos de dentro de los scrolls, reutilizando `ContentRow` (el mismo widget que usan Descubrir, Home, biblioteca…).

# Scope
- `lib/features/library/presentation/widgets/content_row.dart`: nuevo parámetro opcional `cornerBadgeFor` (badge por item, igual que ya existen `cardLogoFor`/`cornerLogosFor`), reenviado a `PosterCard`/`BackdropCard`.
- **Nuevo** `lib/features/seerr/presentation/widgets/seerr_content_row.dart`: fila de Seerr sobre `ContentRow` con los tamaños del skin (`homeCardWidth`/`homeRowHeight`/`homeCardScale`/`itemSpacing`), imagen externa por item y sin badge "Se incluye con Jellyfin".
- `lib/features/seerr/presentation/widgets/seerr_media_row.dart`: delegación en `SeerrContentRow` (mismo look, sin duplicar la construcción de la fila).
- `lib/features/seerr/application/seerr_providers.dart`: `seerrRequestToMedia` (respaldo) y `seerrRequestToBaseItem(r, {media})` re-clavado por petición.
- `lib/features/seerr/domain/seerr_models.dart`: se retira `SeerrRequest.posterUrl()` (queda sin uso; la URL se resuelve con `SeerrMedia`).
- `lib/features/seerr/presentation/seerr_screen.dart`: `_RequestsTab` pasa a `ListView` con una fila `SeerrContentRow` de peticiones; cada carátula se resuelve con la ficha de TMDB (`seerrDetailProvider`), con la petición como respaldo mientras carga. Badge de estado por tarjeta: si el título ya está en la biblioteca Jellyfin, verde con tick y "Disponible" (`seerrStatusAvailable`), por encima del estado de la petición.
- Se mantiene `SeerrPosterGrid` para la pestaña Buscar (no se toca su comportamiento). Sin ARB nuevas. Sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD actualizado antes del primer cambio
- [x] `ContentRow.cornerBadgeFor` (badge por item)
- [x] `SeerrContentRow` reutilizable (Descubrir y Peticiones)
- [x] `_RequestsTab` como fila de scroll con carátula TMDB + nombre + estado
- [x] Badge verde con tick cuando el título ya está en la biblioteca
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (17/10/2026, proyecto completo): `No issues found!` (retirados también imports ya no usados en `seerr_media_row.dart`).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Render visual pendiente de comprobación del usuario (skin propio): Peticiones como scroll con carátula TMDB, nombre y badge de estado.
- Coste: se consulta la ficha de TMDB por petición (igual que Descubrir) para garantizar carátula; si molesta, se puede limitar a la carátula propia de la petición.
