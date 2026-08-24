# Consideraciones de desarrollo

Notas y preferencias sobre cómo trabajar en este proyecto.

## Builds

- **Nunca ejecutar un build (`flutter build ...`) al terminar una respuesta.** Usar solo `flutter analyze` (y `flutter test` si procede) como verificación. El build es lento y lo ejecuta el desarrollador cuando lo pide.

## Reutilización de componentes

- Si se pide un componente que hace lo mismo que otro ya existente, generar un **widget genérico** reutilizable en lugar de duplicar código, y usarlo en los lugares que lo necesiten.

## Traduccion de cadenas
- Siempre que vaya a haber texto de widgets, debe traducirse con cadenas ARB, minimo a ingles y español, como ya esta en otras partes de la aplicacion. Se reutilizaran cadenas si ya existen en dichos archivos ARB, para no duplicar claves
