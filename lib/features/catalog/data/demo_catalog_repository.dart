import '../../../core/domain/pokemon_id.dart';
import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/pokemon_summary.dart';

/// Datos de ejemplo para probar el catálogo desde la app.
final class DemoCatalogRepository implements CatalogRepository {
  final _snapshot = CatalogSnapshot(
    items: [
      _pokemon(1, 'Bulbasaur', ['grass', 'poison']),
      _pokemon(4, 'Charmander', ['fire']),
      _pokemon(7, 'Squirtle', ['water']),
    ],
    hasMore: false,
  );

  static PokemonSummary _pokemon(int id, String name, List<String> types) {
    const sprites =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    return PokemonSummary(
      id: PokemonId(id),
      name: name,
      nationalNumber: id,
      types: types,
      artworkUrl: Uri.parse('$sprites/other/official-artwork/$id.png'),
      spriteUrl: Uri.parse('$sprites/$id.png'),
    );
  }

  @override
  Stream<CatalogSnapshot> watchCatalog() => Stream.value(_snapshot);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}
}
