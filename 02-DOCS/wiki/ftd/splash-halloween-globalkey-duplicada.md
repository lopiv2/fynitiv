# FTD — Claves duplicadas en el splash de Halloween

## Intent

Resolver la excepción `Multiple widgets used the same GlobalKey` introducida al anclar las gotas al título: el logo normal y la copia del `ShaderMask` del brillo se construyen a la vez y no pueden compartir las mismas claves.

## Scope

- `lib/router/splash_screen.dart`: permitir construir `_buildLetters` sin claves para la copia del brillo; mantener las claves solo en el título principal que usa `_BloodRainPainter`.
- No cambiar el recorrido/animación de las gotas ni las personalizaciones estacionales del usuario.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] La copia del brillo no reutiliza claves del título principal.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- `_buildLetters(attachRainKeys: false)` crea la copia del brillo sin las claves reservadas para medir el título principal; el pintor de gotas conserva esas claves.

## Next

- Probar el splash de Halloween y confirmar que no aparece `Multiple widgets used the same GlobalKey` y que las gotas siguen cayendo hasta abajo.
