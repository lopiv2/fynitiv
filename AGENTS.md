# Consideraciones de desarrollo

Notas y preferencias sobre cómo trabajar en este proyecto.

## Builds

- **Nunca ejecutar un build (`flutter build ...`) al terminar una respuesta.** Usar solo `flutter analyze` (y `flutter test` si procede) como verificación. El build es lento y lo ejecuta el desarrollador cuando lo pide.

## Reutilización de componentes

- Si se pide un componente que hace lo mismo que otro ya existente, generar un **widget genérico** reutilizable en lugar de duplicar código, y usarlo en los lugares que lo necesiten.

- Si se agregase un nuevo scroll slider a algun skin, siempre ajustar el Focus, para no perder funcionalidad respecto al modo TV

## Traduccion de cadenas

- Siempre que vaya a haber texto de widgets, debe traducirse con cadenas ARB, minimo a ingles y español, como ya esta en otras partes de la aplicacion. Se reutilizaran cadenas si ya existen en dichos archivos ARB, para no duplicar claves

## Utiliza siempre el widget universal de Hover en todas las tarjetas

- Debes utilizar el widget universal de Hover en todas las tarjetas, y luego ya te ire yo diciendo el enrutamiento y todo eso hacia otras pantallas o reproductores

## Utilizar siempre el loader cuando sea necesario

- Debes utilizar el loader en cualquier parte que este haciendo una peticion DIO a una Api de Jellyfin o externa mientras carga los datos

## Utilizar siempre metodos de la api de jellyfin_dart

- Debes utilizar metodos de la api del paquete jellyfin_dart con funciones para obtener datos de la api de Jellyfin cuando se pueda, para agilizar las llamadas a la api, y la obtencion de datos

## Corrige los problemas siempre que puedas antes de tu respuesta final

- Debes corregir los problemas de consola siempre que puedas antes de dar tu respuesta final

## No tocar elementos corregidos a mano por el usuario

- No corregir la posicion de PrimeCardBadge, dejar tal y como está en las tarjetas posicionada

## No hagas tests si no te lo pido

- No ejecutes, ni escribas ningun test, si el usuario no lo pide por prompt
