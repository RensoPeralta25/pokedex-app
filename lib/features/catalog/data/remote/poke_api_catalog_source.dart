import '../../domain/pokemon_summary.dart';
import 'poke_api_graphql_client.dart';
import 'pokemon_catalog_dto.dart';

/// Página remota. El cursor sigue siendo un detalle de la capa data.
final class CatalogRemotePage {
  CatalogRemotePage({
    required List<PokemonSummary> items,
    required this.nextOffset,
  }) : items = List.unmodifiable(items);

  final List<PokemonSummary> items;
  final int? nextOffset;

  bool get hasMore => nextOffset != null;
}

/// Descarga páginas sin modificar el almacenamiento ni el estado de pantalla.
final class PokeApiCatalogSource {
  PokeApiCatalogSource({CatalogGraphqlRequest? request})
    : _request = request ?? PokeApiGraphqlClient().query;

  final CatalogGraphqlRequest _request;

  static const _catalogQuery = r'''
query CatalogPage($limit: Int!, $offset: Int!) {
  pokemon(
    where: {is_default: {_eq: true}}
    order_by: [{pokemon_species_id: asc}, {id: asc}]
    limit: $limit
    offset: $offset
  ) {
    id
    name
    nationalNumber: pokemon_species_id
    types: pokemontypes(order_by: {slot: asc}) {
      type { name }
    }
    sprites: pokemonsprites(limit: 1, order_by: {id: asc}) {
      sprites
    }
  }
}
''';

  Future<CatalogRemotePage> fetchPage({
    int offset = 0,
    int pageSize = 20,
  }) async {
    RangeError.checkNotNegative(offset, 'offset');
    RangeError.checkValueInInterval(pageSize, 1, 100, 'pageSize');

    // Un registro extra indica si existe otra página sin pedir un conteo.
    final response = await _request(_catalogQuery, {
      'limit': pageSize + 1,
      'offset': offset,
    });
    final errors = response['errors'];
    if (errors != null && errors is! List) {
      throw const FormatException('Campo errors inválido en GraphQL');
    }
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? first['message'] : null;
      throw StateError(
        message is String ? 'PokéAPI: $message' : 'Error de GraphQL en PokéAPI',
      );
    }

    final data = response['data'];
    final rows = data is Map<String, dynamic> ? data['pokemon'] : null;
    if (rows is! List || rows.length > pageSize + 1) {
      throw const FormatException('Página de Pokémon inválida');
    }

    final items = rows.take(pageSize).map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Registro de Pokémon inválido');
      }
      return PokemonCatalogDto.fromJson(row).toDomain();
    }).toList();

    return CatalogRemotePage(
      items: items,
      nextOffset: rows.length > pageSize ? offset + pageSize : null,
    );
  }
}
