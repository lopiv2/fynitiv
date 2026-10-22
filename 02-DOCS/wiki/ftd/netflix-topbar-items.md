# Items Libros, TV/Radio y Seerr en la topbar Netflix

## Intent
Completar el nav de la topbar Netflix con el orden: buscar, Home, Shows, Movies, Libros, TV/Radio, Juego Online, Seerr y Mi Netflix, cada uno con su acceso correspondiente.

## Scope
- In:
  - `TopBarNavItem`: nuevos `books` (rama 5 eReader), `liveTv` (rama 3) y `seerr` (`/seerr`); orden por defecto actualizado en `Skin.topBarNavItems` y fallback JSON.
  - `NetflixTopBar`: casos nuevos con etiqueta y estado activo (reutiliza ARB `eReader`, `liveTvRadio`, `seerr`; sin claves nuevas).
- Out:
  - No cambiar classic/isla ni otros presets; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Enum + orden por defecto; comprobar `flutter analyze`.
- [ ] Casos en `NetflixTopBar` con accesos; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `top_bar.dart`: `TopBarNavItem.books/liveTv/seerr` documentados con su acceso.
- `skin.dart`: orden por defecto `search, home, shows, movies, books, liveTv, games, seerr, myNetflix` (constructor + fallback JSON).
- `netflix_top_bar.dart`: casos nuevos — Libros → rama 5 (etiqueta ARB `books`: "Libros"/"Books"), TV/Radio → rama 3, Seerr → `/seerr` con activo por `loc`; lista de respaldo con el orden completo; sin más ARB nuevas (`liveTvRadio`, `seerr` reutilizadas).
- `flutter analyze` → `No issues found! (ran en 12.7s)`.

## Next
- Probar en app cada item del nav Netflix y su estado activo.
