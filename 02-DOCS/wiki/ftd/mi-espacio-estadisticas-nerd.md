# FTD — Mi espacio y Estadísticas de Nerd

## Intent

Añadir al menú del avatar una opción **Mi espacio** que abra una pantalla propia del usuario, con layout adaptable (TV / móvil / escritorio) y una sección oculta de **Estadísticas de Nerd**: películas vistas, episodios, horas de vídeo y música, canciones, libros, juegos, plataformas, un "nivel de nerd" y logros desbloqueados a modo de easter egg. Todo el texto nuevo pasa por ARB (inglés y español).

## Scope

- `lib/features/profile/domain/nerd_stats.dart`: modelo de estadísticas, cálculo de puntos/nivel y logros.
- `lib/features/profile/application/nerd_stats_provider.dart`: recuentos reales vía `jellyfin_dart` (items reproducidos + suma de `runTimeTicks`) y ROMM (juegos y plataformas), tolerante a fallos.
- `lib/features/profile/presentation/my_space_screen.dart`: pantalla adaptable con loader, error+reintento, tarjetas, nivel y logros.
- `user_avatar_menu.dart` y menú del `floating_island_bar.dart`: opción «Mi espacio» (helper compartido `openMySpace`).
- `lib/l10n/app_en.arb` y `app_es.arb`: claves nuevas; regeneradas con `flutter gen-l10n`.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Opción «Mi espacio» en el menú del avatar (y en la isla flotante).
- [x] Pantalla adaptable: reutiliza `metricsFor` (ancho + `PlatformMode`) y escala extra en TV.
- [x] Estadísticas reales con `AppLoader` y error recuperable.
- [x] Nivel de nerd + logros (easter egg).
- [x] Cadenas ARB en inglés y español, generadas.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter gen-l10n` → genera claves nuevas en `app_localizations*.dart` (`mySpace`, `nerdStatsTitle`, `achMarathon`, …).
- `flutter analyze` (proyecto completo) → `No issues found! (ran in 10.8s)`.
- `nerdStatsProvider`: 5 consultas `getItems(isPlayed: true)` (películas, episodios, series, audio y libros) con `enableTotalRecordCount`; suma minutos con `runTimeTicks / 600.000.000`. ROMM: `getGames(limit: 1)` para total y `lastPlayed: true` para jugados, más nº de plataformas. Cada bloque en `try/catch` para degradar a ceros.
- `MySpaceScreen`: `metricsFor(width, height, mode)` da tipografías/espaciados; columnas de tarjetas 2/3/4/5 según ancho y logros 1/2/3. `tvScale` agranda paddings y avatar.
- Puntos de nerd = 20·películas + 5·episodios + 10·series + 2·canciones + 100·libros + 50·juegos jugados + minutos de vídeo + ½·minutos de música. Niveles en 0/500/2.500/10.000/35.000.
- 9 logros: maratoniano, cinéfilo, seriófilo, ratón de biblioteca, melómano, retro gamer, coleccionista, club de los 100 y aprendiz de todo; los bloqueados muestran su condición.

## Next

- Verificar visualmente en móvil, escritorio y TV (o `debugDevice`) que el layout escala y que el menú del avatar abre «Mi espacio».
- Evolución posterior: 30 niveles con XP por actividad (ver `mi-espacio-30-niveles-xp.md`).
