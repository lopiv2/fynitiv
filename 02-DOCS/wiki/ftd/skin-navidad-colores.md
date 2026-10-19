# Colores de skin para Navidad

## Intent
Que el teñido estacional del skin se note claramente como Navidad (verde/rojo/oro) en lugar de
quedar casi igual que Halloween o apagado, sin alterar el comportamiento de Halloween ni del modo
normal, y sin cambiar el skin persistido del usuario.

## Scope
- In:
  - `SeasonalPalette` gana un multiplicador de intensidad (`strength`, por defecto 1.0) para que
    una temática pueda tener algo más de presencia con el mismo ajuste del usuario.
  - `tintSkinForSeason` aplica `intensity * palette.strength` (limitado a 0..1).
  - Nueva paleta de Navidad (fondo verde/rojo, acento oro, primario verde) con `strength` 1.5.
- Out:
  - Cambiar la paleta ni el comportamiento de Halloween (strength 1.0 → idéntico).
  - Cambiar la intensidad por defecto global ni el slider de Ajustes.
  - Teñir `secondary`/`sidebar` (fuera del alcance acordado: fondo, acento y primario).
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] `strength` en `SeasonalPalette` + uso en `tintSkinForSeason`; `flutter analyze`.
- [x] Paleta de Navidad ajustada con refuerzo moderado; `flutter analyze`.
- [x] Halloween y modo normal conservan `strength` 1.0 por defecto.

## Evidence
- `effectiveSkinProvider` ya tiñe el skin con `tintSkinForSeason(base, event, intensity)` para
  cualquier `SeasonalEvent`, y el override de debug alimenta `activeSeasonalEventProvider`.
- La paleta de Navidad previa (`backgroundTop #041E1A`, `backgroundBottom #7A0E12`, acento
  `#E53935`, primario `#1B8A4B`) mezclada al 35% sobre el skin por defecto (`#0B1030`/`#1A2568`,
  acento `#2B7FFF`, primario `#AA5CC3`) produce un fondo casi idéntico al de Halloween
  (`~#3C1D4A` vs `~#3C2349`) y un primario grisáceo (`~#786C99`), por eso Navidad no se percibía.
- `AppTheme.fromSkin` usa `skin.primary` como semilla del tema y `DashboardBackground` usa el
  skin efectivo, así que subir la fuerza del teñido se ve en tema y fondo.
- `SeasonalPalette.strength` ahora multiplica la intensidad de Ajustes y se limita a 0..1.
  Halloween y demás paletas omiten el argumento (1.0); Navidad usa 1.5 (35% del slider → 52.5%),
  con fondo verde bosque/rojo, acento oro y primario verde vivo.
- `flutter analyze` → `No issues found! (ran in 10.9s)`.
- Repositorio en rama `main`.

## Next
Revisar visualmente el resultado en varios skins (Jellyfin, Disney+, Prime) con el chip
**Navidad** + "Repetir" y ajustar `strength`/paleta si hace falta.
