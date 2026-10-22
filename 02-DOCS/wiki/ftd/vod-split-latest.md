# Novedades por split (fix fila vacía en Series)

## Intent
Que `newReleases` en pantallas divididas traiga novedades del tipo del split con query propia, en vez de filtrar el top-20 global (si son todo pelis, Series se quedaba sin fila).

## Scope
- In:
  - `vodSplitLatestProvider` family por `VodSplit` (`[movie]` / `[series]`, límite 20, mismos campos).
  - `VodScreen`: con split usa la family (sin post-filtro); sin split mantiene `vodLatestProvider`.
- Out:
  - No tocar banner, customs ni presets; sin ARB; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Family + uso en `VodScreen`; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `library_providers.dart`: `latestForTypesProvider` family (clave tipos) + `scrollTypesKey`/`typesKeyFor` compartidos (renombrado `bannerTypesKey` en sus 4 usos).
- `vod_screen.dart`: `latest` top-level = family con clave del split; `newReleases` por sección obedece al `types` de su scroll (`latestTypesFor` + `newReleasesItems`, estrechado al split; se omite si queda vacío), igual que `library`; `buildNewReleasesRow` acepta items.
- `flutter analyze` → `No issues found! (ran en 6.3s)`.

## Next
- Probar en Series de Prime la fila de novedades; recordar reaplicar el chip del preset tras editar código.
