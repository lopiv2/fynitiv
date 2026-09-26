# AXTree error en hover de AppHover (Windows)

## Intent
Cada hover sobre tarjetas con `AppHover` escupe en consola `[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)] Failed to update ui::AXTree, error: 33 will not be in the tree and is not the new root`. Eliminar el spam sin romper hover/focus ni lectores de pantalla.

## Scope
- In: `lib/core/widgets/app_hover.dart` (contenedor semántico por tarjeta).
- Out: engine Flutter (bug upstream abierto #182444, sin fix en ningún release), resto de widgets con Tooltip propio.

## Checklist
- [x] Causa identificada: bug upstream Windows (OverlayPortal/Tooltip + scrollables con two-pane semantics; configs absorbidas entre items) — ver evidencia web.
- [x] Mitigación documentada en campo: `Semantics(container: true)` por ancla (caso medido: ~90 errores → 0).
- [x] Aplicar `Semantics(container: true)` exterior en `AppHover`.
- [x] `Semantics(container: true)` en el ancla del `Tooltip` de `jukebox_entry_card.dart` (Tooltip fuera de AppHover en scrollables).
- [x] `Semantics(container: true)` en `RoundIconButton` (3 Tooltips adyacentes del slider).
- [x] `flutter analyze` de los 3 ficheros → "No issues found!" (1.8s). Nota: una edición intermedia rompió el cierre del `Positioned` en jukebox (error `expected_token` 339:11); reparado y verificado con `git diff` + analyze.
- [x] `_showArrowOverlay()` idempotente en `content_row.dart` y `game_content_row.dart` (reutiliza entrada + `markNeedsBuild`, sin remove/insert por hover).
- [x] `flutter analyze` de ambas filas → "No issues found!" (1.8s).
- [ ] Confirmar con el usuario que el spam desaparece al mover el ratón por tarjetas.

## Evidence
- Upstream: `flutter/flutter#182444` (ListView+Tooltip → mismo error al hovereare), diagnóstico en `#190344`/`#190431` (abiertos, sin fix publicado).
- App: `AppHover` = `Focus` + `MouseRegion` + `GestureDetector` por tarjeta dentro de grids/rows scrollables; sin nodo propio, su config semántica se fusiona con vecinas (`IndexedSemantics`) y el bridge Windows rechaza el update.
- Overlays con `AnimatedOpacity` (media_card, game_continue_card) no montan/desmontan → descartado churn de montaje.
- `flutter analyze lib/core/widgets/app_hover.dart` → "No issues found!" (1.1s).
- El error PERSISTE tras el contenedor en `AppHover` con ids repetidos (1542 x3, 1561, 2064) = nodo overlay huérfano reenviado. Causa real: `Tooltip` (OverlayPortal) FUERA/ENCIMA de tarjetas en scrollables — el contenedor quedó del lado equivocado del ancla:
  - `jukebox_entry_card.dart:284` — `Tooltip` envuelve `AppHover` en listas/grids (receta exacta del bug: hover muestra/oculta el overlay con animación de dismiss → graft corrupto).
  - `round_icon_button.dart:26` — 3 `Tooltip` adyacentes (trailer/fav/info del slider), misma receta del crash documentado (tres Tooltips adyacentes en fila scrolleable).
- Fix: `Semantics(container: true)` del lado del ANCLA (envolviendo el `Tooltip`), no dentro de la tarjeta.
- El error PERSISTE con id estable (1542) → nodo estructural. Nueva causa: `_showArrowOverlay()` en `content_row.dart` y `game_content_row.dart` destruía (`remove`) y recreaba (`insert`) la OverlayEntry de flechas EN CADA hover (y otra vez en post-frame) para usarla como ancla `below:` de la hovercard (`hover_play_card.dart:266`). Cada transición A→B = 2 teardowns del overlay con IconButtons → churn determinista.
- Fix aplicado: `_showArrowOverlay()` idempotente — si existe, `markNeedsBuild()`; solo inserta la primera vez. Z-order intacto (flechas siempre anteriores a cualquier hovercard, que usa `below:` esta entrada).

## Next
- Si persiste: la hovercard expandida (`hover_play_card.dart:237-266`) también se destruye/recrea por hover — siguiente candidato a reutilizar entrada. Y en última instancia el reordenado del Stack (`_buildStackedItems`).
