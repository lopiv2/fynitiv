# E-Reader — animación de pasar hoja (curl realista) + preferencia

## Intent
Que el lector paginado (EPUB y cómics CBZ) pase de página con un efecto realista de
hoja de libro curvándose, y permitir activarlo/desactivarlo desde Preferencias con la
elección persistida entre reinicios.

## Scope
- In:
  - Dependencia `real_page_flip` (curl 3D físico, single y doble página, Windows/Android,
    MIT) integrada en el `SpreadReader` genérico compartido por EPUB y CBZ.
  - Preferencia persistente `readerPageFlipEnabledProvider` (por defecto activada).
  - Interruptor en Ajustes > Preferencias.
  - Cadenas ARB EN+ES.
- Out:
  - Visor PDF (pdfrx trae su propio visor; no se toca).
  - Sonido/haptics propios del paquete (se dejan desactivados).
  - Persistencia de la posición de lectura.

## Checklist
- [x] FTD antes del primer cambio (este documento)
- [x] `flutter pub add real_page_flip`
- [x] `ReaderPageFlipNotifier` persistente (`jellyfin.reader_page_flip_enabled`, def. true)
- [x] `SpreadReader` usa `PageFlipWidget` cuando está activado; `PageView` actual cuando no
- [x] Interruptor en `_PreferencesPanel`
- [x] ARB `readerPageFlip` / `readerPageFlipHint` (EN+ES) + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `flutter --version` → Flutter 3.50.0-0.1.pre / Dart 3.14.0 (cumple el requisito 3.44+
  de `real_page_flip` 3.1.2).
- `flutter pub add real_page_flip` → `+ real_page_flip 3.1.2`, sin conflictos de versión.
- API verificada en el paquete instalado: `PageFlipWidget(itemBuilder, itemCount,
  controller, initialIndex, spreadMode, onPageChanged, config)`,
  `PageFlipSpreadMode.single|doubleSpread`, `PageFlipController.nextPage/previousPage`.
- Detalle clave: `PageFlipConfig.skipTapAnimation` por defecto es `true` y también hace
  **instantáneos** los giros programáticos (`nextPage`/`previousPage`); se fuerza a
  `false` para que flechas/D-pad animen el curl. `enableSound`/`enableHaptics` a `false`.
- `SpreadReader` pasa a `ConsumerStatefulWidget`, observa `readerPageFlipEnabledProvider`
  y conserva flechas, contador, foco y `CallbackShortcuts` (D-pad). En modo curl mantiene
  su propia `PageFlipController`; al desactivar vuelve a un `PageView` (con su
  `PageController` reciclado a la página actual).
- `flutter gen-l10n` OK; getters `readerPageFlip`/`readerPageFlipHint` presentes en EN y ES.
- `flutter analyze` → `No issues found!`.

## Next
Probar en la app con un EPUB y un CBZ reales: swipe, flechas, D-pad, doble página y que el
ajuste persiste al reiniciar. Vigilar el gesto del `InteractiveViewer` del CBZ frente al
swipe del curl.
