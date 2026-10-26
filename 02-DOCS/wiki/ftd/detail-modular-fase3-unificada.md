# FTD — Detalle modular fase 3: DetailPage unificada (PENDIENTE)

## Intent

`DetailPage` única que sustituya a `ItemDetailScreen` (pelis/series/
episodios), `BookDetailScreen`, `artist_detail_screen`,
`person_detail_screen` y, más adelante, Seerr/juegos: recibe el item y un
`skin` opcional, resuelve `detailLayoutFor(skin, kind)` y compone secciones
con builders por tipo. Sin cambios visuales en la migración.

## Scope

- NUEVA `DetailPage` + builders por tipo (libro ya pilotado en fase 2;
  replicar patrón a peli/serie/música/persona).
- Migrar rutas una a una manteniendo las pantallas viejas hasta paridad.
- Partir `_AdditionalInformation` en secciones (`synopsis`/`credits`/`extras`
  separadas) cuando un tipo lo necesite.
- Variantes de cabecera por skin (`DetailHeaderStyle`) como primer cambio
  visible opcional.
- Sin ARB nuevas salvo que una variante las pida, sin tocar
  `PrimeCardBadge`, en `main`.

## Checklist

- [ ] `DetailPage` + builders por tipo.
- [ ] Migración de rutas con paridad visual.
- [ ] `flutter analyze` limpio.

## Evidence

- Pendiente de ejecución (fase apuntada, no iniciada).

## Next

- Ejecutar cuando se priorice; antes, si eso, una variante visible por skin
  sobre el cableado de fase 2.
