# Series: hover en biblioteca y episodios en detalle (Prime)

## Intent
- En el grid de biblioteca, las series muestran el botón "Ver ahora" en el hover,
  y **tanto la tarjeta como "Ver ahora" abren el detalle** (no reproducen).
- En el detalle (Prime), las series con episodios deben mostrar los apartados de
  temporadas/capítulos (estilo pestañas, como el detalle de serie de Disney);
  sin episodios, no debe aparecer "Ver ahora".

## Scope
- In:
  - `library_view_screen.dart`: series → `onTap`/`onPlay` (por `onTap`) detalle;
    `showPlayIcon` visible (según scroll).
  - `item_detail_screen.dart`: `isSeriesDetail` incluye Prime y Disney; el cuerpo
    de serie oculta "Ver ahora" y las pestañas Episodios/Extras cuando no hay
    episodios (queda Sugerencias/Detalles).
- Out: no se cambia `hover_play_card.dart` ni las tarjetas (se probó separar
  "Ver ahora" de la tarjeta y se revirtió: ambos van al detalle para series).

## Checklist
- [x] Series en biblioteca: "Ver ahora" visible; tarjeta → detalle; "Ver ahora" → reproduce.
- [x] Detalle Prime: apartados de episodios si hay episodios.
- [x] Detalle: "Ver ahora" oculto si no hay episodios.
- [x] `flutter analyze` limpio.

## Evidence
- `library_view_screen.dart`: para `series`, `onTap` → `/home/details` (y por
  tanto también el botón "Ver ahora", que usa `onTap`), `showPlayIcon` visible.
  `hover_play_card.dart` y las tarjetas quedan igual que antes (sin cambios).
- `item_detail_screen.dart`: `isSeriesDetail = series && (disney_plus ||
  amazon_prime)` → `_DisneySeriesBody`; dentro, `hasEpisodes` controla el botón
  VER y las pestañas Episodios/Extras (por defecto Sugerencias si no hay).
- `flutter analyze` → `No issues found!`.

## Temporadas también al abrir desde Inicio (episodios)
- Causa: al abrir el detalle desde Inicio, muchas filas pasan un **episodio**
  (Continuar viendo / A continuación), no la serie; al no ser `type == series`,
  no se usaba el cuerpo de serie y faltaban las temporadas.
- Fix: `item_detail_screen.dart` resuelve la serie del item abierto
  (`seriesId`) cuando es episodio/temporada, y usa ese item para el cuerpo y sus
  datos (`bodyItem`). `isSeriesDetail` se basa en la serie resuelta, así que
  **todas** las vistas de detalle de serie en Prime muestran temporadas y su
  desplegable. `_streamLabels` pasa a recibir el item fuente.
- `flutter analyze` → `No issues found!`.

## Next
- Comprobar en Prime: detalle de serie desde Inicio (episodio) y desde la
  biblioteca (serie) muestran las temporadas igual.
- Pendiente/ajustable: las pestañas del cuerpo son las de Disney
  (Episodios/Sugerencias/Extras/Detalles); si se quieren las de la referencia
  (Episodios/Relacionado/Detalles) habría que parametrizar las etiquetas.
