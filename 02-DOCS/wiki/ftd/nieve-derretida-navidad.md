# Nieve derretida de Navidad (tarjetas y letras)

## Intent
Añadir un efecto de nieve derretida —capa superior con borde ondulado y chorretes— sobre las
tarjetas de contenido y sobre las letras de FYNITIV de la splash, activo solo en Navidad, sutil y
sin distraer.

## Scope
- In:
  - Componente reutilizable `snow_drip.dart`: `buildSnowDripPath`, `SnowCapPainter`,
    `SnowCapOverlay` y `SnowDripClipper` (mismo lenguaje visual para tarjetas y letras).
  - Tarjetas `PosterCard`, `BackdropCard` y `LibraryGridCard`: capa de nieve sobre la imagen y
    bajo badges/títulos; semilla por item; chorretes animados solo al hover.
  - Letras de `_LetterTile` en la splash: copia blanca del glifo recortada con `SnowDripClipper`,
    con deshielo muy lento usando el clock existente.
  - Gate único por estación: `SeasonalEvent.christmas`.
- Out:
  - Ajuste de skin para activar/desactivar la nieve (solo estación).
  - Animación continua en todas las tarjetas (rendimiento).
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] `snow_drip.dart` con forma compartida; `flutter analyze`.
- [x] Nieve en las tres tarjetas con hover sutil; `flutter analyze`.
- [x] Nieve en las letras de la splash; `flutter analyze`.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- `PosterCard`, `BackdropCard` y `LibraryGridCard` son `Consumer*` y ya apilan imagen, viñeta y
  badges, así que pueden leer `activeSeasonalEventProvider` y añadir un overlay sin cambiar sus
  múltiples llamadas.
- `_LetterTile` pinta la cara frontal (`_face(gradient, outline: true)`) dentro de un `Stack`;
  se puede añadir una capa recortada con `ClipPath` sobre la misma `Text`.
- `activeSeasonalEventProvider` ya respeta calendario y override de debug; el clock de la splash
  (`_controller.value`, 13 s) sirve como fase para el deshielo.
- Repositorio en rama `main`.
- `lib/core/widgets/snow_drip.dart`: `buildSnowDripPath` (contorno determinista por seed),
  `SnowCapPainter` (relleno degradado + sombra), `SnowCapOverlay` y `SnowDripClipper`.
- `PosterCard` y `BackdropCard`: overlay insertado inmediatamente después de la imagen y bajo
  viñetas/badges; seed a partir de id/nombre; `TweenAnimationBuilder` extiende los chorretes
  sutilmente al hover/focus de imagen.
- `LibraryGridCard`: mismo overlay, recortado a esquinas de 16 px, seed por biblioteca y
  animación sutil al hover/focus universal.
- `splash_screen.dart` / `_LetterTile`: copia clara de cada glifo recortada con
  `SnowDripClipper` (seed por carácter); el deshielo deriva de `_controller.value` (1.5 ciclos
  suaves por presentación). Se limita a `presentation.id == 'christmas'`.
- `flutter analyze` → `No issues found! (ran in 10.9s)`.

## Next
Revisar el resultado en varios tamaños de tarjeta y en la splash; ajustar profundidad/chorretes y
la fase del deshielo.
