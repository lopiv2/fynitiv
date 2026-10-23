# FTD: banner-top-padding — hueco configurable entre barra y slider

## Intent
Poder ajustar por skin el hueco vertical entre la barra superior y el `FeaturedSlider` (hoy fijo: 0 si `bannerAttachedTop`, 54 si no).

## Scope
- `lib/core/skin/skin.dart`: campo `bannerTopPadding` (defecto 54.0) + `copyWith`/JSON.
- `home_screen.dart` y `vod_screen.dart`: `top: bannerAttached ? 0 : (skin?.bannerTopPadding ?? 54)`.
- No cambia el defecto de ningún skin; Netflix lo ajustará el usuario a mano si quiere.

## Checklist
- [x] FTD creado antes del cambio
- [x] campo en Skin + copyWith + JSON
- [x] uso en home y VOD
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (skin + home + VOD + presets): `No issues found!`.

## Next
- Ninguno; el usuario pone el valor que quiera en el preset Netflix.
