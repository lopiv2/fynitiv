# Sincronía de subtítulos por texto (elegir la línea)

## Intent
Poder sincronizar un subtítulo eligiendo en un diálogo transparente la línea del
fichero que coincide con lo que se está diciendo. Al tocar la línea, se calcula el
desfase (`sub-delay`) para que esa línea empiece en el instante actual. Formatos
soportados: SRT, WebVTT, ASS y SSA. Límite ±60 s. Con filtro de texto. Botón junto al
slider de sincronía.

## Scope
- In:
  - `lib/features/subtitles/domain/subtitle_cues.dart`: parser SRT/VTT/ASS/SSA a líneas.
  - `lib/features/subtitles/presentation/subtitle_sync_dialog.dart`: diálogo transparente
    con filtro, lista de líneas, resalte de la actual y selección.
  - `lib/features/player/presentation/player_screen.dart`: botón junto al slider, carga del
    texto de la pista activa (data/uri/integrada), cálculo y aplicación de `sub-delay`,
    límite ±60 s.
  - `lib/l10n/app_en.arb` + `app_es.arb`: cadenas nuevas.
- Out: calibración por dos puntos; guardar el desfase en el servidor; edición del fichero.

## Checklist
- [x] FTD antes del primer cambio
- [x] Parser SRT/VTT/ASS/SSA
- [x] Diálogo transparente con filtro + resalte + autofocus
- [x] Carga del texto de la pista activa (data/uri/API)
- [x] Cálculo `sub-delay = posición − inicio` y clamp ±60
- [x] Botón junto al slider + límite ±60 en slider/atajos
- [x] Cadenas ARB (en/es) + `flutter gen-l10n`
- [x] `flutter analyze` limpio
- [x] Fix "no se pudo leer el texto": carga por API autenticada (índice de stream, SRT→VTT) antes del respaldo por URL

## Evidence
- El texto de las pistas de datos (`SubtitleTrack.data`) está en `track.id`; las URI del
  servidor (`SubtitleTrack.uri`) traen una URL con `api_key` que se puede descargar.
- `_applySubtitleDelay` / `_persistSubtitleDelay` ya aplican y guardan `sub-delay` de mpv.
- mpv `sub-delay` positivo = subtítulo más tarde → `desfase = posición − inicioLínea`.
- Se guarda `_appliedSubtitleTrack` (la pista que eligió el usuario) porque la que
  reporta mpv pierde los flags `data`/`uri`; así la carga del texto es fiable.
- La posición se lee **después** de cerrar el diálogo (en el momento del toque), no al
  abrirlo, para que el desfase sea correcto.
- `flutter gen-l10n` genera `subtitleSyncByText`, `subtitleSyncPickLine`,
  `subtitleSyncHint`, `subtitleFilterHint`, `subtitleTextUnavailable` (en/es).
  `flutter analyze` (proyecto completo) → `No issues found!`.
- Fix reportado ("no se pudo leer el texto" al pulsar el botón): antes se dependía de
  descargar la URL de la pista (`http.get`), que puede fallar (URL de entrega absoluta,
  auth, redirección). Ahora `_loadSubtitleTextViaApi` localiza el stream por `DeliveryUrl`
  o idioma (prefiriendo externos) y pide el texto con `getSubtitleApi().getSubtitle`
  (formato `srt` y, si falla, `vtt`), usando el Dio autenticado. La URL queda de respaldo.
  Se añade `debugPrint` `[subtitle-sync]` con el motivo si sigue sin texto.

## Next
- Probar con un SRT descargado: abrir el diálogo, filtrar, tocar la línea que suena y
  comprobar el desfase; afinar con los botones ±0,5 s.
- Valorar calibración por dos puntos o por desplazamiento continuo si hace falta más
  precisión.
