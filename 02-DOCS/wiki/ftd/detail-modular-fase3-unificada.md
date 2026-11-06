# FTD — Detalle modular fase 3: layouts por skin en el detalle de item

## Intent
El detalle de item (`item_detail_screen.dart`, pelis/series/episodios) hoy es
composición Prime para todos los skins (salvo series Disney). Darle a cada
skin su distribución según las referencias del usuario, solo distribución y
contenido: los colores los sigue poniendo cada skin. Prime no se toca.

- Disney (pelis): cabecera con logo, badges, meta, sinopsis, progreso,
  botones (Continuar, reiniciar, tráiler, +) y tabs SUGERENCIAS / EXTRAS /
  DETALLES. Las series Disney siguen con `_DisneySeriesBody` (ya tabulado).
- Netflix (pelis y series): columna de póster con resume, centro con título,
  meta y tabs OVERVIEW / EPISODES (series) / TRAILERS & MORE / MORE LIKE THIS,
  nota ★ a la derecha y play destacado.
- Jellyfin (pelis y series): título, nota/fecha/badges de formato, géneros,
  sinopsis con póster a la derecha, metadatos a la izquierda, fila de botones
  (Play, tráiler, visto, favorito) y Cast & crew con fotos.

## Scope
- In:
  - `detail_layout.dart`: `DetailLayoutVariant` (prime/disney/netflix/
    jellyfin) + `detailVariantFor(skin)` para kinds de item; presets sin
    cambios y Prime como defecto (también para movistar_plus/custom,
    pendiente de decisión).
  - `item_detail_screen.dart`: cuerpos `_DisneyMovieBody`,
    `_NetflixDetailBody`, `_JellyfinDetailBody` privados reutilizando los
    bloques existentes (`_DetailActions` solo Prime; el resto comparte
    `_RelatedSection`, `_AdditionalInformation`, `_EpisodesTab`,
    `_ExtrasTab`, `_DetailTitle`, `_SeriesTabButton`, primitivas); switch por
    variante en el `build` sin tocar la rama Prime.
  - ARB es/en: `overview`, `trailersAndMore`, `castAndCrew`, `starring`,
    `directedBy`, `watched` (+ regen).
- Out: resto de tipos (libros ya pilotados, música, persona, juegos, Seerr,
  colecciones), `PrimeCardBadge`, paletas de colores, rutas.

## Checklist
- [x] FTD creado antes del cambio.
- [x] Variante en `detail_layout.dart` + resolver.
- [x] ARB es/en + regen.
- [x] Cuerpo Disney pelis con tabs.
- [x] Cuerpo Netflix pelis/series con tabs.
- [x] Cuerpo Jellyfin pelis/series secuencial.
- [x] `flutter analyze` limpio.

## Evidence
- `detail_layout.dart`: `DetailLayoutVariant` (prime/disney/netflix/jellyfin)
  + `detailVariantFor(skin, kind)`; solo kinds de item tienen variante propia,
  `movistar_plus`/`custom` y el resto de tipos devuelven Prime.
- ARB: `overview`, `trailersAndMore`, `castAndCrew`, `starring`,
  `createdBy`, `directedBy`, `favorite`, `watched`, `runs`, `ends` en es/en +
  regen verificado (`app_localizations_es.dart`).
- `item_detail_screen.dart`: el `build` deriva la variante y monta
  `_DisneyMovieBody` (logo, badges, meta, sinopsis, progreso+restante,
  Continuar/reiniciar/tráiler/+ y tabs Sugerencias/Extras/Detalles),
  `_NetflixDetailBody` (póster+resume, título, meta, play rojo con acento del
  skin, tabs Overview/Episodios/Tráilers/Más como este) y
  `_JellyfinDetailBody` (título, nota/fecha/badges de formato, géneros,
  sinopsis+póster, director/duración/fin, botones Play/tráiler/visto/
  favorito con `markPlayedItem`/`markUnplayedItem`, Cast & crew con fotos
  `/Persons` y ficha al tocar). Reutilizan `_RelatedSection`,
  `_AdditionalInformation`, `_EpisodesTab`, `_ExtrasTab` (solo series),
  `_DetailTitle`, `_SeriesTabButton` (subrayado con color opcional),
  `_VerButton`, `_WideDetailButton` y primitivas; `_verTarget`/`_episodesFor`
  de la serie Disney extraídos a funciones puras compartidas.
- Rama Prime y `_DisneySeriesBody` intactos; los items Seerr siguen por Prime
  (conservan el flujo Solicitar) y la descarga solo vive en Prime.
- `flutter analyze` → `No issues found!`.

## Next
- Verificación visual por skin con una peli y una serie (progreso, tabs,
  episodios, fotos de reparto); `movistar_plus` y `custom` quedan con Prime
  hasta decidir su fallback. Sin `flutter build`.
- Limitaciones conocidas: el botón reiniciar de Disney vuelve al reproductor
  igual que Continuar (el player no soporta posición inicial); la etiqueta
  "marca" Netflix usa el primer estudio; el fin Jellyfin se calcula con la
  hora actual + restante.
- Fase 3b (pendiente): `DetailPage` única por tipo para libros/música/
  persona sobre este mismo cableado.
