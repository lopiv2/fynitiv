# Logos de estudios

Deja aquí los logos de los estudios. El nombre del archivo puede ser el que
quieras (`.png`, `.webp`, `.jpg` o `.svg`): la app busca en esta carpeta un
archivo cuyo nombre coincida con el del estudio ignorando mayúsculas, espacios
y guiones.

Ejemplos que ya funcionan:

- `Walt_Disney_Pictures.webp` → Walt Disney Pictures
- `marvel_studios.png` → Marvel Studios
- `lucasfilm.png` → Lucasfilm

Si no encuentra un archivo para un estudio, cae al logo que devuelve
Seerr/TMDB; si tampoco hay, la tarjeta muestra el backdrop de la primera
película y el nombre del estudio.

El campo `logo` de `assets/data/studios.json` sirve como pista/ruta explícita y
tiene prioridad si el archivo existe.
