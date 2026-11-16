# ADR-0001 — SQLite con Drift como persistencia local

- **Estado:** aceptada
- **Fecha:** 15/11/2026
- **Ticket:** KAN-8 / PKD-02
- **Requisitos:** OF-02, OF-04, OF-10, OF-16, OF-17; PS-01, PS-05, PS-06,
  PS-09–PS-11; RNF-RES-04; RNF-REN-02, RNF-REN-03; PA-04, PA-13

## Contexto

La app es Offline-First: la interfaz debe construirse siempre desde datos
persistidos localmente, y PokéAPI solo actualiza esa persistencia (OF-16). El
enunciado aclara que una caché de respuestas no basta. Se necesita un modelo
estructurado y consultable (entidades, relaciones e índices) que soporte
búsquedas y filtros offline. Las escrituras deben ser transaccionales y la
interfaz debe enterarse de los cambios sin recargar.

Antes de esta decisión ya existía el contrato `CatalogLocalStore` (KAN-10). Ese
contrato exige:

- emitir la vista actual y cada cambio;
- guardar registros, desplazamiento y fecha en una sola transacción;
- no emitir nada si el guardado falla.

Hacía falta una tecnología que lo implementara.

## Alternativas consideradas

| Opción | A favor | En contra |
|---|---|---|
| **Drift (SQLite)** | SQL real con claves, `CHECK`, foreign keys e índices; consultas reactivas (`watch`) que emiten solo tras confirmar una transacción; migraciones versionadas con esquemas exportados y pruebas generadas; tipado en compilación; ejecución en un isolate de fondo; pruebas en memoria sin dispositivo; recomendado por el enunciado | Requiere generación de código (`build_runner`); curva de aprendizaje mayor que un almacén clave-valor |
| sqflite | SQLite sin generación de código | Habría que escribir a mano la observación de cambios, el mapeo y la infraestructura de migraciones; SQL en texto sin verificación de tipos |
| Hive / Isar | Rápidos y sencillos para objetos | Modelo no relacional: relaciones Pokémon–tipo, unicidad compuesta y filtros con índices son menos naturales; Isar tiene mantenimiento incierto |
| Caché normalizada de un cliente GraphQL | Viene con el cliente | El enunciado (§6.5) indica que no sustituye la persistencia estructurada: no hay consultas nuevas offline, ni datos del usuario, ni política explícita de vigencia |

## Decisión

Usar **Drift** sobre SQLite, con `drift_flutter` para abrir la base en el
dispositivo:

- `AppDatabase` vive en `lib/core/database/` y reúne las tablas que define cada
  funcionalidad en su capa `data/local/`.
- Esquema v1 normalizado: `pokemon`, `types`, `pokemon_types`, `favorites`,
  `sync_metadata`, con tres índices documentados en el [README](../../README.md#persistencia-local).
- Upsert por `PokemonId` dentro de una transacción. Los tipos de cada Pokémon
  recibido se reemplazan.
- `favorites` sin clave foránea hacia `pokemon`, para que la sincronización del
  catálogo nunca altere datos del usuario (PS-11).
- Fechas como texto ISO-8601 en UTC.

Versiones resueltas: `drift` 2.35.4, `drift_flutter` 0.3.1, `drift_dev` 2.35.3
y `build_runner` 2.17.1 (las dos últimas solo en desarrollo).

## Consecuencias

**Positivas**
- La pantalla recibe solo datos confirmados. Un fallo remoto o de escritura no
  borra ni mezcla la vista (OF-04, RNF-RES-04).
- Tres sincronizaciones de la misma página no cambian los conteos (PA-13).
  Una prueba automática lo comprueba.
- Los índices preparan búsqueda y filtros offline (RF-CAT-03, RF-FIL-01).
- Las migraciones tienen un procedimiento y una prueba que valida el esquema.
- Los adaptadores se prueban con SQLite real en memoria, sin emulador.

**Negativas / a vigilar**
- Hay código generado (`*.g.dart`, `test/drift/.../generated`). Se versiona y
  no se edita a mano; al cambiar tablas hay que regenerarlo.
- `watchCatalog()` relee el catálogo completo en cada cambio. Para el tamaño de
  la Pokédex (~1 000 registros) es aceptable; si creciera, convendría paginar
  la lectura local.
- Para revisar la base del dispositivo hay que usar la versión debug:
  `adb exec-out run-as com.example.dart_final_project cat app_flutter/pokedex.sqlite`
  copia el archivo para abrirlo con cualquier visor de SQLite. Editar datos en
  vivo (PA-16) queda por resolver para la entrega final.
