# FTD — Colecciones on-the-fly en libros (metadatos locales)

## Intent

Una única fila "Colecciones" en `EReaderScreen` donde cada elemento ES una
colección (agrupadas en cliente por metadatos locales + embebidos OPF/ComicInfo,
sin colecciones manuales ni APIs externas). Pulsar una colección o "Ver más"
abre la pantalla de colecciones como las bibliotecas: buscador, orden,
paginado y detalle con sus libros.

## Scope

- `lib/features/ereader/application/ereader_providers.dart`: modelo
  `EReaderCollection` + `eReaderCollectionsProvider` (ya hechos).
- NUEVO `widgets/collection_card.dart` (genérica, con `AppHover`): portada del
  primer libro + título + nº de títulos (`libraryCountTitles`, reutilizada).
- NUEVO `widgets/collections_row.dart`: scroll horizontal único + tarjeta
  final `seeMore` (reutilizada) → `/ereader/collections`.
- NUEVO `collections_screen.dart`: como las bibliotecas (`LibraryPageHeader`,
  buscador `search`, orden `sortAZ/sortZA`, flechas `pageOf`, grid, `noResults`).
- NUEVO `collection_detail_screen.dart`: grid de libros con `PosterCard`.
- `ereader_screen.dart`: sustituye las N filas por la única `CollectionsRow`.
- `app_router.dart`: rutas `collections` + `collections/detail` (vía `extra`).
- Solo ARB ya existentes; sin claves nuevas, sin tocar `PrimeCardBadge`,
  todo sobre `main`.

## Checklist

- [x] Provider de colecciones con agrupado Serie → Autor → Género.
- [x] Sección en `EReaderScreen` con `ContentRow` por colección.
- [x] ARB `bookCollections` ES+EN + `gen-l10n`.
- [x] `flutter analyze` limpio.
- [x] FIX: llamada propia con `people` + fallback autor por `PersonKind.author`
  + logs de diagnóstico (las páginas reutilizadas no traían `people`).
- [x] Metadatos embebidos: serie Calibre en OPF + `ComicInfo.xml` (CBZ/CB7/CBT/CBR)
  para los sueltos, con caché persistente y topes.
- [x] Una sola `CollectionsRow` + `CollectionCard` genérica.
- [x] `CollectionsScreen` (buscador, orden, paginado) + `CollectionDetailScreen`.
- [x] Rutas en `app_router.dart`; `EReaderScreen` usa la fila única.
- [x] `flutter analyze` limpio (final).
- [x] REUSE: fila sobre `ContentRow` (patrón `SeerrContentRow`: DTOs sintéticos
  + `imageUrlFor` + `cornerBadgeFor` + `onSeeMore`); grid con `PosterCard`;
  eliminar `CollectionCard`/`CollectionsRow` propios.

## Evidence

- `eReaderCollectionsProvider` (`ereader_providers.dart`): Serie ≥2 (A-Z) →
  Autor ≥2 (por nº) → Género ≥3 (por nº); cada libro en una sola colección;
  tope 5000 libros.
- `EReaderScreen`: sección `l10n.bookCollections` con un `ContentRow` por
  colección entre "Recién añadidos" y "Todos los libros".
- `flutter gen-l10n` generó `bookCollections` (ES `Colecciones`, EN
  `Collections`); `dart format` + `flutter analyze lib/features/ereader lib/l10n`
  → No issues found.
- FIX no-se-veían: el provider reutilizaba las páginas del grid, que no piden
  `ItemFields.people`; ahora hace una llamada propia con `people` y el autor
  cae a `people` tipo/rol autor. Además registra
  `[ereader] collections: N libros -> M filas (...)` y
  `[ereader] collections failed: ...` en consola para diagnosticar
  (p. ej. biblioteca sin serie/autor/género → 0 filas).
- Metadatos embebidos para los sueltos (sin serie ni autor del servidor):
  serie Calibre (`calibre:series`) + creadores del OPF en EPUB
  (`epub_metadata.dart`), y `Series`/`Writer`/`Genre` de `ComicInfo.xml` en
  CBZ/CB7/CBT (ZIP) y CBR (RAR vía `another_rar` con temporal que se borra).
  PDF y resto se omiten. Solo faltantes, en secuencia, tope 80 ficheros por
  ejecución, con caché persistente en `SharedPreferences`
  (`ereader.embeddedMeta.v1`, incluye negativos) y log
  `[ereader] embedded meta: N ficheros leídos`.
- Fila única: `CollectionsRow` (scroll horizontal de `CollectionCard` con
  `AppHover` + tarjeta final `seeMore`) sustituye las N filas en
  `EReaderScreen`; cada tarjeta abre `/ereader/collections/detail` y "Ver más"
  abre `/ereader/collections` (rutas nuevas en `app_router.dart`, objeto por
  `extra`).
- `CollectionsScreen` como las bibliotecas: `LibraryPageHeader`, buscador
  (`search`), orden A-Z/por nº (`sortAZ/sortZA` con `AppHoverButton.text`),
  flechas (`pageOf`), grid y `noResults` — todo ARB reutilizado, sin claves
  nuevas. `CollectionDetailScreen`: grid de `PosterCard` → detalle.
- `flutter analyze lib/features/ereader lib/router/app_router.dart` →
  No issues found.
- REUSE (sin reinventar): la fila es `CollectionsContentRow` sobre el
  `ContentRow` de siempre (patrón `SeerrContentRow`): DTOs sintéticos
  (`collection:$index` → colección), portada por `imageUrlFor`, pastilla con
  nº de títulos por `cornerBadgeFor`, "Ver más" por `onSeeMore`, botón del
  hover `details`; tamaños del skin activo. Grid de `CollectionsScreen` y
  detalle con `PosterCard` estándar. Eliminados `CollectionCard` y
  `CollectionsRow` propios.

## Next

- Enriquecimiento opcional con APIs sin key (Open Library / AniList /
  Gutendex) para los sueltos.
