# Frases variables y backdrop en los moods de Inicio

## Intent
Hacer más dinámicos los 8 botones de mood en Inicio: cada entrada muestra una frase localizada distinta por mood y un backdrop aleatorio de una película o serie de sus géneros, conservando el degradado y aplicando encima un tint semitransparente del color del mood.

## Scope
- In:
  - Añadir seis frases por mood en inglés y español mediante ARB y generar las localizaciones.
  - Volver a elegir frases y backdrops al entrar a Inicio, incluidas las transiciones de pestaña y el regreso desde detalles.
  - Cargar en paralelo un título aleatorio por mood y mostrar su backdrop, con degradado de color mientras llega.
  - Compartir la selección de imagen panorámica backdrop → thumb → primary con la tarjeta de biblioteca existente.
- Out:
  - Cambios al comportamiento de selección aleatoria al pulsar un mood.
  - Cambios a otros skins, a la configuración del diseño del Home o a la navegación de los botones.

## Checklist
- [x] Añadir y generar seis frases relacionadas por mood en EN/ES; `flutter gen-l10n` terminó correctamente y se comprobaron los getters generados para los 8 moods.
- [x] Seleccionar frases e imágenes de nuevo al entrar a Inicio; el código del listener de ruta/provider pasó `flutter analyze`.
- [x] Renderizar backdrop bajo tint translúcido manteniendo fallback de color y hover; `flutter analyze` pasó y se revisó el orden de capas en `_MoodButton`.
- [x] Reutilizar el helper de imagen panorámica en las tarjetas de biblioteca; `flutter analyze` pasó.
- [x] Actualizar esta evidencia con los resultados observados.

## Evidence
- Diagnóstico inicial: rama `main`, working tree limpio; Home usa `StatefulShellRoute.indexedStack`, la tarjeta mood emplea `AppHover` y `fetchRandomMoodItem` filtra por géneros.
- `lib/l10n/app_en.arb` y `app_es.arb`: 5 frases nuevas por mood; `flutter gen-l10n` generó los getters `moodAction2`…`moodAdventure6` para EN/ES.
- `mood_suggestion.dart`: `moodPhrases` reúne 6 opciones localizadas por mood; el grid elige una usando una semilla aleatoria renovada al volver a `/home`.
- `mood_providers.dart`: solicita candidatos aleatorios por mood en paralelo y prefiere uno de hasta 10 resultados con backdrop; `bestLandscapeImageUrl` usa backdrop → thumb → primary como respaldo.
- `mood_suggestions_grid.dart`: conserva el degradado como fallback, añade la imagen con fade y aplica el tint de color semitransparente; mantiene `AppHover` y la viñeta de legibilidad.
- `library_grid_card.dart` reutiliza `bestLandscapeImageUrl`.
- `flutter analyze` → `No issues found! (ran in 3.0s)`; `git diff --check` → sin salida (sin errores).
- No se ejecutaron tests ni se hizo render de la app.

## Next
- Probar visualmente en la app con un servidor Jellyfin: entrar y volver a Inicio, confirmar variación de frases/backdrops y revisar la intensidad del tint y la legibilidad en los 8 moods.
