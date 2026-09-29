# Intent
Añadir al shuffle de música de fondo de juego online las 3 canciones nuevas metidas en `assets/audio/themes/`: `Ethereal Madness.mp3`, `Hidden Bonus Room.mp3` y `Triumph at the Final Gate.mp3`.

# Scope
- In: `lib/core/constants/theme_music.dart` (`kThemeTracks` pasa de 7 a 10, en orden alfabético como el resto). Sin cambios en `pubspec.yaml` (el directorio `assets/audio/themes/` ya está declarado) ni en el player (lee la lista para el shuffle).
- Out: cambios de volumen/orden del shuffle, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] 3 temas añadidos a `kThemeTracks`
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (theme_music + game_bg_player) → "No issues found!".

# Evidence
- Disco: `assets/audio/themes/` tiene 10 `.mp3`; la lista solo 7. Faltan: `Ethereal Madness.mp3`, `Hidden Bonus Room.mp3`, `Triumph at the Final Gate.mp3`.
- `pubspec.yaml:140` declara `- assets/audio/themes/` (directorio: los nuevos entran solos al bundle).
- `game_bg_player.dart:68` hace shuffle de `kThemeTracks` al entrar: con añadirlas basta.

# Next
Entrar en `/games` y comprobar que las nuevas suenan en la rotación.
