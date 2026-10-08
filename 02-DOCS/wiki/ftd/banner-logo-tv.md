# Tamaño del logo del featured slider acorde a la plataforma (TV)

## Intent
En los banners del featured slider (home y VOD) los logos/títulos se ven
demasiado grandes en TV. El resto del contenido (texto, botones) ya recibe un
ajuste por plataforma, pero el logo usa solo `contentScale`, por lo que queda
desproporcionado en TV.

Bug relacionado (mismo banner): en móvil/tablet el logo no aparecía en absoluto
porque el banner es bajo y los offsets fijos de la columna (top 134 / bottom 130)
dejaban la zona central con ~16px, recortando el logo.

Se sustituyen los valores fijos/mágicos por dimensionado **proporcional al
tamaño de pantalla vía `MediaQuery.sizeOf`**, con un helper reutilizable.

## Scope
- In: helper `uiScaleFor(Size)` en `core/constants/ui_constants.dart`;
  `_buildLogoSlide` escala el logo por `uiScaleFor(MediaQuery.sizeOf(context))`
  (+ factor TV); offsets verticales de la columna del logo y de la meta
  (`screenInset = alturaPantalla * 0.08`) en `featured_slider.dart`; hueco
  escalable `logoMetaGap` entre el logo y la fila de calificación/géneros
  (inlineMeta de Disney) más reserva del alto de la meta.
- Out: escala `s` del resto del contenido (valor manual del usuario `0.22` en
  TV), valores de skin (`bannerLogoMaxHeight`, `bannerLogoWidthFactor`,
  `bannerContentScale`), resto del banner.

## Checklist
- [x] FTD antes del primer cambio
- [x] Helper `uiScaleFor(Size)` reutilizable con MediaQuery
- [x] Logo escalado por tamaño de pantalla (+ factor TV)
- [x] Offsets verticales proporcionales a la altura de pantalla
- [x] Hueco escalable entre logo y meta inferior
- [x] `flutter analyze` limpio

## Evidence
- `ui_constants.dart`: `uiScaleFor(Size)` combina ancho/alto con referencia
  1600×900 y toma el menor ratio, acotado a [0.6, 1.0]. Reutilizable.
- `_buildLogoSlide`: `s = contentScale * uiScaleFor(MediaQuery.sizeOf(context)) *
  (isTv ? _kTvLogoScale : 1.0)`. Tamaños resultantes (logo base 110):
  móvil/tablet ≈66, desktop ≈88, TV ≈79.
- Offsets: `screenInset = (alturaPantalla * 0.08).clamp(40,140)`; en móvil 800 →
  64 (antes 134/130 → zona útil ~16px, ahora ~152px). TV mantiene 80/24.
- Separación logo↔meta: `logoBottom = metaBottom + metaRowHeight +
  overviewReserve + logoMetaGap`, con `logoMetaGap = (28 * ui).clamp(16,40)`
  (móvil ≈17, desktop ≈22, TV 28), `metaRowHeight` 30 (inline) / 26 (normal) y
  `overviewReserve` 66 cuando el skin muestra la sinopsis bajo la meta. El
  `bottom` del logo se ancla por encima de todo el bloque inferior + hueco, así
  el espacio entre logo y la fila edad/año • géneros (Disney, inlineMeta) queda
  garantizado y escala con la pantalla.
- `flutter analyze` → `No issues found!`.

## Next
- Validar visualmente el hueco logo↔calificación/géneros en el skin Disney
  (móvil, tablet, desktop y TV). Ajustables: el `28` de `logoMetaGap`, el `0.08`
  de `screenInset` y `uiScaleFor` (referencias/rango).



