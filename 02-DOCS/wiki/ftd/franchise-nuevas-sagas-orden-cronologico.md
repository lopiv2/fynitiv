# FTD: franchise-nuevas-sagas-orden-cronologico — nuevas franquicias + orden historia/estreno

## Intent
Añadir las franquicias cuyas imágenes ya están en `assets/images/franchises/` pero
todavía no tienen entrada en el catálogo (`alien`, `backtothefuture`,
`ghostbusters`, `indianajones`, `jurassicpark`, `matrix`, `meninblack`,
`terminator`, `transformers`) y ofrecer en la pantalla de cada franquicia dos
órdenes: **estreno** y **cronológico/historia**, para poder seguir sagas como
Star Wars, Alien, Indiana Jones o Transformers en el orden narrativo.

Segunda iteración: recordar el orden elegido entre reinicios y numerar los
pósters (`1, 2, 3…`) cuando se está en modo cronológico, para que la secuencia
se lea de un vistazo.

Tercera iteración: el número va sobre un triángulo de esquina como el de la
referencia, y el `storyOrder` de Marvel sigue el orden cronológico de
DigitalSpy (solo películas).

Cuarta iteración: se añaden las 29 series del cronológico de DigitalSpy más
los 3 especiales como película (`Werewolf by Night`, Especial de las Fiestas
y `One Last Kill`): la franquicia `mcu` pasa de 39 a 71 entradas.

## Scope
- In:
  - `assets/data/franchises.json`: 9 bloques nuevos (items en orden de estreno
    con `storyOrder`) y `storyOrder` en las franquicias existentes.
  - `lib/features/franchises/domain/curated_franchise.dart`: campo `storyOrder`
    y clave de ordenación (`sortKey`).
  - `lib/features/franchises/application/franchise_providers.dart`: estado del
    orden (Notifier) persistido en `SharedPreferences` y helper
    `sortedFranchiseEntries`.
  - `lib/features/franchises/presentation/franchise_screen.dart`: chips
    "Orden de estreno" / "Orden cronológico" y numeración de pósters en modo
    cronológico.
  - `lib/l10n/app_es.arb` y `app_en.arb`: cadenas nuevas (generadas con
    `flutter gen-l10n`).
- Out: hub de franquicias, tarjetas, rutas, reproducción y posters.

## Checklist
- [x] FTD creado antes del cambio.
- [x] 9 bloques nuevos en `franchises.json` con `posterAsset` de las imágenes
      nuevas y `storyOrder` en cada item.
- [x] `storyOrder` en las 7 franquicias existentes.
- [x] Campo `storyOrder` + ordenación en el dominio.
- [x] Chips de orden conectados y con foco TV.
- [x] ARB es/en generados.
- [x] JSON válido y `flutter analyze` limpio.
- [x] Persistir el orden elegido en `SharedPreferences`.
- [x] Numerar los pósters en orden cronológico (incluidos los faltantes).
- [x] Badge triangular con número según referencia.
- [x] `storyOrder` de `mcu` según DigitalSpy (cronológico, solo películas).
- [x] Series de `mcu` añadidas (29 series tv + 3 especiales como película).

## Evidence
- `franchises.json` validado con script: 16 franquicias, `storyOrder` contiguo
  (1..N) y sin TMDB duplicados en cada bloque.
  - Nuevas: `alien` (7), `back_to_the_future` (3), `ghostbusters` (5),
    `indiana_jones` (5), `jurassic_park` (7), `matrix` (4), `men_in_black` (4),
    `terminator` (6), `transformers` (7).
  - Órdenes narrativos destacados: Alien pone Prometheus/Covenant antes de
    Alien y Romulus; Star Wars pasa a 1→9; Indiana Jones empieza por el Templo
    Maldito; Transformers empieza por Bumblebee y Rise of the Beasts; Fast &
    Furious mueve Tokyo Drift tras Fast & Furious 6.
- IDs TMDB comprobados contra `themoviedb.org` (el slug del redirect 403):
  corregidos `217` (Calavera de Cristal), `335977` (Dial del Destino) y `41154`
  (Men in Black 3); el resto de la lista confirmada.
- `storyOrder` se parsea en `CuratedFranchiseItem`; `sortKey` usa año en
  `release` y `storyOrder` en `story`; el índice del catálogo desempata.
- `franchiseSortOrderProvider` (Notifier) conserva la elección al navegar entre
  franquicias; por defecto `release`. Se persiste en `SharedPreferences` con la
  clave `app.franchise_sort_order` y se recarga en `build()`.
- En modo cronológico cada póster muestra su número de posición (1, 2, 3…) en
  la esquina superior izquierda, sobre un triángulo (`_CornerTrianglePainter`,
  76x68, degradado `#0B323A`) enrasado con el borde de la tarjeta y número cian
  `#6FE9F2` encima; los faltantes muestran además su badge debajo.
- `mcu.storyOrder` reescrito según el cronológico de DigitalSpy (solo
  películas, 39 títulos): Capitana Marvel tras Cap1; Thor: Mundo Oscuro antes
  que Iron Man 3; Guardianes 2 antes que Vengadores 2; Viuda Negra tras Civil
  War; Deadpool y Lobezno tras Endgame y antes de Shang-Chi; Wakanda Forever
  antes que Love and Thunder; Doomsday cierra en 39.
- Series añadidas a `mcu` (29 tv + 3 especiales como película, 71 entradas en
  total): las 15 de Netflix/ABC/Hulu (SHIELD, Agent Carter, Daredevil, Jessica
  Jones, Luke Cage, Iron Fist, Defenders, Inhumans, Punisher, Runaways,
  Cloak & Dagger) y las 14 de Disney+ (WandaVision, Falcon/WS, Loki, What If,
  Hawkeye, Moon Knight, Ms. Marvel, She-Hulk, Secret Invasion, I Am Groot,
  Echo, Agatha, Born Again, Ironheart, Eyes of Wakanda, Marvel Zombies,
  Wonder Man, VisionQuest) más los especiales (Werewolf, Fiestas, One Last
  Kill). IDs TMDB verificados contra `themoviedb.org` uno por uno; cada serie
  es una sola entrada situada en su primera aparición cronológica.
- `flutter gen-l10n` → claves `sortByRelease` / `sortChronological` presentes en
  `app_localizations_es.dart` y `app_localizations_en.dart`.
- `flutter analyze` → `No issues found!`.

## Next
- Verificación visual por el desarrollador: alternar ambos chips en Alien,
  Star Wars y Transformers, comprobar el foco TV en los chips, que el número
  grande se vea como la referencia y que el orden persista tras reiniciar. Sin
  `flutter build` (norma del proyecto).
