# ContinueWatching respeta `cardType` (póster/backdrop)

## Intent

Que la fila "Continuar viendo" use el formato indicado en su `HomeScroll`
(`cardType: poster`/`backdrop`) y no se quede siempre en backdrop por el
`imageSource` heredado del preset.

## Cause

`isBackdropForContinue`/`isBackForContinue` decidían solo por `imageSource`:
- `primary` → póster
- `thumb`/`backdrop` → backdrop
- `null` → global del skin

Ignoraban `cardType`, así que un scroll con `cardType: poster` e
`imageSource: thumb` seguía pintándose como backdrop.

## Scope

- `lib/features/library/presentation/home_screen.dart`: el helper respeta
  `cardType` antes que `imageSource`.
- `lib/features/vod/presentation/vod_screen.dart`: ídem.
- En la fila de continuar viendo, si el formato es póster se usa la imagen
  `primary` (no el `thumb` heredado) para que la tarjeta no salga recortada.

## Checklist

- [x] `cardType` manda sobre `imageSource` en Continuar viendo (Inicio y VOD)
- [x] Póster con imagen primaria
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 11.1s)`

## Next

Si quieres el mismo criterio en "A continuación"/"Novedades", sus pre-pases de
spacing todavía usan el backdrop global; el formato de tarjeta del render ya
respeta `cardType`.
