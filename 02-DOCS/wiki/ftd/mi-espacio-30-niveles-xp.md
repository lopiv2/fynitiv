# FTD — 30 niveles y XP por actividad

## Intent

Ampliar «Mi espacio» de 5 a **30 niveles** y cambiar los puntos de nerd por **XP explícita por actividad**: cada película, episodio, serie, canción, libro, juego y hora (de vídeo o música) aporta una cantidad fija de XP. Mostrar además un desglose con las tasas para que el número tenga sentido.

## Scope

- `lib/features/profile/domain/nerd_stats.dart`: constantes de XP por actividad, `xp` total, 30 umbrales de nivel, tier (título) por rango y progreso.
- `lib/features/profile/presentation/my_space_screen.dart`: nivel/tier (`N/30`), XP, siguiente nivel y bloque «Cómo se gana XP» con chips.
- `app_en.arb` / `app_es.arb`: `xpRulesTitle`, `xpRule` y etiquetas de cada tasa; `nerdPoints`/`nerdNextLevel` reformuladas a XP. Regenerado con `flutter gen-l10n`.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] 30 niveles con umbrales progresivos.
- [x] XP por película, episodio, serie, canción, libro, juego y horas.
- [x] Desglose visible en la UI (traducido).
- [x] `flutter analyze` limpio.

## Evidence

- Tasas: película 50, episodio 10, serie 25, canción 2, libro 150, juego jugado 75, juego en biblioteca 2, hora de vídeo 20, hora de música 5.
- Umbrales `120·(L-1)² + 80·(L-1)`: nivel 1 = 0 XP, nivel 2 = 200, nivel 10 = 10.440, nivel 20 = 44.840, nivel 30 = 103.240.
- Tiers por rango (1–5 Curioso, 6–10 Entusiasta, 11–15 Maestro del maratón, 16–22 Archivista, 23–30 Leyenda viva).
- Comprobación de la fórmula: 100 películas + 500 episodios + 20 series + 1.000 canciones + 5 libros + 20 juegos jugados + 200 en biblioteca + 500 h vídeo + 100 h música = 25.650 XP → nivel 15.
- `flutter gen-l10n` → claves generadas (`xpRulesTitle`, `xpRule(xp, label)`, `xpLabel*`).
- `flutter analyze` (proyecto completo) → `No issues found! (ran in 10.4s)`.

## Next

- Verificar visualmente el nivel/tier, la barra y los chips de XP en móvil, escritorio y TV.
