# Pokédex — Proyecto final de Desarrollo de Aplicaciones Móviles

Aplicación Flutter. **KAN-7 / PKD-01** estableció la estructura por
funcionalidades, la navegación inicial y los contratos entre módulos.
**KAN-9 / PKD-03** añadió la consulta paginada del catálogo a PokéAPI.
**KAN-11 / PKD-05** añadió la pantalla del catálogo y sus estados.
**KAN-12 / PKD-06** añadió el arranque sin bloqueos y la carga progresiva.
**KAN-10 / PKD-04** conectó GraphQL con la lectura local observable.
**KAN-8 / PKD-02** añadió la base SQLite (Drift) como fuente de verdad.
**KAN-13 / PKD-07** añadió el indicador global de conectividad.

## Requisitos y ejecución

Usar una instalación de Flutter que incluya Dart compatible con `^3.13.5`,
según `pubspec.yaml`, y un emulador o dispositivo Android/iOS configurado.

```sh
flutter pub get
flutter run
```

Para compilar en Android hace falta el **NDK 28.2.13676358** (la versión que
pide Flutter). Drift incluye SQLite nativo y se compila con el NDK. Si Gradle
no logra instalarlo solo, se instala desde Android Studio (SDK Manager → SDK
Tools → NDK) o con `android sdk install ndk/28.2.13676358`.

El código generado de Drift (`*.g.dart`) está versionado, así que no hace falta
ejecutar `build_runner` para correr la app. Solo hay que regenerarlo si se
cambian las tablas (ver [KAN-8](#kan-8--pkd-02--base-local-con-drift)).

Al abrirse, la app muestra lo que haya en la base local y, en segundo plano,
descarga la primera página del catálogo desde PokéAPI. Cada tarjeta abre el
detalle del Pokémon. También puedes navegar a Favoritos y Trivia. Las pruebas
de widgets siguen usando `AppDependencies.demo()`, con datos en memoria.

## KAN-13 / PKD-07 — Gestión de conectividad e indicador global

Una barra fija arriba de todas las pantallas (catálogo, favoritos, trivia y
detalle) informa la disponibilidad del servicio, la actividad de
sincronización y la vigencia de los datos locales.

| Estado | Cuándo | Indicador |
|---|---|---|
| Verificando | Al iniciar, antes de la primera comprobación | «Verificando conexión…» |
| En línea | PokéAPI respondió una consulta GraphQL | «En línea» |
| Sincronizando | En línea y hay una descarga en curso | «Sincronizando…» con progreso |
| Sin conexión | El dispositivo no tiene red o no resuelve el servidor | «Sin conexión» |
| Servicio no disponible | Hay red, pero la API falla, tarda más de 5 s o devuelve errores | «Servicio no disponible» |

La segunda línea muestra `Datos locales · actualizado HH:mm` a partir de
`sync_metadata.last_success_at` (IND-04). Cada estado combina icono, texto y
color, y una etiqueta `Semantics` con región en vivo que TalkBack anuncia
(IND-05).

**Cómo se decide el estado (IND-02).**
[`ApiConnectivityService`](lib/core/data/api_connectivity_service.dart) escucha
los cambios de red de [`connectivity_plus`](https://pub.dev/packages/connectivity_plus)
y, cuando hay red, envía `query { __typename }` a PokéAPI con límite de 5 s
([`checkGraphqlService`](lib/core/data/graphql_health_check.dart)). Solo una
respuesta GraphQL válida produce «En línea». La comprobación se repite cada
30 s mientras haya red. Para evitar parpadeos (IND-06), perder «En línea»
exige dos comprobaciones fallidas seguidas (la segunda a los 3 s); recuperarlo
es inmediato.

**Disponibilidad y sincronización por separado (§7.4).** `ConnectivityStatus`
y `SyncActivity` son contratos distintos.
[`SyncActivityTracker`](lib/core/data/sync_activity_tracker.dart) marca
`syncing` mientras `ObservableCatalogRepository` descarga y guarda. El
indicador muestra «Sincronizando» solo con el servicio en línea, así que nunca
aparece «sin conexión y sincronizando».

**Reconexión (PA-07).** Al pasar de «Sin conexión» o «Servicio no disponible»
a «En línea», `CatalogPage` llama a `refresh()` sin intervención del usuario.

**Pendiente para la entrega final:** reintentos con backoff (RNF-RES-02) y un
mecanismo documentado para simular la API caída con red activa (PA-08).

```sh
flutter test test/core test/app test/catalog_page_test.dart
```

## KAN-8 / PKD-02 — Base local con Drift

La app guarda el catálogo, los favoritos y los metadatos de sincronización en
SQLite mediante [Drift](https://drift.simonbinder.eu). La interfaz solo lee de
esta base (OF-16, OF-17): las respuestas de GraphQL se validan, se guardan en
una transacción y la pantalla recibe el cambio porque observa la base.

### Modelo de datos (PS-01)

```
pokemon ─────────────< pokemon_types >──────────── types
id PK                  pokemon_id FK (cascade)      name PK
name                   slot                         
national_number        type_name FK                 
artwork_url            PK (pokemon_id, slot)
sprite_url
updated_at (UTC)

favorites                          sync_metadata
pokemon_id PK (sin FK)             resource_key PK ('catalog')
created_at (UTC)                   last_success_at (UTC)
                                   next_offset (>= 0 o NULL)
                                   status
```

| Tabla | Para qué | Archivo |
|---|---|---|
| `pokemon` | Un registro por Pokémon del catálogo | [catalog_tables.dart](lib/features/catalog/data/local/catalog_tables.dart) |
| `types` | Tipos conocidos (clave natural: nombre) | mismo archivo |
| `pokemon_types` | Relación Pokémon–tipo; `slot` conserva el orden de PokéAPI | mismo archivo |
| `favorites` | Favoritos del usuario | [favorites_table.dart](lib/features/favorites/data/local/favorites_table.dart) |
| `sync_metadata` | Última actualización exitosa y siguiente página por recurso | [sync_metadata_table.dart](lib/core/database/sync_metadata_table.dart) |

[`AppDatabase`](lib/core/database/app_database.dart) reúne las tablas que
define cada funcionalidad en su capa `data/local/`. Ninguna clase de Drift sale
de la capa data: los adaptadores convierten las filas a `PokemonSummary`,
`CatalogSnapshot` y `PokemonId`.

**Índices (RNF-REN-02)**

| Índice | Columnas | Uso |
|---|---|---|
| `idx_pokemon_order` | `pokemon(national_number, id)` | Orden del catálogo, igual al de la consulta GraphQL |
| `idx_pokemon_name` | `pokemon(name)` | Búsqueda por nombre (RF-CAT-03) |
| `idx_pokemon_types_type` | `pokemon_types(type_name)` | Filtro por tipo (RF-FIL-01) |

### Decisiones de persistencia y sincronización

- **Claves estables (PS-05).** `pokemon.id` es el ID del recurso de PokéAPI, el
  mismo valor que `PokemonId`. El número nacional se guarda aparte y no
  identifica filas. Restricciones `CHECK` impiden IDs, `slot` y desplazamientos
  negativos.
- **Sin duplicados (PS-06).** [`DriftCatalogLocalStore.upsertPage`](lib/features/catalog/data/local/drift_catalog_local_store.dart)
  inserta o actualiza cada Pokémon por su clave (`INSERT ... ON CONFLICT DO
  UPDATE`). Los tipos de cada Pokémon recibido se borran y se vuelven a
  insertar con su `slot`. Los Pokémon de otras páginas no se tocan.
- **Escrituras transaccionales (RNF-RES-04).** Pokémon, tipos y metadatos se
  guardan en una sola transacción. Si una instrucción falla, SQLite revierte
  todo y Drift no notifica a los observadores, así que la pantalla conserva la
  vista anterior (OF-04).
- **Lectura observable.** `watchCatalog()` emite la vista actual al suscribirse
  (vacía si no hay datos) y una vista nueva después de cada transacción
  confirmada. Cada vista se lee dentro de una transacción para que Pokémon,
  tipos y metadatos correspondan al mismo estado.
- **Metadatos (PS-09).** `sync_metadata` guarda una fila por recurso. Para el
  catálogo, `last_success_at` llega a la pantalla como
  `CatalogSnapshot.lastUpdated` (base para IND-04) y `next_offset` define la
  siguiente página y `hasMore`.
- **Datos del usuario separados (PS-11).** `favorites.pokemon_id` es una
  referencia lógica **sin** clave foránea. Ninguna operación sobre el catálogo
  puede borrar o cambiar favoritos por cascada, y se puede marcar un favorito
  aunque el Pokémon todavía no esté en el catálogo local.
  [`DriftFavoritesRepository`](lib/features/favorites/data/local/drift_favorites_repository.dart)
  es idempotente: repetir `true` conserva la fecha original.
- **Fechas.** Se guardan como texto ISO-8601 en UTC (`build.yaml`) para
  conservar los milisegundos y leerlas directamente en un inspector.
- **Conexión.** En producción, `driftDatabase(name: 'pokedex')` abre el archivo
  `pokedex.sqlite` en el directorio de documentos de la app y ejecuta SQLite en
  un isolate de fondo (RNF-REN-03). La composición está en
  [`AppDependencies.production()`](lib/app/app_dependencies.dart).

### Migraciones (PS-10)

`AppDatabase.schemaVersion` es `1`. Cada versión publicada se exporta a
[`drift_schemas/`](drift_schemas/app_database/) y una prueba valida que la base
coincide con ese esquema. Para cambiar las tablas:

1. Modificar la tabla y subir `schemaVersion`.
2. Ejecutar `dart run build_runner build`.
3. Ejecutar `dart run drift_dev make-migrations`, que exporta el nuevo esquema,
   genera los pasos tipados y las pruebas de cada migración.
4. Escribir el paso en `migration.onUpgrade` y correr `flutter test test/drift`.

### Cómo probarlo

```sh
dart run build_runner build      # solo si cambiaron las tablas
flutter test test/data/local test/drift
```

| Prueba | Qué comprueba |
|---|---|
| [app_database_test.dart](test/data/local/app_database_test.dart) | Tablas, índices y claves foráneas activas |
| [drift_catalog_local_store_test.dart](test/data/local/drift_catalog_local_store_test.dart) | Vista vacía, orden, tipos, metadatos; tres guardados iguales no cambian los conteos (PA-13); un fallo revierte todo y no emite |
| [drift_catalog_repository_contract_test.dart](test/data/local/drift_catalog_repository_contract_test.dart) | `ObservableCatalogRepository` con la base real: refresh, fallo de GraphQL y paginación |
| [drift_favorites_repository_test.dart](test/data/local/drift_favorites_repository_test.dart) | Idempotencia, varios observadores y que el catálogo no altere favoritos |
| [database_persistence_test.dart](test/data/local/database_persistence_test.dart) | Cerrar y reabrir el archivo conserva catálogo, metadatos y favoritos |
| [migration_test.dart](test/drift/app_database/migration_test.dart) | La base coincide con el esquema exportado v1 |

Prueba manual (PA-04 dentro del alcance del avance): abrir la app con red y
cargar dos páginas; forzar el cierre; desactivar la red; volver a abrir. El
catálogo sigue visible con un aviso de que no se pudo actualizar. Las imágenes
offline corresponden a KAN-14 y el indicador de conectividad a KAN-13.

## KAN-10 / PKD-04 — Integración del catálogo remoto con la lectura local

[`ObservableCatalogRepository`](lib/features/catalog/data/observable_catalog_repository.dart)
coordina la descarga desde PokéAPI y el guardado. La pantalla sigue usando
`CatalogRepository`. En la integración, `watchCatalog()` devuelve el flujo de
la fuente local y la consulta remota solo se ejecuta al actualizar o paginar.

- **Actualización inicial.** `refresh()` descarga desde el desplazamiento 0,
  conserva los registros de otras páginas y reinicia el desplazamiento para
  volver a recorrer las páginas. Al repetir una página, el guardado actualiza
  por `PokemonId`.
- **Paginación.** `loadNextPage()` usa el desplazamiento guardado. Si es nulo,
  termina sin consultar. Una cola serializa la actualización y las páginas
  para que cada solicitud lea el desplazamiento que dejó la anterior.
- **Escritura.** El [contrato local](lib/features/catalog/data/local/catalog_local_store.dart)
  entrega los Pokémon, el desplazamiento y la fecha UTC a una sola operación.
  El adaptador de KAN-8 debe confirmarlos en una transacción y publicar la
  vista local solo después de confirmarla.
- **Fallos.** Si GraphQL falla o devuelve datos inválidos, el repositorio
  evita la escritura. Si falla el guardado, el contrato exige conservar los
  registros, la fecha y el desplazamiento anteriores. El error llega a la
  pantalla y la cola permite reintentar.

```sh
flutter test test/observable_catalog_repository_test.dart
```

Las pruebas usan respuestas GraphQL controladas y una fuente local en memoria.
Verifican lectura observable, actualización sin duplicados, conservación de
datos ante fallos y paginación después de guardar. KAN-8 conectó el adaptador
Drift al arranque y repite estos flujos con la base real.

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
