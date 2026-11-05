# FTD: franchise-poster-assets — imágenes locales para cada franquicia

## Intent
Asignar a cada franquicia del hub su imagen local de `assets/images/franchises/`, sin logos superpuestos (el usuario ya creó sus imágenes).

## Scope
- `assets/data/franchises.json`: añadir `posterAsset` a las 4 franquicias restantes (MCU ya lo tiene).
- No se toca: código, `PrimeCardBadge`, foco TV, ARB.

## Checklist
- [x] FTD creado antes del cambio
- [x] `posterAsset` en star_wars, harry_potter, fast_furious, lotr
- [x] JSON válido + `flutter analyze` limpio

## Evidence
- Nuevos ficheros en `assets/images/franchises/` (05/11/2026): `starwars.jpg`, `harry_potter.webp`, `fastfurious.webp`, `lotr.jpg`; MCU ya usa `Marvel_poster.png`.
- Mapeo: star_wars_skywalker → `starwars.jpg`; harry_potter → `harry_potter.webp`; fast_furious → `fastfurious.webp`; lotr → `lotr.jpg`.

## Next
- Verificación visual por el desarrollador (sin `flutter build` por norma).
