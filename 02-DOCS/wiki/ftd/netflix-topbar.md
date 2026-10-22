# Topbar modular por skin + estilo Netflix

## Intent
Modularizar la creación de la topbar para adaptarla según el skin (igual que los `LayoutSection`/`HomeScroll` de Inicio/VOD) y darle al skin Netflix la barra de la foto: avatar con desplegable a la izquierda, nav centrada con píldora blanca en el activo (buscar, Home, Shows, Movies, Games, My Netflix) y logo de marca a la derecha.

## Scope
- In:
  - Nuevo `lib/core/skin/top_bar.dart`: `TopBarStyle { classic, netflix }` + `TopBarNavItem { search, home, shows, movies, games, myNetflix }`.
  - `Skin`: `topBarStyle` (defecto `classic`) + `topBarNavItems` (defecto lista Netflix) con `copyWith`/JSON (`topBarStyle`, `topBarNavItems`).
  - Preset Netflix: `topBarStyle: TopBarStyle.netflix`.
  - Nuevo `NetflixTopBar` (widget reutilizable): avatar izq. con menú (extraído a `UserAvatarMenu` genérico y reutilizado en `Sidebar`), nav central con píldora, logo der.; respeta foco TV (`ScaleButton` + `tvInicioFocusNode` en Home) y opacidad por scroll (transparente sobre el billboard, como Prime).
  - `home_shell.dart`: `barOpacity` por scroll también para topbar Netflix superpuesta.
  - ARB EN+ES: `shows`, `movies`, `myNetflix` (+ `flutter gen-l10n`); reutilizar resto.
- Out:
  - No cambiar el render classic/isla ni otros presets; estilo Netflix solo afecta a la rama horizontal cuando `topBarStyle == netflix`.
  - No tocar `PrimeCardBadge`; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] `top_bar.dart` con enums; comprobar `flutter analyze`.
- [ ] Campos en `Skin` con JSON/`copyWith`; comprobar `flutter analyze`.
- [ ] `UserAvatarMenu` extraído y reutilizado en `Sidebar` + `NetflixTopBar`; comprobar `flutter analyze`.
- [ ] `NetflixTopBar` como la foto (avatar, píldora, logo) con foco TV; comprobar `flutter analyze`.
- [ ] Preset Netflix con `topBarStyle.netflix` + `barOpacity` en `home_shell`; comprobar render y `flutter analyze`.
- [ ] ARB EN+ES + `flutter gen-l10n`; comprobar getters.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `lib/core/skin/top_bar.dart` (nuevo): `TopBarStyle { classic, netflix }` + `TopBarNavItem { search, home, shows, movies, games, myNetflix }` documentados.
- `lib/core/skin/skin.dart`: `topBarStyle` (defecto `classic`) + `topBarNavItems` (defecto lista Netflix) con `copyWith`, `fromJson` (tolerante a desconocidos) y `toJson`.
- `lib/features/library/presentation/widgets/user_avatar_menu.dart` (nuevo, genérico reutilizable): avatar con menú de cerrar sesión extraído de `Sidebar`; usado en `Sidebar` (lateral + classic) y en `NetflixTopBar`.
- `lib/features/library/presentation/widgets/netflix_top_bar.dart` (nuevo): avatar izq. + caret, nav centrada (buscar + píldoras `AppHover` con píldora blanca en activo/hover/foco TV, `tvInicioFocusNode` en Home), logo der.; `shows`/`movies` resuelven la vista por `CollectionType` y se ocultan si no existe; `myNetflix` → `/library`; fondo transparente→sólido con `barOpacity`.
- `sidebar.dart`: rama horizontal usa `NetflixTopBar` si `topBarStyle == netflix` (antes de classic); `_UserAvatar` eliminado.
- `lib/router/home_shell.dart`: `barOpacity` por scroll también para topbar Netflix superpuesta.
- `skin_presets.dart`: Netflix con `topBarStyle: TopBarStyle.netflix`.
- ARB: `shows`/`movies`/`myNetflix` en `app_en.arb`/`app_es.arb`; `flutter gen-l10n` regeneró getters (verificados `shows`, `movies`, `myNetflix`).
- `flutter analyze` → `No issues found! (ran en 15.2s)`.

## Next
- Probar en app: chip Netflix, scroll (barra transparente→sólida), cada item del nav, desplegable del avatar y mando en modo TV.
