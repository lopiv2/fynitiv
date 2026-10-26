# FTD — Etiqueta "Mi biblioteca" en topbar Netflix

## Intent

En el tema Netflix, la píldora de navegación `myNetflix` debe mostrar
"Mi biblioteca" (ES) / "My Library" (EN) en vez de "Mi/Mi Netflix".

## Scope

- Solo valores ARB de la clave existente `myNetflix`
  (`lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`) + regenerar con
  `flutter gen-l10n` + ajuste del comentario en `skin_enums.dart`.
- Sin renombrar la clave (solo se usa en `netflix_top_bar.dart:198`), sin
  cambios de navegación, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] Cambiar `myNetflix` a "Mi biblioteca" / "My Library" en ambos ARB.
- [x] Regenerar localizaciones (`flutter gen-l10n`).
- [x] Actualizar comentario en `skin_enums.dart`.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter gen-l10n` regeneró `app_localizations_es.dart:2674` → `'Mi biblioteca'`
  y `app_localizations_en.dart:2664` → `'My Library'`.
- `flutter analyze lib/l10n .../netflix_top_bar.dart .../skin_enums.dart` → No issues found.
- Único uso de `l10n.myNetflix` en `netflix_top_bar.dart:198` (píldora de la topbar Netflix).

## Next

- Comprobar visualmente la topbar del skin Netflix.
