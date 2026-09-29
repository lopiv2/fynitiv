# Intent
Recuperar el autoplay del OST al entrar al detalle del juego. La cadena de datos (`ostTracksProvider`) y `_maybeStartOst` están intactas en el diff; se instrumenta con traza `[Ost]` para ver dónde se corta (pistas vacías, mute, sesión, `playUrl`).

# Scope
- `debugPrint [Ost]` en `_maybeStartOst` (nº pistas, mute), `playQueue` (sesión, mute) y `_playCurrent` (sesión, éxito/error de `playUrl`, hoy silenciado con `catch (_)`).
- Sin cambios de lógica todavía; solo diagnóstico. Sin `flutter build`; `flutter analyze`.

# Checklist
- [x] Traza `[Ost]` en los 3 puntos
- [x] `flutter analyze` limpio
- [x] Log del usuario: `[Ost] _playCurrent ABORT session=15 current=15 empty=false muted=true` → causa: mute activo (persistido en sesión), no regresión
- [x] Endurecido `SoloudInitializer.ensureInitialized` (reutiliza motor nativo si el segundo `init()` falla tras hot restart)

# Evidence
- `flutter analyze --no-pub`: `No issues found!`.
- El mute por defecto es `false` (`GameBgMutedController.build`), pero persiste en `sessionStorage`: el usuario lo silenció en algún momento (switch del header, botón del detalle o ajustes) y el OST lo respeta por diseño — ni autoplay ni manual suenan con `muted=true`.

# Evidence
- (pendiente) `flutter analyze` + log del usuario.

# Next
- Según el log: arreglar la causa (sesión/mute/playUrl) y retirar o mantener la traza mínima.
