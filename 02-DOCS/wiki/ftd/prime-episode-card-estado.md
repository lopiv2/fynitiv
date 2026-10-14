# Tarjeta de capítulo Prime: visto/a medias, tiempo restante y meta

## Intent
En el detalle de serie de Prime, cada capítulo debe mostrar su estado (visto o a
medias), un indicador de "tiempo restante" si está a medias, y una línea de meta
(edad, CC, duración y fecha), como la referencia. Al reproducir: un capítulo
visto empieza desde el principio; uno a medias reanuda.

## Scope
- In:
  - `item_detail_screen.dart`: `_EpisodeCard` (y `_EpisodeHoverThumb`) con
    variante Prime (`prime`): barra de progreso blanca (completa si visto,
    parcial si a medias), pastilla "Tiempo restante: X min" y `_EpisodePrimeMeta`
    (edad + CC + duración + fecha). Se pasa `prime` desde `_DisneySeriesBody`
    (según skin) a `_EpisodesTab`/`_ExtrasTab`/`_EpisodeWrap`.
  - `library_providers.dart`: `seriesEpisodesProvider` pide `ItemFields.mediaStreams`
    (para el icono CC).
  - `playback_provider.dart`: si el item está `played`, no se reanuda (empieza en
    0); si no, reanuda desde `playbackPositionTicks`.
- Out: la tarjeta básica del resto de skins (no Prime) no cambia de aspecto.

## Checklist
- [x] Capítulo visto → barra completa; a medias → barra parcial + tiempo restante.
- [x] Meta de Prime: edad, CC, duración, fecha.
- [x] Reproducir: visto desde el inicio; a medias reanuda.
- [x] Solo Prime (el resto mantiene la tarjeta básica).
- [x] `flutter analyze` limpio.

## Evidence
- `_EpisodeCard(prime: …)` + `_EpisodeHoverThumb(prime/watched/remainingText)` +
  `_EpisodePrimeMeta` (usa `DateFormat.yMMMd(l10n.localeName)`,
  `officialRating`, `mediaStreams`, `runTimeTicks`).
- `_DisneySeriesBody` calcula `prime = skin.id == 'amazon_prime'` y lo pasa a las
  pestañas; al ser el cuerpo común, aplica a **todas** las vistas de detalle de
  serie en Prime.
- `playback_provider.dart`: `start = played ? null : ticks(playbackPositionTicks)`.
- `flutter analyze` → `No issues found!`.
- Verificado en la app por el usuario: estado (visto/a medias), meta y arranque
  (inicio/reanudar) funcionan correctamente.

## Next
- Cerrado.
