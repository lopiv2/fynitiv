# Presentaciones de splash por estación

## Intent
Separar la presentación de la splash en un modelo reutilizable con una variante por estación,
de modo que la música y los visuales cambien según la estación activa (calendario o override de
debug), y que "Repetir presentación" reproduzca la presentación y el audio de la estación en
curso. Primera variante completa: Halloween.

## Scope
- In:
  - Modelo `SplashPresentation` (audio, fondo, colores de letras/tagline, glow, extrusión, tint
    y efectos decorativos como funciones puras del progreso 0..1).
  - Registro `splashPresentationFor(SeasonalEvent?)`: por defecto (sin estación), Halloween,
    Navidad; San Valentín y Pascua reutilizan la de por defecto hasta tener arte.
  - Refactor de `lib/router/splash_screen.dart` para renderizar desde la presentación y
    reaccionar a `activeSeasonalEventProvider` (relanza animación + audio al cambiar).
  - Presentación de Halloween: audio `halloween_splash_reveal.mp3`, paleta naranja/morado,
    viñeta morada, **fondo** con luna, niebla y la imagen `halloween_back` (que aparece tras el
    relámpago), relámpago con **flash** inmediato y **cuatro bandadas** de murciélagos (chevrones)
    cruzando la pantalla (`bat_fly.webp`).
  - Registrar los mp3 nuevos en `pubspec.yaml` y precargarlos en `main.dart`.
- Out:
  - Arte de fondo propio por estación (de momento se reutiliza `splash_back.png`).
  - Presentaciones completas de Navidad/San Valentín/Pascua (Navidad queda con audio + recoloreado).
  - Mover `splash_screen.dart` (se mantiene la ruta para no romper el router ni el test).
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] Modelo + registro de presentaciones; `flutter analyze`.
- [x] `splash_screen.dart` renderiza desde la presentación y reacciona al cambio de estación; `flutter analyze`.
- [x] Presentación de Halloween (audio + paleta + murciélagos) y Navidad (audio + recoloreado).
- [x] `pubspec.yaml` + `main.dart` con los audios nuevos.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- `lib/router/splash_screen.dart` es una presentación única hardcodeada: audio
  `audio/splash_reveal.mp3`, fondo `assets/images/backgrounds/splash_back.png`, degradado
  plateado→azul→morado, morph de iconos y flare; "Repetir presentación" (`_replay`) solo
  reinicia el clock y relanza el mismo audio.
- `activeSeasonalEventProvider` (de `core/seasonal/active_seasonal_event.dart`) ya devuelve la
  estación activa respetando el override de debug.
- Assets presentes en disco pero **no registrados** en `pubspec.yaml` (`assets/audio/`): 
  `halloween_splash_reveal.mp3`, `christmas_splash_reveal.mp3`; `main.dart` solo precarga
  `audio/splash_reveal.mp3`.
- `assets/images/seasonal/` ya está registrada como carpeta → `bat_fly.webp` disponible.
- Repositorio en rama `main`.
- `lib/features/splash/domain/splash_presentation.dart`: `SplashPresentation` (id, audio,
  fondo, `letterStops`, `taglineColors`, extrusión, glow, `backgroundTint`, `iconColor`,
  `iconShadows`, flare, `backgroundEffects` **detrás** del contenido y `effects` delante) +
  `SplashEffect` (función pura del progreso) + helpers `letterColor`, `letterGradient`,
  `extrusionColor`, `taglineColor`.
- `lib/features/splash/presentation/presentations/`: `default` (réplica exacta de la anterior),
  `halloween`, `christmas` y el registro `splashPresentationFor(SeasonalEvent?)`
  (San Valentín y Pascua → default).
- Halloween (`halloween_splash_presentation.dart`):
  - `backgroundEffects`: `halloweenBackEffect` (imagen `assets/images/seasonal/halloween_back.webp`,
    ya presente y en carpeta registrada → sin cambios en `pubspec.yaml`; aparece por fade justo
    tras el flash), `halloweenFogEffect` (3 bandas de niebla derivando) y `halloweenMoonEffect`
    (luna con halo y cráteres, leve deriva).
  - `effects`: `halloweenBatsEffect` (**4 bandadas** de 20/16/13/9 murciélagos repartidos en
    nube uniforme pero desigual —espiral de ángulo áureo con radio/ángulo irregulares y
    pseudo-aleatorio determinista por índice— con remolque, aleteo y tamaño/opacidad variables)
    y `halloweenLightningEffect` (rayo `CustomPaint` realista —canal principal
    con 16 desviaciones, 9 ramas con sub-ramas, grosor decreciente de raíz a punta y tres
    capas halo/brillo/núcleo, con geometría de semilla fija para que no parpadee— + flash de
    pantalla en el mismo instante; doble destello con subida rápida y
    caída exponencial en progreso 0.55).
  - Los `Image.asset` llevan `errorBuilder` para no romper si el asset no está disponible.
  - El icono del tagline (incluida la ∞ de `Icons.all_inclusive`) usa el naranja de la paleta
    (`iconColor`) y `iconShadows` oscuras: sobre la imagen clara `halloween_back` el blanco
    original desaparecía. `Icon` y `MorphIcon` aceptan `shadows`, aplicadas en `splash_screen.dart`.
- Navidad (`christmas_splash_presentation.dart`), a partir de `christmas_back.webp` (noche azul
  con pueblo iluminado) y `santa.webp` (trineo + renos, ambos en la carpeta registrada):
  - `backgroundEffects`: `christmasBackEffect` (`christmas_back` por fundido 8%→43%),
    `christmasVillageGlowEffect` (brillo cálido inferior con pulso leve),
    `christmasSantaEffect` (trineo cruzando de izquierda a derecha entre 12% y 82% con arco,
    cabeceo y desvanecido en extremos) y `christmasSnowEffect` (110 copos con deriva).
  - `effects`: `christmasForegroundSnowEffect` (12 copos grandes y tenues → profundidad).
  - Nieve dibujada con `CustomPainter` y `Random` de semilla fija (estable por frame).
  - Paleta adaptada a la noche azul: letras blanco→rojo→verde menta, tagline con oro, glow e
    icono dorados, extrusión azul/roja y sombras oscuras en el icono.
- `lib/router/splash_screen.dart`: lee `activeSeasonalEventProvider`, guarda `_presentation` y
  con `ref.listen` reinicia animación + audio al cambiar de estación; el cuerpo pasa a un
  `Stack` con fondo (asset + `backgroundTint`) y, dentro, las capas `backgroundEffects` (tras el
  tinte y detrás del contenido), el contenido y las capas `effects` delante. Se eliminaron las
  constantes de color/asset hardcodeadas (ahora son campos de la presentación).
- `pubspec.yaml`: registrados `halloween_splash_reveal.mp3` y `christmas_splash_reveal.mp3`;
  `main.dart` precarga los tres audios de splash.
- `flutter analyze` → `No issues found! (ran in 8.4s)`.

## Next
Probar la secuencia de Navidad (fundido de `christmas_back`, copos, brillo del pueblo y vuelo del
trineo) y ajustar tiempos/tamaño con el creador; después valorar fondo dedicado para San Valentín y
Pascua.
