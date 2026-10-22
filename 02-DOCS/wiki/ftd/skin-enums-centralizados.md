# Enums de skin centralizados en skin_enums.dart

## Intent
Tener los enums del sistema de skin/config localizados en un único archivo (`lib/core/skin/skin_enums.dart`) en vez de repartidos en `skin.dart`, `home_scroll.dart`, `layout_section.dart` y `top_bar.dart`.

## Scope
- In:
  - Nuevo `skin_enums.dart` con todos los enums + `AvatarPosition` + `defaultGenresForTitle`/`titleForGenres`.
  - Los 3 archivos con clases mantienen `import`+`export` del nuevo (cero cambios en los ~27 consumidores); se elimina `top_bar.dart` y sus 5 imports (cubiertos por el export).
- Out:
  - No mover enums de features (alcance a acordar después); sin cambios de comportamiento; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] `skin_enums.dart` creado; comprobar `flutter analyze`.
- [ ] Shims + borrado de `top_bar.dart`; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `lib/core/skin/skin_enums.dart` (nuevo): todos los enums del sistema skin/config (`SidebarPosition`, `LogoPosition`/`AvatarPosition`, `SliderDotAlignment`, `LogoOverlayPosition`, `CardImageType`, `AudioWaveformEffect`, `SliderTransition`, `SliderVignetteMode`, `SeerrDiscoverCategory`, `LayoutSectionType`, `VodSplit`, `TopBarStyle`, `TopBarNavItem`, `RowImageSource`, `RowLogoPosition`, `RowMetaAlign`, `HomeScrollCardType`, `HomeScrollTitle`+`resolve`, `HomeScrollTapAction`, `JellyGenre`, `HomeScrollSort`) + `defaultGenresForTitle`/`titleForGenres`/`jellyGenresFilter`.
- `skin.dart`, `home_scroll.dart`, `layout_section.dart`: `import`+`export` del nuevo; `top_bar.dart` eliminado y sus 5 importadores apuntan a `skin_enums.dart`; imports redundantes limpiados según lint.
- Sin cambios de comportamiento: cero cambios en consumidores.
- `flutter analyze` → `No issues found! (ran en 10.3s)`.

## Next
- Acordar si se extiende a enums de features o se quedan locales.
