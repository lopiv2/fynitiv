# Topbar estilo Prime: sin iconos y lupa a la derecha

## Intent
Dar al skin Amazon Prime su propio tipo de topbar: quitar los iconos de todos los elementos (navegación solo-texto) y pasar Buscar a la derecha pegado a Ajustes como solo una lupa (sin texto).

## Scope
- In:
  - `TopBarStyle.prime` (+ docs); preset Prime con `topBarStyle: TopBarStyle.prime`.
  - `Sidebar`: rama prime en horizontal — mismos accesos que classic pero `withIcons=false` (items, menú Biblioteca con `textOnly`, Ajustes solo-texto); Buscar sale del flujo y va a la derecha como lupa (`TopBarIconButton`).
  - Nuevo `TopBarIconButton` genérico reutilizable (lupa con `AppHover` + tooltip); `_NetflixIconButton` pasa a usarlo.
  - `_NavItem._buildRow` y `_TopBarLibraryMenu`: sin hueco de icono cuando no hay icono (`textOnly`).
- Out:
  - No cambiar classic/island/netflix ni otros presets; sin ARB nuevas (reutiliza `search`); sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] `TopBarStyle.prime` + preset; comprobar `flutter analyze`.
- [ ] Rama prime solo-texto + lupa a la derecha; comprobar `flutter analyze`.
- [ ] `TopBarIconButton` genérico y refactor Netflix; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `top_bar.dart`: `TopBarStyle.prime` documentado (solo-texto + lupa a la derecha).
- `skin_presets.dart`: Prime con `topBarStyle: TopBarStyle.prime`.
- `sidebar.dart`: `isPrimeBar` quita iconos de los 7 items + Biblioteca (`textOnly`) + Ajustes; Buscar sale del flujo y va a la derecha como lupa pegada a Ajustes; `_buildRow` sin hueco si no hay icono.
- `top_bar_icon_button.dart` (nuevo, genérico reutilizable con `AppHover`): usado en Prime y en Netflix (refactor de `_NetflixIconButton` eliminado).
- Sin ARB nuevas (`search` reutilizado para el tooltip de la lupa).
- Ajuste posterior: sin Ajustes en la barra Prime (ya está en el desplegable del avatar) — `if (!isPrimeBar) settings`.
- Ajuste posterior: texto Prime en blanco con más peso — `emphasized` en `_NavItem` (w700 reposo / w800 activo) y `_TopBarLibraryMenu`, activo solo con `TopBarStyle.prime`.
- `flutter analyze` → `No issues found! (ran en 6.6s)`.

## Next
- Probar en app con skin Prime: items sin iconos, lupa a la derecha, activo/hover y mando en TV.
