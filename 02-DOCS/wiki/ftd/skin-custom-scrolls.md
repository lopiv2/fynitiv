# Skin custom con scrolls configurables (Inicio/VOD)

## Intent
Añadir en Preferencias/Apariencia un tema/skin "Custom" seleccionable por chip que use los colores definidos por el usuario en Apariencia y ofrezca un cuadro de elementos para añadir scrolls custom a VOD e Inicio (estilo Acción, Comedia, etc., a decisión del usuario: género, tipo, título).

## Scope
- In:
  - Nuevo preset `SkinPresets.custom` (id `custom`, nombre `Custom`) con `homeLayout`/`vodLayout` base (featuredSlider, continueWatching, nextUp, recent, library) y colores por defecto = Jellyfin; al seleccionarlo los colores de Apariencia se aplican sobre él y persisten.
  - Editor "Skin custom" visible solo cuando el skin activo es `custom`: dos grupos (Inicio / VOD) que listan las secciones `custom`, con añadir / editar / eliminar / subir / bajar. Reutiliza `AppHover` y `ScaleButton`; toasts con `flutter_easyloading`; sin `ScaffoldMessenger` en código nuevo.
  - Modelo: `HomeScroll.customTitle` (String?, solo cuando `titleKey == custom`) con soporte JSON; `HomeScrollTitle.resolve` acepta título libre; pantallas Inicio/VOD/`library_view_screen` lo prefieren.
  - Render: los scrolls custom nuevos usan el path existente (`homeScrollItemsProvider` + `ContentRow` con `AppHover`), por lo que heredan loader, hover universal, focus TV (`FocusTraversalGroup` + `AppHover trackFocus`) y colores del skin. Añadir `FocusTraversalGroup` al `ListView` de VOD para paridad con Inicio.
  - Cadenas ARB nuevas en `app_en.arb`/`app_es.arb` (mínimo EN+ES, reutilizando claves existentes) + `flutter gen-l10n`; sin textos de debug traducidos.
- Out:
  - No tocar posición de `PrimeCardBadge` ni otros retoques manuales del usuario.
  - No cambiar calendario estacional, presets existentes ni su orden visual (solo añadir `custom` al final de `SkinPresets.all`).
  - Sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [x] Preset `custom` en `skin_presets.dart` + incluido en `all`; comprobar `flutter analyze`.
- [x] `HomeScroll.customTitle` con JSON/`==`/`hashCode`; `resolve` con título libre; comprobar `flutter analyze`.
- [x] Título libre resuelto en Inicio/VOD/library (3 call sites); comprobar render y `flutter analyze`.
- [x] Editor `CustomSkinSection` (widget genérico reutilizable) integrado en `AppearancePanel` solo para `custom`; CRUD + reorden con `apply`; toasts EasyLoading; comprobar render y `flutter analyze`.
- [x] `FocusTraversalGroup` en VOD; comprobar navegación TV y `flutter analyze`.
- [x] ARB EN+ES + `flutter gen-l10n`; comprobar getters generados.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `lib/core/skin/skin_presets.dart`: nuevo `SkinPresets.custom` (id `custom`, colores base Jellyfin, `homeLayout`/`vodLayout` con built-ins, `seerrLayout` estándar) añadido al final de `all` → chip "Custom" en Apariencia.
- `lib/core/skin/home_scroll.dart`: campo `customTitle` (JSON/`==`/`hashCode`); `HomeScrollTitle.resolve(l10n, title, [customTitle])` devuelve el nombre libre cuando `titleKey == custom`.
- `lib/features/settings/presentation/widgets/custom_skin_section.dart` (nuevo, genérico reutilizable): grupos Inicio/VOD con añadir/editar/eliminar/subir/bajar sobre secciones `custom`; filas con `AppHover` universal; diálogo con título (18 existentes + libre), géneros (`JellyGenre`, nombres exactos de Jellyfin), tipos (película/serie), póster/backdrop, orden, límite; toasts vía `flutter_easyloading` (`maskType.none`, `dismissOnTap`); sin `ScaffoldMessenger` en código nuevo.
- `appearance_panel.dart`: sección `CustomSkinSection` solo si `_draft.id == 'custom'`, tras los chips de preset; los colores de Apariencia se aplican sobre el propio draft custom.
- `home_screen.dart`, `vod_screen.dart`, `library_view_screen.dart`: `_scrollTitle`/`_resolveScrollTitle` resuelven con `customTitle`.
- `vod_screen.dart`: `ListView` envuelto en `FocusTraversalGroup(ReadingOrderTraversalPolicy())` como en Inicio (foco TV).
- ARB: 22 claves nuevas en `app_en.arb`/`app_es.arb` (`customSkin`, `customSkinHint`, `homeCustomRows`, `vodCustomRows`, `addCustomRow`, `editCustomRow`, `noCustomRows`, `customName`, `customRowTitle`, `genres`, `types`, `genreNamesHint`, `customSort`, `sortRecent`, `sortRating`, `sortAdded`, `sortRandom`, `customLimit`, `delete`, `moveUp`, `moveDown`, `needGenre`, `customRowAdded`, `customRowUpdated`, `customRowRemoved`); reutilizadas `poster`, `backdrop`, `cardImageType`, `searchTypeMovie`, `searchTypeSeries`, `sortAZ`, `cancel`, `save`.
- `flutter gen-l10n` regeneró `app_localizations*.dart` (getters `customSkin`, `sortRecent`, `needGenre`, `customRowTitle` verificados).
- `flutter analyze` → `No issues found! (ran in 16.1s)`.

## Next
- Probar en la app: seleccionar chip Custom, cambiar colores y comprobar que Inicio/VOD los usan; añadir un scroll custom (p. ej. Comedia solo-series en VOD), reordenar y eliminar; reiniciar y verificar persistencia; navegar con mando en modo TV por los nuevos scrolls.
