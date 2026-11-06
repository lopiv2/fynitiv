# FTD: franchise-carga-progresiva — la pantalla de franquicia pinta antes de Seerr

## Intent
La pantalla de una franquicia se quedaba con el loader hasta terminar **todas**
las consultas de metadatos de Seerr de los títulos que faltan. Con sagas largas
(MCU, Alien, Star Wars) eso son muchas peticiones en paralelo y una sola lenta
retrasa toda la pantalla. Debe pintar el grid en cuanto se conoce la biblioteca
y completar las carátulas de los faltantes de forma progresiva.

## Scope
- In:
  - `lib/features/franchises/application/franchise_providers.dart`:
    - `franchiseEntriesProvider`: solo catálogo + índice Jellyfin + hidratación
      de títulos poseídos; deja de esperar a Seerr.
    - Nuevo `franchiseExternalProvider`: metadatos Seerr de los faltantes, en
      lotes con timeout, usado aparte por la pantalla.
    - Usar `ref.read` (no `ref.watch`) para las fichas puntuales de Seerr y
      evitar reejecuciones del provider.
  - `lib/features/franchises/presentation/franchise_screen.dart`: renderiza
    las entradas base y aplica los metadatos externos cuando llegan.
- Out: catálogo JSON, orden cronológico, numeración, hub y tarjetas.

## Checklist
- [x] FTD creado antes del cambio.
- [x] Separar entradas base de metadatos Seerr.
- [x] `franchiseExternalProvider` con concurrencia limitada y timeout.
- [x] Pantalla pinta sin esperar a Seerr y se actualiza al llegar.
- [x] `flutter analyze` limpio.

## Evidence
- `franchiseEntriesProvider` ya no consulta Seerr: solo catálogo, índice TMDB
  cacheado e hidratación de los títulos poseídos. Devuelve el grid en cuanto
  termina eso.
- `franchiseExternalProvider` (StreamProvider) pide los faltantes en lotes de 6
  con timeout de 8 s por ficha y emite el mapa parcial tras cada lote; la
  pantalla se reconstruye y completa las carátulas sin bloquear el grid.
- Las fichas puntuales se piden con `ref.read` en vez de `ref.watch`, para que
  la respuesta de una ficha no reejecute el provider completo.
- `flutter analyze` → `No issues found!`.

## Next
- Verificar en la app que el grid aparece antes que las carátulas de Seerr y que
  una saga larga (MCU/Alien) ya no deja el loader fijo. Sin `flutter build`.
- Si sigue habiendo espera antes del grid, el siguiente cuello es la consulta
  global del índice TMDB (todas las películas/series con `mediaSources`);
  entonces conviene optimizar ese índice o cachear su resultado en disco.
