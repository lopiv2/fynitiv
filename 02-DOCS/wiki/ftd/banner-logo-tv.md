# Tamaño y posición del logo del featured slider (TV / resoluciones)

## Intent
En los banners del featured slider (home y VOD):
1. Los logos/títulos se veían demasiado grandes en TV (el logo no compartía el
   ajuste por plataforma del resto del contenido).
2. En móvil/tablet el logo no aparecía (el banner es bajo y los offsets fijos
   dejaban la zona central casi sin altura; el logo se recortaba).
3. Faltaba hueco entre el logo y la fila de calificación/géneros de debajo
   (skin Disney, `inlineMeta`), y al forzarlo se recortaba el logo.

Todo se resuelve dimensionando por `MediaQuery` y unificando logo + meta en una
sola columna (abajo-izquierda; centrada verticalmente en TV).

## Scope
- In:
  - `core/constants/ui_constants.dart`: helper `uiScaleFor(Size)`.
  - `featured_slider.dart`: logo escalado por tamaño de pantalla; offsets
    verticales proporcionales (`screenInset`); bloque logo + meta en una sola
    `Column` con `SizedBox(logoMetaGap)` explícito, `FittedBox(scaleDown)` como
    red de seguridad; `_NewBadge` escalable; escala de contenido y posición
    específicas de TV.
- Out: valores de skin (`bannerLogoMaxHeight`, `bannerLogoWidthFactor`,
  `bannerContentScale`), resto del banner.

## Checklist
- [x] FTD antes del primer cambio
- [x] Helper `uiScaleFor(Size)` reutilizable con MediaQuery
- [x] Logo escalado por tamaño de pantalla (+ factor TV)
- [x] Offsets verticales proporcionales a la altura de pantalla
- [x] Logo + meta en una sola columna con hueco explícito (sin recorte)
- [x] `FittedBox(scaleDown)` + `_NewBadge` escalable (robusto a cualquier resolución)
- [x] `flutter analyze` limpio

## Evidence
- `ui_constants.dart`: `uiScaleFor(Size)` combina ancho/alto con referencia
  1600×900, toma el menor ratio y lo acota a [0.5, 1.0].
- `_buildLogoSlide(constraints, ui)`: `s = contentScale * ui`. `ui` se calcula
  en `build` con `uiScaleFor(mq, max: isTv ? 1.2 : 1.0)` (en TV crece hasta 1.2).
- Escala del contenido del banner: `s = contentScale * (isTv ? 1.0 : 1.5)`
  (antes en TV era `0.22`, que dejaba todo diminuto).
- `screenInset = (alturaPantalla * 0.08).clamp(0, 140)` para `top`.
- Un único `Positioned` (`featured_slider.dart`): `Align(bottomLeft)` (en TV
  `centerLeft`, para que el bloque no quede pegado abajo) → `FittedBox(scaleDown)`
  → `SizedBox(width=area)` → `Column(min)` con [logo/acciones/descripción] +
  `SizedBox(logoMetaGap)` + [meta]. El hueco es un `SizedBox` real.
  - `logoMetaGap = (28 * ui).clamp(16, 40)`.
  - `_NewBadge` acepta `scale` (se le pasa `ui`).
- `flutter analyze` → `No issues found!`.
- Validado por el usuario en app: todo correcto en móvil/tablet/desktop y TV.

## Next
- Cerrado. No hay pasos pendientes.

