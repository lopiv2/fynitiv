# Intent
Corregir el icono de play del hover en la vista de detalle: en Prime debe verse círculo blanco con play gris (`HoverPlayGlyphStyle.prime`), pero se ve al revés (círculo oscuro con play blanco). Reutilizar `HoverPlayGlyph` y eliminar los `_HoverPlayIcon` duplicados.

# Scope
- `lib/features/library/presentation/item_detail_screen.dart`: `_EpisodeHoverThumb` usa `HoverPlayGlyph` (`prime` si `prime=true`, `outline` si no); se borra `_HoverPlayIcon` local.
- `lib/features/ereader/presentation/book_detail_screen.dart`: mismo cambio (sin flag prime → `outline`, preserva el visual actual oscuro); se borra `_HoverPlayIcon` local.
- Sin tocar `PrimeCardBadge`; sin ARB nuevas.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] `_EpisodeHoverThumb` (item) usa `HoverPlayGlyph` según `prime`
- [x] `_EpisodeHoverThumb` (book) usa `HoverPlayGlyph`
- [x] `_HoverPlayIcon` duplicados eliminados
- [x] `flutter analyze` limpio

# Evidence
- Causa: `_HoverPlayIcon` local (oscuro + play blanco, estilo `outline`) se mostraba siempre, incluso con skin Prime; el comentario pedía círculo blanco como el overlay de filas. En Prime lo correcto es `HoverPlayGlyphStyle.prime` (blanco + gris).
- `flutter analyze` (4 ficheros): `No issues found!`.
- Sin `flutter build` (norma del proyecto); sin tests (no pedidos).

# Next
- Revisión visual del hover de capítulo en detalle de serie con skin Prime (blanco + gris) y en otro skin (oscuro + blanco).
