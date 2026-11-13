import '../../../core/data/demo_value.dart';
import '../../../core/domain/pokemon_id.dart';
import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/pokemon_summary.dart';

/// Datos de ejemplo para probar el catálogo desde la app.
final class DemoCatalogRepository implements CatalogRepository {
  final _catalog = DemoValue(
    CatalogSnapshot(
      items: [
        _pokemon(1, 'Bulbasaur', ['grass', 'poison']),
        _pokemon(4, 'Charmander', ['fire']),
        _pokemon(7, 'Squirtle', ['water']),
      ],
      hasMore: true,
    ),
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
  Stream<CatalogSnapshot> watchCatalog() => _catalog.watch();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {
    if (!_catalog.value.hasMore) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!_catalog.value.hasMore) return;

    _catalog.update(
      CatalogSnapshot(
        items: [
          ..._catalog.value.items,
          _pokemon(25, 'Pikachu', ['electric']),
          _pokemon(39, 'Jigglypuff', ['normal', 'fairy']),
          _pokemon(52, 'Meowth', ['normal']),
        ],
        hasMore: false,
      ),
    );
  }
}
