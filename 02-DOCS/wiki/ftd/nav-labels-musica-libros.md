# Etiquetas Música y Libros

## Intent
Mostrar "Música" en vez de "Music Player" y "Libros" en vez de "E-Reader", con traducción, en todos los skins.

## Scope
- In:
  - ARB `music` → "Música"/"Music", `eReader` → "Libros"/"Books" (aplica a sidebars, topbars y pantallas al usar las mismas claves).
  - Netflix vuelve a `l10n.eReader`; eliminada la clave duplicada `books`.
- Out:
  - Nada más; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [x] ARB ES/EN + `flutter gen-l10n`; comprobar getters.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `app_es.arb`/`app_en.arb`: `music` y `eReader` actualizados; clave `books` eliminada; Netflix usa `eReader`.
- `flutter gen-l10n` regeneró localizaciones.
- `flutter analyze` → `No issues found! (ran en 10.1s)`.

## Next
- Probar en app que las etiquetas se leen bien en barras laterales y superiores.
