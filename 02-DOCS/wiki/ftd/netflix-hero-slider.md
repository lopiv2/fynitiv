# FTD: netflix-hero-slider — billboard estilo Netflix solo para el skin Netflix

## Intent
Que el `FeaturedSlider` del skin `netflix` se vea como la foto (billboard: título/logo grande, meta `género • año • temporadas • edad • CC`, sinopsis, botones píldora `Play` + `More Info`, insinuación `We think you'll love this!` abajo a la derecha). Solo afecta al skin con `id == 'netflix'`; el resto de skins no cambian.

## Scope
- `lib/features/library/presentation/widgets/featured_slider.dart`: rama hero cuando `skin?.id == 'netflix'` dentro de `_SliderBannerCard` (mismo widget, sin duplicar slider). Reutiliza `_buildLogoSlide`, `_openPlayer`, `_openDetails`, nodos de foco TV existentes (Play→nodo 0, More Info→nodo 1, compactados como cuando no hay trailer).
- Botones píldora nuevos (`_NetflixHeroButton`) con widget universal `AppHover` (scale) + `FocusNode` para no perder modo TV.
- ARB (en+es): `moreInfo` ("More Info"/"Más información"), `netflixHeroMatch` ("We think you'll love this!"/"Creemos que te va a encantar"). Reutiliza `play` y `seriesSeasons` existentes. Regenerar con `flutter gen-l10n`.
- `lib/features/library/application/library_providers.dart`: añadir `ItemFields.childCount` y `ItemFields.mediaStreams` a `bannerItemsForProvider` (temporadas y badge CC del hero).
- Sin cambios de preset: el hero se activa por `skin.id`, no por flags nuevos (sin JSON/copyWith).
- No se toca: `PrimeCardBadge`, autoplay, trailer lateral, dots (siguen abajo-derecha; el hint va encima de ellos).

## Checklist
- [x] FTD creado antes del cambio
- [x] ARB en+es + `flutter gen-l10n`
- [x] provider: fields childCount + mediaStreams en banner
- [x] hero: título/logo, meta foto, sinopsis, píldoras Play/More Info con AppHover + foco TV
- [x] hint "love this" abajo-derecha sin tapar dots
- [x] resto de skins intactos (rama solo netflix)
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (slider + providers): `No issues found!`.
- Solo 2 infos preexistentes en `app_localizations.dart` generado (deprecados de material_ui, no tocados).

## Next
- Captura en Windows con skin Netflix y confirmar equivalencia con la foto; si el CC casi nunca aparece, valorar quitarlo.
