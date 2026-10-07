# Sincronía de subtítulos — botones finos para TV y ratón

## Intent
El ajuste de sincronía (`sub-delay`) solo se podía hacer arrastrando el slider ±10 s, incómodo
con mando de TV y poco preciso con ratón. Añadir botones finos de −0,5 s / +0,5 s y atajos de
teclado (estilo mpv `z`/`x`) para afinar el desfase respecto al audio.

## Scope
- In:
  - `lib/features/player/presentation/player_screen.dart`:
    - `_SubtitleSyncSlider`: botones −0,5 s / +0,5 s junto al slider (mouse/táctil y focusables).
    - `_PlayerViewState._nudgeSubtitleDelay(...)` + atajos de teclado `z` (−0,5 s), `Z`/`x` (+0,5 s).
    - Guarda de foco: las flechas navegan entre controles cuando hay foco en un hijo; hacen
      seek solo con el foco en la raíz.
  - `lib/l10n/app_en.arb` + `app_es.arb`: tooltips de los botones.
- Out: rediseño de la barra como mini-línea de tiempo (opción A/B descartadas por ahora).

## Checklist
- [x] FTD antes del primer cambio
- [x] Botones −0,5 s / +0,5 s (clamp ±10, persisten por item)
- [x] Atajos de teclado `z` / `Z` / `x`
- [x] Guarda de foco para D-pad
- [x] Cadenas ARB (en/es) + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `sub-delay` de mpv: positivo = subtítulos más tarde (`z`/`Z` = ∓0,1 s en mpv; aquí ±0,5 s).
- El control vive en `_buildOverlay` (`player_screen.dart:1258`), sobre la barra de progreso.
- `_onKey` (`player_screen.dart:806`) captura flechas para seek; se añade guarda
  `hasPrimaryFocus` para no bloquear la navegación por foco.
- `flutter gen-l10n` genera `subtitleDelayEarlier` / `subtitleDelayLater` (en/es).
  `flutter analyze` (proyecto completo) → `No issues found!`.

## Next
- Probar en TV: navegar con D-pad hasta los botones (Tab/D-pad) y ajustar con −/+; en ratón,
  clic. Verificar que el valor persiste al reabrir la película.
- Valorar etiquetar la barra o una mini-línea de tiempo si sigue sin ser evidente.
