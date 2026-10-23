# FTD: netflix-hero-arrows — flechas deterministas en el hero

## Intent
Que ←/→ cambien de banner en el hero Netflix de forma fiable, sin depender de la detección de bordes de `focusInDirection` (una capa `Focus` táctil invisible puede absorber el movimiento y el cambio nunca dispara).

## Scope
- `featured_slider.dart`: la fila hero lleva su propio `FocusScope` con `onKeyEvent`: ← en Play → anterior, → en More Info → siguiente; resto ignorado (burbujea al slider). El índice enfocado se sigue con `onFocusChange` de `AppHover`.
- `_SliderBannerCard` recibe `onPrevBanner`/`onNextBanner` del padre (que ya tiene `_goToPrev/_goToNext`). La lógica vieja del scope del slider queda como fallback.
- Sin cambios para skins con dots.

## Checklist
- [x] FTD creado antes del cambio
- [x] callbacks prev/next hacia la tarjeta
- [x] FocusScope propio del hero + índice enfocado
- [x] foco explícito entre píldoras (sin traversal)
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (slider): `No issues found!`.

## Next
- Probar con teclado en PC: → en More Info cambia, ← en Play retrocede.
