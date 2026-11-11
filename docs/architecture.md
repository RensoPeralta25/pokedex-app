# KAN-7 / PKD-01 — Base y contratos entre módulos

Estado: base implementada; acuerdos propuestos para revisión de ambos integrantes.
La participación verificable de ambos sigue pendiente: no se atribuyen commits ni
aprobaciones a alguien que no ha intervenido.

## Alcance

Proyecto ejecutable con navegación inicial Catálogo → Detalle y pestañas Catálogo,
Favoritos y Trivia. Las pantallas son mínimas para verificar la estructura y la
inyección. Los datos demo son explícitos y no requieren red.

No incluye el modelo de base de datos, GraphQL, sincronización, favoritos
persistentes, imágenes, filtros ni reglas de trivia. Esos cambios corresponden a
los siguientes tickets. No se crean capas vacías para funcionalidades aún no
implementadas; cada una incorporará domain/data cuando lo necesite.

## Organización y dirección de dependencias

| Ruta | Responsabilidad | Dependencias permitidas |
| --- | --- | --- |
| `lib/app/` | Composición, tema y navegación raíz | Flutter, contratos e implementaciones concretas |
| `lib/core/domain/` | Identidad y contrato de conectividad compartidos | Dart |
| `lib/core/data/` | Dobles de servicios compartidos | Dart y core/domain |
| `lib/features/catalog/domain/` | Entidades y contrato de catálogo | Dart y core/domain |
| `lib/features/catalog/data/` | Adaptadores de catálogo; ahora solo demo | Dominio; en otros tickets, red/persistencia |
| `lib/features/catalog/presentation/` | Vista inicial del catálogo | Flutter y contratos/entidades |
| `lib/features/favorites/` | Contrato, doble y vista mínima de favoritos | Misma separación domain/data/presentation |
| `lib/features/pokemon_detail/presentation/` | Destino inicial del detalle | Flutter y PokemonSummary |
| `lib/features/trivia/presentation/` | Destino reservado para trivia | Flutter |

El dominio no importa Flutter, GraphQL, bases de datos ni las capas data o
presentation. Las pantallas no instancian repositorios. `AppDependencies` reúne
las implementaciones en un solo punto y las entrega por constructor; se puede
inyectar un doble o adaptador real sin cambiar la pantalla. No hace falta agregar
un contenedor de servicios ni paquetes de gestión de estado en este ticket.

## Acuerdos de contratos

| Contrato | Acuerdo |
| --- | --- |
| `PokemonId` | Entero positivo, identidad por valor. Se usará el ID del recurso Pokémon, no el de especie, forma ni posición en una lista. Todo adaptador debe normalizar sus IDs a este tipo. |
| `PokemonSummary` | ID y nombre de un Pokémon, inmutables. Es el mínimo para navegar y compartir identidad. Campos de imagen, tipos y detalle se añadirán en sus tickets. |
| `CatalogSnapshot` | Lista inmutable de elementos disponibles, `hasMore` y `lastUpdated` opcional. La implementación real registrará la fecha UTC de la última actualización remota exitosa. `null` significa que no hay una actualización registrada. |
| `CatalogRepository.watchCatalog()` | Cada suscripción recibe el estado actual y las actualizaciones posteriores. En producción, la fuente observable será el almacenamiento local. Una vista vacía es válida. |
| `refresh()` | Actualiza la primera página y reinicia la paginación al completarse. Conserva la vista previa si falla. La reconciliación de páginas posteriores se implementará/documentará en PKD-04. |
| `loadNextPage()` | Solicita la próxima página; evita duplicados por ID. Si `hasMore` es falso, no hace nada. El repositorio real serializará las solicitudes concurrentes de páginas/actualización. |
| Errores de actualización | Los Futures fallan con una excepción; el consumidor decide cómo mostrarla. No se emite un catálogo vacío para ocultar un fallo de red. Errores de lectura local pueden emitirse por el Stream. Los tipos específicos de error se definirán con los adaptadores reales. |
| `FavoritesRepository.watchFavoriteIds()` | Conjunto actual inmutable y cambios posteriores, para todos los observadores. Los favoritos se relacionan por `PokemonId`. |
| `setFavorite(id, isFavorite: ...)` | Operación idempotente, no toggle: repetir `true` no elimina el favorito. En producción termina al persistir; un fallo mantiene el estado previo. |
| `ConnectivityService.watchStatus()` | Estado actual y cambios: `unknown`, `online`, `offline`. Disponibilidad de red no garantiza que GraphQL responda. |

Los consumidores cancelan sus suscripciones al salir. `StreamBuilder` lo hace por
las pantallas. El punto de composición posee los servicios; un futuro adaptador
que mantenga recursos añadirá su limpieza allí, no en el dominio.

## Implementaciones de demostración

- `DemoCatalogRepository`: tres Pokémon estáticos, sin más páginas. Cada lectura
  entrega la misma vista; refresh y loadNextPage no hacen nada.
- `DemoFavoritesRepository`: doble en memoria para verificar el contrato observable.
  No ofrece persistencia ni botones funcionales de favoritos en la aplicación.
  Expone dispose para liberar su controlador en las pruebas.
- `DemoConnectivityService`: emite unknown; no consulta el dispositivo.

Los Streams estáticos de catálogo y conectividad terminan después de su único
valor, porque estos dobles no generan cambios. Los adaptadores reales deberán
mantener las suscripciones para publicar cambios durante su ciclo de vida.

## Colaboración y criterios de aceptación

| Criterio de KAN-7 | Evidencia o pendiente |
| --- | --- |
| Proyecto ejecutable con navegación inicial | AppShell y prueba de navegación a detalle y entre tres pestañas |
| Dominio independiente | Archivos domain en Dart puro, sin imports de infraestructura |
| Entidades, IDs, observación, actualización, favoritos y conectividad | Contratos anteriores y sus comentarios en código; pendiente revisión conjunta |
| Implementaciones sustituibles | Inyección por constructor y prueba con otro catálogo |
| Contribuciones verificables de ambos | Pendiente participación real del segundo integrante |

Reparto sugerido para completar este mismo ticket: un integrante implementa la
base; el otro revisa los contratos, ejecuta las pruebas y aporta un commit con
ajustes justificados o deja su revisión en el PR. No marcar este último criterio
como completado hasta contar con esa evidencia y el acuerdo de ambos.

## Comprobación local

Ejecutar desde la raíz del repositorio:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

Las pruebas cubren identidad compartida, inmutabilidad, observación de favoritos,
idempotencia, navegación y sustitución del repositorio desde la raíz. El dominio
se puede revisar comprobando que sus imports solo apuntan a Dart y a otros archivos de dominio.

## Resultado de verificación en esta sesión

- Análisis estático directo con el Dart del SDK instalado: sin problemas.
- Formato de `lib/` y `test/`: sin cambios pendientes.
- Comprobación ejecutable directa en Dart: identidad, inmutabilidad, varios
  observadores, suscriptor tardío, idempotencia, eliminación, catálogo demo y
  conectividad correctos.
- Las pruebas Flutter están escritas, pero el ejecutor no pudo iniciarse porque
  este entorno impide abrir su socket local. No se considera verificada la
  navegación en ejecución hasta correr `flutter test` fuera de esta restricción.
