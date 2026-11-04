# FTD — Origen de las gotas en la tinta de Halloween

## Intent

Corregir el punto de nacimiento de las gotas: ahora se calcula desde la caja exterior de `_LetterTile`, que incluye espacio debajo del glifo y hace que las gotas parezcan salir de la extrusión/sombra. Anclarlas al baseline del `Text` frontal (fin de la tinta de las letras mayúsculas).

## Scope

- `lib/router/splash_screen.dart`: mover las GlobalKeys de `_LetterTile` al `Text` frontal; medir su baseline con `RenderBox.getDistanceToBaseline` y usarlo como origen vertical.
- La copia del logo usada por el brillo sigue sin claves; conservar variación y caída hasta el suelo.
- No tocar personalizaciones manuales, sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Las gotas nacen en el borde de la tinta, no en la sombra/extrusión.
- [x] La copia del brillo no duplica claves.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- Las claves ahora apuntan al `Text` frontal; el pintor calcula el origen vertical con `RenderBox.getDistanceToBaseline(TextBaseline.alphabetic)`, en vez de usar la caja exterior de `_LetterTile`.

## Next

- Verificar visualmente con override `halloween` que cada gota sale de la base visible de la letra (no de su sombra) y cae hasta abajo.
