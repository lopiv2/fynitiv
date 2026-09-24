# FAB sobre mini-player

## Intent
El `floatingActionButton` (toggle sidebar) en `home_shell` se superpone sobre el `MiniPlayerBar` porque `Scaffold` lo posiciona `endFloat` (16px del borde) mientras el mini ocupa `64*s` abajo. Elevar el FAB dinámicamente por encima del mini cuando hay música, manteniéndolo en `endFloat` sin mover su UX.

## Scope
- In: `lib/router/home_shell.dart` envolver el `switch(mode)` de `floatingActionButton` en `Consumer` que lee `miniPlayerScaleProvider` + `soloudMusicProvider`/`musicPlayerProvider` para calcular `barH = (64*s).clamp(64,120)` y `bottomPad = hasBar ? barH + 8 : 0` aplicado vía `Padding(bottom: bottomPad)`; FAB sigue `null` en `tv`.
- Out: mover FAB a header/sidebar, tocar `MiniPlayerBar` o `ui_constants`.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] FAB elevado dinámicamente sobre mini — `flutter analyze` sin issues
- [x] `flutter analyze` global sin issues

## Evidence
- `home_shell.dart:262` `Scaffold(body: Column([Expanded, MiniPlayerBar]), floatingActionButton: switch)` → FAB overlay sobre Column.
- `mini_player_bar.dart:86` `barHeight = 64*s` con `s` por plataforma; `soloudMusicProvider.hasItem && !completed` determina visibilidad.

## Next
Si el FAB queda muy alto en TV (no aplica, `null`), o con mini oculto deja hueco, ajustar `+8` a `+12` o usar `SafeArea`.
