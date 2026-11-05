# FTD: franchise-marvel-poster-sin-logo — póster Marvel como imagen MCU, sin logos encima

## Intent
La tarjeta de la franquicia "Universo Cinematográfico Marvel" debe mostrar `assets/images/franchises/Marvel_poster.png` como imagen, sin ningún logo superpuesto. Quitar también el overlay de logo en el resto de tarjetas de franquicias; el usuario creará sus propias imágenes.

## Scope
- `assets/data/franchises.json`: quitar los 5 campos `logo`; añadir a `mcu_infinity_saga` `"posterAsset": "assets/images/franchises/Marvel_poster.png"`.
- `lib/features/franchises/domain/curated_franchise.dart`: nuevo campo `posterAsset` + parseo JSON.
- `lib/features/franchises/application/franchise_providers.dart`: `posterAsset` prioritario como `imageUrl` del hub.
- `lib/features/library/presentation/widgets/poster_card.dart` + `backdrop_card.dart`: si `imageUrl` empieza por `assets/`, usar `Image.asset` (genérico, reutilizable para las imágenes que cree el usuario).
- `lib/features/library/presentation/widgets/content_row.dart`: no precalentar con `CachedNetworkImageProvider` las URLs `assets/` (las gestiona `Image.asset`).
- `lib/features/library/presentation/home_screen.dart` + `lib/features/vod/presentation/vod_screen.dart` (filas de franquicias): forzar `showStackLogo: false` y no pasar `stackLogoFor`.
- No se toca: `PrimeCardBadge`, foco TV, ARB (sin textos nuevos), resto de filas.

## Checklist
- [x] FTD creado antes del cambio
- [x] JSON sin logos + posterAsset en MCU
- [x] Campo `posterAsset` en dominio + provider prioritario
- [x] Soporte `assets/` en PosterCard/BackdropCard
- [x] Precache salta `assets/`
- [x] Filas de franquicias sin `showStackLogo`/`stackLogoFor`
- [x] `flutter analyze` limpio

## Evidence
- Póster existe: `assets/images/franchises/Marvel_poster.png` (1,3 MB); carpeta ya declarada en `pubspec.yaml:171`.
- Causa actual del logo: `home_screen.dart:369` usa `showStackLogo: cfg?.showLogo ?? true` + `stackLogoFor` desde `franchise.logo`; `vod_screen.dart:434` usa `?? false` pero el skin podría activarlo.
- Causa de imagen ignorada si se pone asset en `imageUrl`: `PosterCard`/`BackdropCard` siempre usan `CachedNetworkImage`.

## Next
- `flutter analyze` limpio; arranque visual lo verifica el desarrollador (sin `flutter build` por norma).
