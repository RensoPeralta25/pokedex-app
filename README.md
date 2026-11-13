# Pokédex — Proyecto final de Desarrollo de Aplicaciones Móviles

Aplicación Flutter. **KAN-7 / PKD-01** estableció la estructura por
funcionalidades, la navegación inicial y los contratos entre módulos.
**KAN-9 / PKD-03** añadió la consulta paginada del catálogo a PokéAPI.
**KAN-11 / PKD-05** añadió la pantalla del catálogo y sus estados.
**KAN-12 / PKD-06** añadió el arranque sin bloqueos y la carga progresiva.

## Requisitos y ejecución

Usar una instalación de Flutter que incluya Dart compatible con `^3.13.5`,
según `pubspec.yaml`, y un simulador/dispositivo configurado.

```sh
flutter pub get
flutter run
```

La app abre el catálogo con Bulbasaur, Charmander y Squirtle como datos de
demostración. Cada tarjeta abre el detalle del Pokémon. También puedes navegar
a Favoritos y Trivia. KAN-10 conectará la fuente remota de KAN-9 con la
persistencia y el catálogo observable.

## KAN-12 / PKD-06 — Arranque y carga progresiva

La pantalla se suscribe a `watchCatalog()` al abrirse. Al recibir la primera
vista del repositorio, espera a que Flutter termine el cuadro actual y llama a
`refresh()` en segundo plano. Si el catálogo ya contiene datos, las tarjetas
permanecen visibles durante la actualización. Las pestañas siguen disponibles.

| Decisión | Motivo |
| --- | --- |
| Mostrar **Cargar más** cuando `CatalogSnapshot.hasMore` es verdadero | El repositorio indica si quedan datos. El botón permite pedir la siguiente página de forma explícita. |
| Deshabilitar la carga mientras hay una operación en curso | Evita solicitudes simultáneas por toques repetidos y evita paginar durante una actualización inicial. |
| Mostrar el fallo junto a **Reintentar página** | Se conserva la cuadrícula y se puede reintentar sin perder los elementos visibles. |
| Leer los nuevos elementos desde `watchCatalog()` | `loadNextPage()` solo indica si la operación terminó. La pantalla recibe el catálogo actualizado cuando lo publica el repositorio. |

### Cómo probarlo

1. Ejecuta `flutter run` y abre **Catálogo**. Verás tres Pokémon de prueba.
2. Pulsa **Cargar más**. Mientras aparece el indicador, puedes navegar a otra
   pestaña. Al regresar, podrás ver Pikachu, Jigglypuff y Meowth al desplazarte
   por la cuadrícula. El botón desaparece al terminar la segunda página.
3. Ejecuta `flutter test test/catalog_page_test.dart` para comprobar la
   navegación durante una actualización pendiente, el bloqueo de solicitudes
   repetidas y la recuperación de un error de página sin perder tarjetas.

El repositorio de demostración simula dos páginas en memoria. KAN-10
conectará la consulta GraphQL con la base local observable. La validación de
PA-01 con una instalación limpia, datos reales e indicador de sincronización
queda para la integración del avance.

## KAN-11 / PKD-05 — Pantalla del catálogo

La pantalla permite explorar Pokémon y abrir su detalle. Consume el
`Stream<CatalogSnapshot>` del repositorio inyectado. Esto permite validar
la interfaz con datos de prueba mientras avanza la integración con la base local.

### Qué se implementó y por qué

| Componente | Decisión |
| --- | --- |
| [`CatalogPage`](lib/features/catalog/presentation/catalog_page.dart) | Observa el repositorio y muestra carga, contenido, vacío o error. Conserva la navegación al detalle y usa `GridView.builder` para construir las tarjetas conforme aparecen en pantalla. |
| [`PokemonCatalogCard`](lib/features/catalog/presentation/pokemon_catalog_card.dart) | Presenta nombre, número nacional con ceros iniciales, tipos e imagen. Si falta el arte oficial o falla su descarga, prueba el sprite disponible. Si tampoco hay sprite, muestra un ícono y conserva visible el resto de la tarjeta. |
| [`DemoCatalogRepository`](lib/features/catalog/data/demo_catalog_repository.dart) | Provee tres registros iniciales con número, tipos y referencias a imágenes de PokéAPI. Los datos de las tarjetas están disponibles sin conexión. Las imágenes se cargan cuando sus enlaces están disponibles. |

La cuadrícula usa entre una y cuatro columnas, según el ancho disponible y la
escala del texto. Esto permite usar el espacio de pantallas anchas y mantener
legibles las tarjetas en pantallas pequeñas o con texto ampliado.

### Estados de pantalla

| Estado | Qué se ve |
| --- | --- |
| Carga | Un indicador mientras llega la primera vista del repositorio o está en curso un reintento. |
| Contenido | Las tarjetas de los Pokémon disponibles. |
| Vacío | El mensaje «No hay Pokémon disponibles». |
| Error | Un mensaje y el botón **Reintentar**. El botón llama a `refresh()` y, si termina correctamente, vuelve a suscribirse para recuperar incluso un flujo que se cerró. |

### Cómo revisar el ticket

1. Ejecuta `flutter pub get` y `flutter run` con un emulador o dispositivo.
2. En **Catálogo**, comprueba que Bulbasaur (`#001`), Charmander (`#004`) y
   Squirtle (`#007`) muestren sus nombres, tipos y arte.
3. Abre una tarjeta y vuelve con el botón de retroceso. Prueba un ancho
   distinto o aumenta el tamaño del texto para comprobar la cuadrícula.
4. Ejecuta las pruebas de pantalla para reproducir carga, vacío, error,
   recuperación mediante **Reintentar** y cambio de ancho.

```sh
flutter test test/catalog_page_test.dart
```

La validación del ticket pasó con `flutter analyze` y las 13 pruebas del proyecto.
La persistencia y la carga de páginas remotas desde la pantalla corresponden
a los tickets de integración y paginación.

## KAN-9 / PKD-03 — Catálogo remoto con GraphQL

El ticket implementa la descarga del catálogo de PokéAPI por páginas y
convierte la respuesta en datos que el proyecto puede utilizar. Así KAN-10
podrá guardar cada página en la base local y actualizar el catálogo a partir
de esos datos. La pantalla sigue usando el catálogo de demostración hasta
que se conecte esa integración.

### Qué se implementó y por qué

| Componente | Qué hace y por qué |
| --- | --- |
| [`PokeApiGraphqlClient`](lib/features/catalog/data/remote/poke_api_graphql_client.dart) | Envía la consulta y sus variables como JSON mediante un `POST` al endpoint `https://graphql.pokeapi.co/v1beta2`. Usa `HttpClient` de Dart y concentra el manejo de HTTP y el tiempo de espera en un solo lugar. |
| [`PokeApiCatalogSource`](lib/features/catalog/data/remote/poke_api_catalog_source.dart) | Define qué campos pedir a PokéAPI, valida la respuesta y devuelve un `CatalogRemotePage` con la lista y el desplazamiento siguiente. Recibe una función de consulta por constructor para probar la paginación con respuestas controladas. |
| [`PokemonCatalogDto`](lib/features/catalog/data/remote/pokemon_catalog_dto.dart) | Lee y valida la estructura JSON de PokéAPI. Convierte cada registro en `PokemonSummary` para que la base local y la interfaz trabajen con el modelo del proyecto. |
| [`PokemonSummary`](lib/features/catalog/domain/pokemon_summary.dart) | Conserva el ID y el nombre, y agrega número nacional, tipos, arte oficial y sprite frontal. La lista de tipos se copia como inmutable y las imágenes pueden estar ausentes. Los constructores existentes que pasan ID y nombre siguen funcionando. |
| [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) | Declara el permiso de Internet en el manifiesto principal para que Android pueda hacer las consultas también en compilaciones de distribución. |

La consulta filtra por `is_default` para mostrar la variedad predeterminada
de cada especie en el catálogo inicial. Ordena por número nacional y usa el
ID del recurso para desempatar. También ordena los tipos por su ranura para
conservar su orden original.

El ID de un recurso Pokémon y el número nacional cumplen funciones distintas.
`PokemonId` identifica el registro que la app usará para consultar el detalle
o guardar favoritos. El número nacional viene de `pokemon_species_id` y
permite ordenar y mostrar las especies en la Pokédex. Las imágenes se
devuelven como referencias HTTP o HTTPS para que la descarga pueda manejarse
por separado.

### Cómo funciona la paginación

1. `fetchPage()` empieza en `offset: 0` y devuelve hasta 20 Pokémon. Se
   puede pedir un tamaño entre 1 y 100.
2. Para una página de 20, la consulta pide 21 registros. Si llegan 21, la
   fuente entrega los primeros 20 y devuelve `nextOffset: 20`. El registro
   adicional se incluirá al consultar la segunda página.
3. Si llegan 20 o menos, devuelve esos registros y `nextOffset: null`.
   Eso permite detectar el final incluso cuando la última página tiene
   exactamente 20 Pokémon. `hasMore` se deriva de `nextOffset`.

KAN-10 podrá pasar ese desplazamiento a la siguiente llamada después de
guardar la página correctamente. Si falla la descarga o el guardado,
conservar el desplazamiento permite reintentar la misma página.

### Manejo de errores

El cliente aplica un límite de **15 segundos** a la petición completa,
incluida la lectura de la respuesta, y cierra la conexión al terminar.
Reporta estados HTTP distintos de 200 y respuestas que tengan un formato
inválido. GraphQL puede devolver HTTP 200 con un campo `errors`. La fuente
rechaza esa respuesta, incluso si trae datos parciales, para que el
repositorio pueda conservar el catálogo válido que ya tenga guardado.
La ausencia de una imagen es un caso válido y se representa con `null`.

### Ejemplo de uso

```dart
import 'package:dart_final_project/features/catalog/data/remote/poke_api_catalog_source.dart';

Future<void> main() async {
  final source = PokeApiCatalogSource();
  final firstPage = await source.fetchPage();

  for (final pokemon in firstPage.items) {
    print('#${pokemon.nationalNumber} ${pokemon.name} · ${pokemon.types.join(', ')}');
  }

  final nextOffset = firstPage.nextOffset;
  if (nextOffset != null) {
    final nextPage = await source.fetchPage(offset: nextOffset);
    print('Pokémon en la segunda página: ${nextPage.items.length}');
  }
}
```

Para probar la conexión manualmente, guarda el ejemplo como
`tool/check_catalog.dart` y ejecuta `dart run tool/check_catalog.dart` desde
la raíz después de `flutter pub get`.

### Cómo se verificó

```sh
flutter test test/catalog_remote_source_test.dart
```

Las cuatro pruebas de KAN-9 cubren el mapeo de campos, el cambio de página,
la separación entre ID y número nacional, las imágenes ausentes y el rechazo
de datos inválidos o errores GraphQL. El análisis de Dart y las 10 pruebas
del proyecto pasaron. Una comprobación adicional con un servidor local
validó el `POST`, el manejo de errores HTTP y el tiempo de espera.

La consulta al endpoint público quedó pendiente de confirmar porque PokéAPI
devolvió HTTP 504 durante la prueba en vivo.

## Estructura

- `lib/app/`: aplicación, navegación e inyección por constructor.
- `lib/core/`: identidad y servicios compartidos.
- `lib/features/`: catálogo, detalle, favoritos y trivia.
- `test/`: pruebas de contratos, navegación y sustitución de dependencias.
- `docs/architecture.md`: acuerdos de KAN-7 y detalles de la fuente remota de KAN-9.

Cada funcionalidad incorpora `domain`, `data` y `presentation` según su necesidad.
El dominio utiliza Dart puro. Las pantallas dependen de interfaces; las
implementaciones se seleccionan en `AppDependencies`.

## Validación

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Consultar [Arquitectura y contratos](docs/architecture.md) antes de implementar
los siguientes tickets. El acuerdo y la contribución verificable del segundo
integrante siguen pendientes de revisión conjunta.
