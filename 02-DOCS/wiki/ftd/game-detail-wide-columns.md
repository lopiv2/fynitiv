# Layout detalle juego: dos filas en wide

## Intent
La rama wide del detalle mezclaba carátula+player en una columna y datos+descripción+temas en otra, lo que impedía dar más ancho al reproductor OST. Reestructurar a dos filas (superior: carátula | datos+descripción; inferior: player | lista) con ancho fijo a la izquierda y `Expanded` a la derecha, fácil de ajustar a futuro.

## Scope
- In: solo rama wide (≥760px) de `GameDetailScreen`; izquierda fija 300, carátula 260×366, player en `compact: false`; derecha `Expanded` intacta por dentro.
- Out: rama compacta (<760px), lógica OST/datos, otros formatos.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Filas reestructuradas sin cambiar widgets internos — `flutter analyze` sin issues
- [ ] Sin regresión visual en compacta (no tocada) — pendiente revisión del usuario en runtime

## Evidence
- `flutter analyze lib/features/games/presentation/game_detail_screen.dart` → "No issues found!"

## Next
`flutter analyze` y prueba visual del usuario.
