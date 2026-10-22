# Preset de skin Netflix

## Intent
Añadir un selector (chip) de skin estilo Netflix en Apariencia como punto de partida: fondo casi negro, acento rojo, barra superior, tarjetas backdrop 16:9 y billboard superior con acciones.

## Scope
- In:
  - Nuevo preset `SkinPresets.netflix` (id `netflix`) con paleta (#E50914 sobre #141414/#000), `sidebarPosition.top` sin isla flotante, `cardImageType.backdrop`, radio pequeño, billboard con `bannerAttachedTop` + acciones + edad recomendada, y `homeLayout`/`vodLayout` base (featuredSlider, continueWatching, nextUp, recent/library, customs de acción y comedia en backdrop).
  - Incluirlo al final de `SkinPresets.all` (detrás de `custom`) sin alterar presets existentes.
  - Sin claves ARB nuevas (nombre fijo `Netflix`, como el resto de marcas).
- Out:
  - No tocar `PrimeCardBadge`, presets existentes, editor custom ni layouts de otras pantallas.
  - Sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Preset `netflix` en `skin_presets.dart` + incluido en `all`; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `lib/core/skin/skin_presets.dart`: nuevo `SkinPresets.netflix` (id `netflix`, paleta rojo #E50914 sobre negro #141414/#000, barra superior sin isla, backdrop 16:9, radio 4, billboard con `bannerAttachedTop` + acciones + edad + trailer, `homeLayout`/`vodLayout` con featuredSlider, continueWatching con play, nextUp, recent/library y customs de acción y comedia en backdrop) añadido al final de `all` → chip "Netflix" en Apariencia tras "Custom".
- Sin claves ARB nuevas (nombre de marca fijo, como el resto de presets).
- `flutter analyze` → `No issues found! (ran in 11.8s)`.

## Next
- Seleccionar el chip Netflix en Apariencia y comprobar Inicio/VOD; ajustar valores (alturas, espacios, banner) según feedback visual.
