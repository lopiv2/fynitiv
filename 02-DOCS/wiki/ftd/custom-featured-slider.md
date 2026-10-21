# Slider destacado (featured slider) en el tema Custom

## Intent
Dar la posibilidad de añadir un featured slider (banner de novedades) a Inicio y VOD del tema Custom desde el editor de la sección "Skin personalizado", con su interruptor para mostrarlo u ocultarlo.

## Scope
- In:
  - Claves ARB EN+ES (`addSlider`, `featuredSliderName`, `showBannerRow`, `showBannerRowHint`, `sliderAdded`, `sliderRemoved`) + `flutter gen-l10n`.
  - `CustomSkinSection`: switch "Mostrar slider destacado" (`draft.showNewReleasesBanner`) + botón para añadir `LayoutSection.featuredSlider()` en cada grupo (Inicio/VOD); al añadir se activa el banner para que se vea al instante.
  - `_GroupBlock`: lista secciones `custom` y `featuredSlider` con subir/bajar/eliminar; las de slider muestran etiqueta traducida sin diálogo de edición.
  - Render existente (`home_screen.dart`/`vod_screen.dart`, `homeScrollItemsProvider` no implicado, `FeaturedSlider` + `FocusTraversalGroup` ya heredados) sin cambios: paridad de foco TV.
  - Solo `flutter analyze` (sin build, sin tests no pedidos).
- Out:
  - No tocar presets, `PrimeCardBadge`, ni otros skins.
  - Sin `ScaffoldMessenger` (toasts con `flutter_easyloading`).

## Checklist
- [x] ARB EN+ES + `flutter gen-l10n`.
- [x] Switch de banner + añadir slider en Inicio y VOD; el banner se auto-activa al añadir.
- [x] Reordenar/eliminar sliders junto a scrolls custom.
- [x] `flutter analyze` sin problemas.

## Evidence
- `lib/l10n/app_en.arb` / `app_es.arb`: `addSlider`, `featuredSliderName`, `showBannerRow`, `showBannerRowHint`, `sliderAdded`, `sliderRemoved`; `flutter gen-l10n` regeneró los getters.
- `lib/features/settings/presentation/widgets/custom_skin_section.dart`: switch `showBannerRow` (+hint) sobre `draft.showNewReleasesBanner`; botón slider en cada grupo que añade `LayoutSection.featuredSlider()` y activa el banner para vista instantánea; `_GroupBlock` lista `custom` + `featuredSlider` con subir/bajar/eliminar; `_SliderTile` sin tap (no captura foco TV) con etiqueta traducida.
- Render sin cambios: `home_screen.dart`/`vod_screen.dart` ya pintan `featuredSlider` con `FeaturedSlider` dentro del `FocusTraversalGroup` existente (paridad TV); persistencia vía `LayoutSection` JSON ya existente.
- `flutter analyze` → `No issues found!`.

## Next
- Probar en la app con tema Custom: añadir slider en Inicio/VOD, ver el banner al instante, quitarlo, apagar el switch y comprobar que se oculta.
