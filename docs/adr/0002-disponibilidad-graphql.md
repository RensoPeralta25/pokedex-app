# ADR-0002 — Detectar la disponibilidad real con una consulta GraphQL

- **Estado:** aceptada
- **Fecha:** 15/11/2026
- **Ticket:** KAN-13 / PKD-07
- **Requisitos:** IND-01 a IND-07, OF-11, OF-12, OF-14, PA-07, PA-12; §7.4

## Contexto

El indicador global debe decir si la app puede obtener datos de PokéAPI, no
solo si el teléfono tiene Wi-Fi o datos móviles (IND-02). Hay casos comunes
en los que hay red pero no servicio: un Wi-Fi sin salida a Internet, un portal
cautivo o la API caída. Además:

- el estado debe actualizarse solo ante cambios de red y de disponibilidad
  (IND-03);
- no debe parpadear ante fallos breves (IND-06);
- la disponibilidad y la actividad de sincronización deben modelarse por
  separado para evitar estados contradictorios como «sin conexión y
  sincronizando» (§7.4);
- al recuperar el servicio, la app debe actualizarse sola (PA-07).

## Alternativas consideradas

| Opción | A favor | En contra |
|---|---|---|
| Solo `connectivity_plus` | Inmediato, sin tráfico | Dice si hay una interfaz de red, no si PokéAPI responde: incumple IND-02 |
| Ping ICMP o resolución DNS | Barato | No prueba que la API GraphQL funcione; ICMP suele estar bloqueado |
| Usar la consulta del catálogo como comprobación | Sin peticiones extra | Descarga 21 Pokémon cada vez; mezcla disponibilidad con sincronización y escribiría en la base |
| **`connectivity_plus` + `query { __typename }`** | Reacciona al instante a cambios de red y confirma con la misma API; la respuesta pesa ~40 bytes | Una dependencia nativa más; tráfico periódico mínimo |

## Decisión

[`ApiConnectivityService`](../../lib/core/data/api_connectivity_service.dart):

1. Escucha los cambios de red de `connectivity_plus`. Sin ninguna interfaz de
   red pasa a `offline` de inmediato, sin consultar la API.
2. Con red, envía `query { __typename }` al mismo endpoint de PokéAPI con un
   límite de **5 s**
   ([`checkGraphqlService`](../../lib/core/data/graphql_health_check.dart)):
   - HTTP 200 con `data` y sin `errors` → `online`;
   - fallo de DNS o red inalcanzable → `offline`;
   - timeout, HTTP distinto de 200, `errors` o conexión rechazada →
     `serviceUnavailable`.
3. Repite la comprobación cada **30 s** mientras haya red.
4. Para perder `online` exige **dos fallos seguidos** (el segundo a los 3 s);
   recuperarlo es inmediato.
5. La actividad de sincronización es otro contrato (`SyncActivityMonitor`); el
   indicador muestra «Sincronizando» solo si el servicio está `online`.
6. `CatalogPage` llama a `refresh()` cuando el estado pasa a `online` desde
   `offline` o `serviceUnavailable`.

## Consecuencias

**Positivas**
- Nunca se muestra «En línea» sin una respuesta GraphQL válida.
- Se distinguen «Sin conexión» y «Servicio no disponible».
- La reconexión actualiza el catálogo sin intervención (PA-07; probado en un
  Samsung Galaxy A34: «Sin conexión» en ≤ 3 s y vuelta a «En línea» en ~4 s).
- El monitor recibe la red y la comprobación por constructor, por lo que se
  prueba con dobles y con un servidor HTTP local.

**Negativas / a vigilar**
- Tráfico periódico: ~40 bytes cada 30 s mientras haya red.
- Una caída de la API con red activa puede tardar hasta ~33 s en reflejarse
  (intervalo + confirmación).
- Una dependencia nativa adicional (`connectivity_plus`).
- Pendiente para la entrega final: un mecanismo documentado para simular la
  API caída con red activa (PA-08) y reintentos con backoff (RNF-RES-02).
