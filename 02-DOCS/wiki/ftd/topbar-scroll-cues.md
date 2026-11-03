# Scroll con pistas visuales en la barra superior (móvil)

## Intent

La barra superior de navegación (posición `top`: classic fija, isla
flotante y estilo Netflix) ya tiene `SingleChildScrollView` horizontal,
pero en móvil el scroll no se descubre (sin affordance) y el item activo
puede quedar fuera de la vista. Añadir pistas visuales y auto-centrado
del activo sin tocar la lógica de foco de TV.

## Scope

- In:
  - Nuevo `TopBarScroller` reutilizable (`features/library/presentation/widgets/`):
    scroll horizontal + fades laterales (solo cuando hay overflow y según
    la posición) + auto-centrado del item activo al montar/cambiar.
  - Uso en las tres variantes: classic (`sidebar.dart`), isla
    (`floating_island_bar.dart`), Netflix (`netflix_top_bar.dart`).
  - `flutter analyze` como verificación.
- Out:
  - Visual de los items (`_NavItem`, `_FloatingNavItem`, `_NetflixPill`),
    nodos de foco TV y `FocusScope`/`FocusTraversalGroup` existentes.
  - Otros shells, `PrimeCardBadge`, ARB nuevas (sin textos nuevos),
    tests (no pedidos) y `flutter build` (solo `flutter analyze`).

## Checklist

- [x] `top_bar_scroller.dart` genérico (controller, fades, auto-centrado)
- [x] Classic + isla + Netflix usan `TopBarScroller`
- [x] `flutter analyze` sin problemas; demostrar salida

## Evidence

Implementación (2026-11-03, prueba observada):

- Nuevo `lib/features/library/presentation/widgets/top_bar_scroller.dart`:
  `TopBarScroller(children, isActive)` con `ScrollController` propio,
  fades laterales vía `ShaderMask` (`BlendMode.dstIn`, solo con overflow
  y según posición) y auto-centrado del activo (`Scrollable.ensureVisible`
  `alignment: 0.5`; salto al montar, animado 300 ms al cambiar; sin
  re-scroll en rebuilds por opacidad). Transparente al foco (sin nodos).
- Tocados: `sidebar.dart` (classic), `floating_island_bar.dart` (isla),
  `netflix_top_bar.dart` (Netflix). Predicados `isActive` con los tipos
  privados de cada fichero; items y foco TV intactos.
- `flutter analyze` (full) → `No issues found!`.
- Causa raíz del "sin scroll" (2026-11-04, evidencia en SDK
  `scroll_configuration.dart:120`: `dragDevices` = táctil/stylus/trackpad,
  sin ratón): en escritorio o en el simulador de dispositivo con ratón, un
  `SingleChildScrollView` sin behavior no arrastra. `TopBarScroller` envuelve
  ahora su scroll en `ScrollConfiguration(behavior:
  HorizontalScrollBehavior())`, el mismo patrón que `content_row.dart:1267`.

## Next

Probar en móvil 390×844 con skin top (classic, isla y Netflix):
arrastrar la barra, comprobar fades y que el activo arranca centrado;
verificar que en TV el D-pad sigue igual.
