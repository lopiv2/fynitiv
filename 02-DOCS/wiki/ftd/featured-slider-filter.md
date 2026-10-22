# Slider destacado filtrable por tipo + fix series en Prime

## Intent
Que el `featuredSlider` pueda filtrar si muestra películas, series, ambas o música (vía `scroll.types` de la sección), y arreglar que en Series de Prime no aparece: el provider único (10 últimas entre pelis+series) dejaba a la pantalla de series sin items.

## Scope
- In:
  - `bannerItemsForProvider` family (clave = tipos ordenados) con query por `includeItemTypes`; helper `bannerTypesKey(scroll)` (vacío → pelis+series); eliminar `latestBannerItemsProvider`/`vodLatestBannerProvider` tras migrar sus 2 usos.
  - Home y VOD: slider por sección con su clave; sin scroll → defecto (pelis+series), y en split VOD sin scroll → el tipo del split (por eso Series de Prime ya muestra series).
  - `FeaturedSlider`: álbumes (`musicAlbum`) navegan a `/music/album/:id` en detalles, play y tap (el trailer ya está limitado a peli/serie).
- Out:
  - No cambiar presets (el slider bare se adapta solo) ni el editor custom (solo añade/elimina sliders); sin ARB nuevas; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Family + helper, migar Home/VOD, borrar providers viejos; comprobar `flutter analyze`.
- [ ] Navegación de álbumes en el slider; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `library_providers.dart`: `bannerItemsForProvider` family (clave tipos ordenados; vacía → pelis+series) + helper `bannerTypesKey(scroll)`; eliminados `latestBannerItemsProvider`/`vodLatestBannerProvider` (sus 2 usos migrados).
- `home_screen.dart`/`vod_screen.dart`: slider por sección con su clave; `buildFeaturedSlider(items?)` opcional; en VOD sin scroll en split → clave del split (por eso Series de Prime ya muestra series con query propia en vez de competir en el top-10 global).
- `featured_slider.dart`: álbumes navegan a `/music/album/:id` en detalles, play y tap/teclado (el trailer ya estaba limitado a peli/serie).
- Sin cambios de presets (el slider bare se adapta solo) ni ARB.
- `flutter analyze` → `No issues found! (ran en 10.2s)`.

## Next
- Probar en app: Series de Prime con slider de series; slider de música en un custom con tipos álbum.
