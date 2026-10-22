# Quitar el item VOD cuando hay split

## Intent
Eliminar la parte de VOD de la navegación cuando el skin divide VOD en Películas y Series: el item VOD se sustituye por Películas/Series en su misma posición.

## Scope
- In:
  - `sidebar.dart`: `vodItems` (split ? Películas/Series : VOD) usado en vertical (Disney y resto) y topbar classic/prime; `/vod` sigue existiendo para skins sin split.
- Out:
  - No tocar rutas, `VodScreen`, presets ni Netflix; sin ARB nuevas; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Item VOD sustituido por split en los tres flujos; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `sidebar.dart`: `vodItems` (split ? Películas/Series : VOD) en el sitio de VOD en vertical (Disney y resto) y topbar classic/prime (Prime sigue excluyendo Buscar del flujo); `/vod` se conserva para skins sin split; ramas sin cambios.
- `flutter analyze` → `No issues found! (ran en 6.6s)`.

## Next
- Probar en app con Disney/Prime (sin item VOD) y con un skin sin split (VOD intacto).
