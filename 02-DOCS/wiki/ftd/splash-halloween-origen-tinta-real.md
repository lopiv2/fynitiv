# FTD — Origen en la tinta visible de Halloween

## Intent

Enfoque inicial para corregir los chorros que flotaban sobre las letras. El usuario aclaró que se refería a los `capDrips` recortados dentro de las letras, no a las líneas independientes del overlay; por ello se reemplaza por `splash-halloween-capdrips-caida-sincronizada.md`.

## Scope

- Enfoque reemplazado: no añadir un ratio de top de tinta específico a la fuente.
- La implementación correcta usa los capdrips dentro del glifo y comparte su semilla/centros con las gotas que caen; ver la FTD enlazada arriba.
- Sin tests (no solicitados), no tocar personalizaciones manuales, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del cambio.
- [x] Requerimiento corregido tras aclaración del usuario; no se implementa el enfoque de ratio de tinta.

## Evidence

- La captura compartida por el usuario mostró que el límite superior de la caja tipográfica situaba los chorros por encima de la tinta; la corrección solicitada después especificó los `capDrips` interiores.

## Next

- Seguir la verificación visual en `splash-halloween-capdrips-caida-sincronizada.md`.
