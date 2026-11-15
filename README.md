# Pokédex — Proyecto final de Desarrollo de Aplicaciones Móviles

Pokédex móvil en Flutter que consume la API GraphQL de
[PokéAPI](https://pokeapi.co) con una arquitectura **Offline-First +
Online-Preferred**: la interfaz siempre se construye desde una base de datos
local y, cuando el servicio está disponible, la app descarga información
actualizada, la guarda en esa base y la interfaz se entera del cambio.

Estado del **avance** (≈ 40 % del proyecto): catálogo paginado desde PokéAPI,
persistencia local con SQLite, funcionamiento sin conexión tras reiniciar,
indicador global de conectividad e imágenes disponibles sin conexión. El
detalle completo, favoritos en la interfaz, búsqueda, filtros y trivia
corresponden a la entrega final.

## Contenido

1. [Requisitos e instalación](#requisitos-e-instalación)
2. [Tecnologías y justificación](#tecnologías-y-justificación)
3. [Arquitectura](#arquitectura)
4. [Estructura del proyecto](#estructura-del-proyecto)
5. [Estrategia Offline-First](#estrategia-offline-first)
6. [GraphQL y paginación](#graphql-y-paginación)
7. [Sincronización](#sincronización)
8. [Persistencia local](#persistencia-local)
9. [Gestión de conectividad](#gestión-de-conectividad)
10. [Imágenes sin conexión](#imágenes-sin-conexión)
11. [Funcionalidades adicionales implementadas](#funcionalidades-adicionales-implementadas)
12. [Pruebas y verificación](#pruebas-y-verificación)
13. [Limitaciones conocidas](#limitaciones-conocidas)
14. [Decisiones de arquitectura (ADR)](#decisiones-de-arquitectura-adr)
15. [Uso de herramientas de IA](#uso-de-herramientas-de-ia)
16. [Historial por ticket](#historial-por-ticket)

## Requisitos e instalación

| Requisito | Versión |
|---|---|
| Flutter (stable) | 3.47 o superior, con Dart compatible con `^3.13.5` |
| Android SDK | API 24 o superior en el dispositivo |
| Android NDK | **28.2.13676358** (Drift compila SQLite nativo con el NDK) |
| Dispositivo | Teléfono Android con depuración USB o emulador |

```sh
flutter pub get
flutter run
```

- Si Gradle no instala el NDK solo: Android Studio → SDK Manager → SDK Tools →
  NDK, o `android sdk install ndk/28.2.13676358`.
- El código generado de Drift (`*.g.dart`) está versionado: no hace falta
  ejecutar `build_runner` para correr la app. Solo se regenera si cambian las
  tablas (ver [Migraciones](#migraciones)).
- APK de depuración: `flutter build apk --debug`. Para un teléfono con poco
  espacio, `flutter build apk --release --split-per-abi --target-platform android-arm64`
  genera uno de ~18 MB.

## Tecnologías y justificación

| Dependencia | Para qué | Por qué |
|---|---|---|
| Flutter / Dart | Aplicación multiplataforma | Exigido por el enunciado |
| `HttpClient` de `dart:io` | Cliente GraphQL (POST JSON) | Una sola consulta con variables no justifica un cliente GraphQL completo; la caché normalizada de esos clientes no sustituye la persistencia estructurada (§6.5) |
| [`drift`](https://pub.dev/packages/drift) ^2.35 + [`drift_flutter`](https://pub.dev/packages/drift_flutter) ^0.3 | Base local SQLite | Claves, índices y transacciones reales; consultas reactivas que solo emiten datos confirmados; migraciones con esquemas exportados; ejecución en un isolate de fondo. Ver [ADR-0001](docs/adr/0001-persistencia-drift.md) |
| [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) ^7.3 | Cambios de red del dispositivo | Avisa al instante de Wi-Fi, datos o modo avión; la disponibilidad real se confirma con GraphQL. Ver [ADR-0002](docs/adr/0002-disponibilidad-graphql.md) |
| [`cached_network_image`](https://pub.dev/packages/cached_network_image) ^4.0 + [`flutter_cache_manager`](https://pub.dev/packages/flutter_cache_manager) ^3.5 | Imágenes en disco | Caché con límite de objetos y caducidad configurables; permite precargar y mostrar sin red |
| `drift_dev` ^2.35, `build_runner` ^2.17 (desarrollo) | Generación de código y migraciones de Drift | Requeridos por Drift |
| `flutter_lints` ^6.0 (desarrollo) | Análisis estático | RNF-CAL-01 |

**Gestión de estado.** Se usan `Stream` y `StreamBuilder` de Flutter con
inyección por constructor, sin Riverpod ni BLoC. Cada repositorio expone un
`Stream` observable (catálogo, favoritos, conectividad, sincronización) y las
pantallas solo se suscriben. Para el alcance del avance evita una dependencia
más; si la entrega final lo requiere, los contratos permiten introducir un
gestor de estado sin cambiar las capas de datos.

## Arquitectura

Organización por funcionalidades con tres capas. Las dependencias apuntan
hacia el dominio (P-04).

| Capa | Responsabilidad | No puede |
|---|---|---|
| `presentation` | Pantallas, widgets, estados de carga/vacío/error, indicador | Acceder a GraphQL ni a la base |
| `domain` | Entidades (`PokemonId`, `PokemonSummary`, `CatalogSnapshot`), contratos de repositorio y servicios | Importar Flutter, Drift ni HTTP |
| `data` | Repositorios, fuentes remota y local, DTO, tablas, caché de imágenes | Exponer DTO o filas de Drift a la presentación |

```
 Presentation                 Domain (contratos)                Data
┌──────────────────┐   ┌──────────────────────────┐   ┌─────────────────────────────────┐
│ CatalogPage      │──►│ CatalogRepository        │◄──│ ObservableCatalogRepository      │
│ PokemonCatalogCard│  │ FavoritesRepository      │◄──│ DriftFavoritesRepository         │
│ ConnectivityIndicator►│ ConnectivityService     │◄──│ ApiConnectivityService           │
│ FavoritesPage    │   │ SyncActivityMonitor      │◄──│ SyncActivityTracker              │
└──────────────────┘   └──────────────────────────┘   │  ├─ PokeApiCatalogSource (GraphQL)│
                                                       │  ├─ DriftCatalogLocalStore (SQLite)│
                                                       │  └─ CacheImagePrefetcher (disco) │
                                                       └─────────────────────────────────┘
```

[`AppDependencies.production()`](lib/app/app_dependencies.dart) es el único
punto que crea implementaciones concretas y las entrega por constructor
(RNF-MAN-03). `AppDependencies.demo()` usa dobles en memoria para las pruebas
de widgets. Los acuerdos de contratos de KAN-7 están en
[docs/architecture.md](docs/architecture.md).

## Estructura del proyecto

```
lib/
  app/                         composición, navegación e indicador global
  core/
    domain/                    PokemonId, ConnectivityService, SyncActivityMonitor
    data/                      monitor de conectividad, tracker, caché de imágenes
    database/                  AppDatabase (Drift) y sync_metadata
  features/
    catalog/
      domain/                  PokemonSummary, CatalogSnapshot, CatalogRepository
      data/
        remote/                cliente GraphQL, fuente paginada y DTO
        local/                 tablas y DriftCatalogLocalStore
                               ObservableCatalogRepository, CacheImagePrefetcher
      presentation/            CatalogPage y PokemonCatalogCard
    favorites/                 domain / data (Drift) / presentation
    pokemon_detail/            presentation (destino inicial)
    trivia/                    presentation (reservado)
drift_schemas/                 esquemas exportados por versión
test/                          pruebas por capa (core, data/local, drift, app)
docs/                          architecture.md y adr/
```

## Estrategia Offline-First

- **Fuente de verdad local (OF-16, OF-17).** La pantalla del catálogo solo
  observa `CatalogRepository.watchCatalog()`, que en producción es un
  `Stream` de la base SQLite. Ningún widget recibe respuestas GraphQL.
- **Recorrido de un dato.** PokéAPI → `PokeApiGraphqlClient` (POST) →
  `PokemonCatalogDto` valida y convierte a `PokemonSummary` →
  `ObservableCatalogRepository` → `DriftCatalogLocalStore.upsertPage`
  (transacción) → Drift notifica el cambio → `watchCatalog()` emite una vista
  nueva → `CatalogPage` redibuja.
- **Sin bloqueos (OF-03).** Al abrir, la pantalla muestra de inmediato lo que
  haya en la base (o el estado vacío) y, después del primer cuadro, llama a
  `refresh()` en segundo plano. Se puede navegar mientras tanto.
- **Carga inicial (PS-02).** La primera ejecución descarga solo la primera
  página (20 Pokémon). Las siguientes se piden con «Cargar más». No se
  descarga el catálogo completo de entrada.
- **Sin conexión (OF-05, OF-10).** Si `refresh()` falla, la cuadrícula se
  mantiene con los datos guardados y aparece «No se pudo actualizar el
  catálogo» con un botón para reintentar. Tras un cierre forzado sin red, la
  app abre con los mismos datos (PA-04, probado en dispositivo).
- **Errores remotos (OF-04).** Una respuesta inválida o con `errors` de
  GraphQL se rechaza antes de escribir; un fallo al guardar revierte la
  transacción y no cambia la vista.

## GraphQL y paginación

[`PokeApiCatalogSource`](lib/features/catalog/data/remote/poke_api_catalog_source.dart)
consulta `https://graphql.pokeapi.co/v1beta2` pidiendo solo los campos del
catálogo: ID del recurso, número nacional (`pokemon_species_id`), nombre, tipos
ordenados por ranura y sprites (arte oficial y frontal). Filtra
`is_default` para mostrar la variedad predeterminada de cada especie y ordena
por número nacional e ID.

**Paginación por desplazamiento (RF-CAT-02).** PokéAPI admite `limit` y
`offset`, y el orden fijo los hace estables:

1. Cada página pide **21** registros para mostrar **20**.
2. Si llegan 21, devuelve 20 y `nextOffset = offset + 20`; si llegan 20 o
   menos, `nextOffset = null` (fin del catálogo).
3. El desplazamiento se guarda en `sync_metadata` **en la misma transacción**
   que los Pokémon, así que solo avanza si la página se guardó.

**Errores.** [`PokeApiGraphqlClient`](lib/features/catalog/data/remote/poke_api_graphql_client.dart)
limita la petición completa a **15 s** y cierra la conexión al terminar.
Rechaza HTTP distinto de 200, JSON inválido y respuestas con `errors`, aunque
traigan datos parciales. El diferenciado completo de errores (RNF-RES-05) es de
la entrega final.

## Sincronización

| Evento | Qué hace |
|---|---|
| Abrir la pantalla del catálogo | `refresh()`: descarga la página 1 y reinicia el desplazamiento |
| «Cargar más» | `loadNextPage()`: descarga la página indicada por `next_offset` |
| «Reintentar» / «Reintentar actualización» | `refresh()` |
| Pasar de «Sin conexión» o «Servicio no disponible» a «En línea» | `refresh()` automático (PA-07) y reintento de imágenes |

- **Sin solicitudes concurrentes (RNF-RES-03).** `ObservableCatalogRepository`
  serializa `refresh()` y `loadNextPage()` en una cola: cada operación lee el
  desplazamiento que dejó la anterior.
- **Sin duplicados (PS-06, PA-13).** Upsert por `PokemonId`; los tipos de cada
  Pokémon recibido se reemplazan. Tres guardados de la misma página dejan los
  mismos conteos (prueba automática).
- **Transacciones (RNF-RES-04).** Pokémon, tipos y metadatos se confirman
  juntos o no se confirma nada.
- **Actividad visible.** Cada descarga se registra en `SyncActivityTracker`; el
  indicador muestra «Sincronizando…» mientras dura.
- **Registro de última sincronización (PS-09).** `sync_metadata.last_success_at`
  llega al indicador como «Última actualización: HH:mm».

## Persistencia local

Base SQLite con Drift en el archivo `pokedex.sqlite` del directorio de la app.

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

**Índices (RNF-REN-02)**

| Índice | Columnas | Uso |
|---|---|---|
| `idx_pokemon_order` | `pokemon(national_number, id)` | Orden del catálogo |
| `idx_pokemon_name` | `pokemon(name)` | Búsqueda por nombre (RF-CAT-03) |
| `idx_pokemon_types_type` | `pokemon_types(type_name)` | Filtro por tipo (RF-FIL-01) |

**Decisiones**

- **Claves estables (PS-05).** `pokemon.id` es el ID del recurso de PokéAPI
  (`PokemonId`); el número nacional se guarda aparte. Restricciones `CHECK`
  impiden IDs, `slot` y desplazamientos negativos.
- **Datos del usuario separados (PS-11).** `favorites.pokemon_id` no tiene
  clave foránea: ninguna operación del catálogo puede borrar o modificar
  favoritos. [`DriftFavoritesRepository`](lib/features/favorites/data/local/drift_favorites_repository.dart)
  es idempotente (repetir `true` conserva la fecha original).
- **Lectura consistente.** Cada vista del catálogo se lee dentro de una
  transacción para que Pokémon, tipos y metadatos correspondan al mismo estado.
- **Fechas** como texto ISO-8601 en UTC (`build.yaml`).
- **Rendimiento (RNF-REN-03).** `drift_flutter` ejecuta SQLite en un isolate de
  fondo.

### Migraciones

`AppDatabase.schemaVersion` es `1`. Cada versión publicada se exporta a
[`drift_schemas/`](drift_schemas/app_database/) y una prueba valida que la base
coincide con ese esquema (PS-10). Para cambiar las tablas:

1. Modificar la tabla y subir `schemaVersion`.
2. `dart run build_runner build`.
3. `dart run drift_dev make-migrations` (exporta el esquema y genera los pasos
   y sus pruebas).
4. Escribir el paso en `migration.onUpgrade` y ejecutar `flutter test test/drift`.

### Revisar la base en un dispositivo

Con la versión debug:

```sh
adb exec-out run-as com.example.dart_final_project cat app_flutter/pokedex.sqlite > pokedex.sqlite
```

El archivo se abre con cualquier visor de SQLite para contar registros por
tabla (PA-13).

## Gestión de conectividad

Una barra fija arriba de todas las pantallas (catálogo, favoritos, trivia y
detalle) combina disponibilidad del servicio, actividad de sincronización y
vigencia de los datos (IND-01 a IND-07).

| Estado | Cuándo | Indicador |
|---|---|---|
| Verificando | Al iniciar, antes de la primera comprobación | «Verificando conexión…» |
| En línea | PokéAPI respondió una consulta GraphQL | «En línea» |
| Sincronizando | En línea y hay una descarga en curso | «Sincronizando…» con progreso |
| Sin conexión | No hay red o no se resuelve el servidor | «Sin conexión» |
| Servicio no disponible | Hay red, pero la API falla, tarda más de 5 s o devuelve errores | «Servicio no disponible» |

- **Disponibilidad real (IND-02).**
  [`ApiConnectivityService`](lib/core/data/api_connectivity_service.dart)
  escucha `connectivity_plus` y, con red, envía `query { __typename }` a
  PokéAPI con límite de 5 s, repetida cada 30 s. Solo una respuesta válida
  produce «En línea».
- **Sin parpadeos (IND-06).** Perder «En línea» exige dos fallos seguidos (el
  segundo a los 3 s); recuperarlo es inmediato.
- **Dimensiones separadas (§7.4).** `ConnectivityStatus` y `SyncActivity` son
  contratos distintos; «Sincronizando» solo aparece con el servicio en línea.
- **Vigencia (IND-04).** Segunda línea «Última actualización: HH:mm».
- **Accesibilidad (IND-05).** Icono, texto y color, y una etiqueta `Semantics`
  con región en vivo que TalkBack anuncia. El indicador se pinta después de
  las rutas del `Navigator` para que su `BlockSemantics` no lo oculte.

Detalle de la decisión en [ADR-0002](docs/adr/0002-disponibilidad-graphql.md).

## Imágenes sin conexión

| Decisión (PS-08) | Valor |
|---|---|
| Qué se guarda | El arte oficial de cada Pokémon guardado (o su sprite si no tiene arte) |
| Cuándo | Al guardar cada página, en segundo plano ([`CacheImagePrefetcher`](lib/features/catalog/data/catalog_image_prefetcher.dart), hasta 4 descargas a la vez); también al mostrarse una imagen nueva |
| Dónde | Carpeta de caché de la app (`pokedex_images`), con el índice de `flutter_cache_manager` |
| Límite | 1 200 imágenes ([`PokedexImageCache`](lib/core/data/pokedex_image_cache.dart)) |
| Limpieza | Al pasar el límite se borran las menos usadas; las que no se usan en 365 días caducan |
| Respaldo (OF-08) | Arte oficial → sprite → icono de Pokébola |
| Memoria (RNF-REN-04) | Cada imagen se decodifica al ancho real de la tarjeta (`memCacheWidth`) |

La precarga no forma parte de la transacción ni del estado «Sincronizando»: si
falla, la sincronización termina igual. Al volver la conexión se reintentan
las imágenes que habían fallado. En el dispositivo de prueba, 40 Pokémon
ocuparon ~6 MB y se vieron sin conexión tras un cierre forzado (PA-10).

## Funcionalidades adicionales implementadas

Además de lo mínimo pedido para el avance:

- Indicador con los cuatro estados de la entrega final («Servicio no
  disponible» y «Sincronizando», no solo Online/Offline) y la hora de la
  última actualización.
- Actualización automática del catálogo al recuperar la conexión (PA-07).
- Precarga de imágenes para verlas sin conexión aunque nunca se hayan mostrado.
- Cuadrícula responsiva de 1 a 4 columnas que se adapta al ancho y a la escala
  del texto.

Las funcionalidades complementarias del enunciado (RF-COM: PokémonCard,
animaciones Hero, temas, internacionalización, mapa, onboarding) son de la
entrega final.

## Pruebas y verificación

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Estado actual: análisis sin problemas y **59 pruebas** en verde.

| Área | Pruebas |
|---|---|
| Contratos y navegación | [contracts_test.dart](test/contracts_test.dart), [widget_test.dart](test/widget_test.dart) |
| GraphQL y paginación | [catalog_remote_source_test.dart](test/catalog_remote_source_test.dart) |
| Repositorio observable | [observable_catalog_repository_test.dart](test/observable_catalog_repository_test.dart), [drift_catalog_repository_contract_test.dart](test/data/local/drift_catalog_repository_contract_test.dart) |
| Base local | [app_database_test.dart](test/data/local/app_database_test.dart), [drift_catalog_local_store_test.dart](test/data/local/drift_catalog_local_store_test.dart) (sin duplicados, reversión), [drift_favorites_repository_test.dart](test/data/local/drift_favorites_repository_test.dart), [database_persistence_test.dart](test/data/local/database_persistence_test.dart) (reapertura), [migration_test.dart](test/drift/app_database/migration_test.dart) |
| Conectividad | [api_connectivity_service_test.dart](test/core/api_connectivity_service_test.dart), [graphql_health_check_test.dart](test/core/graphql_health_check_test.dart), [sync_activity_tracker_test.dart](test/core/sync_activity_tracker_test.dart), [connectivity_indicator_test.dart](test/app/connectivity_indicator_test.dart) |
| Pantalla del catálogo e imágenes | [catalog_page_test.dart](test/catalog_page_test.dart), [catalog_image_prefetcher_test.dart](test/catalog_image_prefetcher_test.dart) |

**Pruebas manuales en dispositivo (Samsung Galaxy A34, Android 14)**

| Escenario | Resultado |
|---|---|
| PA-04: cargar 40 Pokémon, cierre forzado, modo avión, reabrir | Los 40 siguen visibles con nombre, número y tipos |
| PA-07: quitar el modo avión sin tocar la app | «Sin conexión» → «Sincronizando…» → «En línea» y la hora se actualiza |
| PA-10: imágenes tras reinicio sin conexión | Las 40 imágenes visibles, incluidas las que nunca se mostraron con red |
| PA-12 (parcial): indicador en catálogo, favoritos, trivia y detalle | Visible y fijo en todas |

## Limitaciones conocidas

- **Funcionalidades de la entrega final:** detalle completo, favoritos en la
  interfaz (el repositorio persistente ya existe), búsqueda, filtros,
  ordenación y trivia.
- **Resiliencia:** sin reintentos automáticos con backoff (RNF-RES-02) ni
  manejo diferenciado de limitación de tasa; `sync_metadata.status` solo
  registra `success`.
- **PA-08:** no hay todavía un mecanismo documentado para simular la API caída
  con red activa.
- **OF-19 a OF-21:** la restauración de datos del catálogo alterados
  localmente no está implementada.
- **Inspector en vivo (PA-16):** la base se puede copiar con `adb run-as`, pero
  no editar en vivo desde la app.
- **Lectura del catálogo:** cada cambio relee el catálogo completo; es
  suficiente para ~1 000 Pokémon.
- **Caché de imágenes:** si Android vacía la carpeta de caché por falta de
  espacio, las imágenes se vuelven a descargar en la siguiente sincronización.
- **Gestión de estado:** `Stream` y `StreamBuilder` en lugar de Riverpod o
  BLoC (ver [Tecnologías](#tecnologías-y-justificación)).

## Decisiones de arquitectura (ADR)

| ADR | Decisión |
|---|---|
| [ADR-0001](docs/adr/0001-persistencia-drift.md) | SQLite con Drift como persistencia local |
| [ADR-0002](docs/adr/0002-disponibilidad-graphql.md) | Detectar la disponibilidad real con una consulta GraphQL |

## Uso de herramientas de IA

Utilizamos herramientas de inteligencia artificial como apoyo para elegir las
librerías que más convenían al proyecto, para saber cómo implementar ciertas
funcionalidades (por ejemplo, el almacenamiento local de los datos) y para
reconocer y evitar malas prácticas en el código. También la utilizamos para la elaboración de las documentaciones del proyecto.

## Historial por ticket

| Ticket | Qué aportó |
|---|---|
| KAN-7 / PKD-01 | Estructura por funcionalidades, navegación y contratos de dominio ([docs/architecture.md](docs/architecture.md)) |
| KAN-9 / PKD-03 | Consulta paginada del catálogo a PokéAPI por GraphQL, DTO y límite de 15 s |
| KAN-11 / PKD-05 | Pantalla del catálogo con estados de carga, vacío, error y «Reintentar»; cuadrícula de 1 a 4 columnas |
| KAN-12 / PKD-06 | Arranque sin bloqueos y «Cargar más» |
| KAN-10 / PKD-04 | `ObservableCatalogRepository`: GraphQL alimenta la fuente local y la pantalla solo la observa |
| KAN-8 / PKD-02 | Base SQLite con Drift, favoritos persistentes, metadatos y migraciones |
| KAN-13 / PKD-07 | Monitor de disponibilidad real, indicador global y actualización al reconectar |
| KAN-14 / PKD-08 | Caché de imágenes en disco y precarga para uso sin conexión |
| KAN-15 / PKD-09 | Esta documentación y los ADR |
