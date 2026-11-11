import '../../../core/domain/pokemon_id.dart';
import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/pokemon_summary.dart';

/// Fixture estática: no consulta la API ni implementa persistencia.
final class DemoCatalogRepository implements CatalogRepository {
  final _snapshot = CatalogSnapshot(
    items: [
      PokemonSummary(id: PokemonId(1), name: 'Bulbasaur'),
      PokemonSummary(id: PokemonId(4), name: 'Charmander'),
      PokemonSummary(id: PokemonId(7), name: 'Squirtle'),
    ],
    hasMore: false,
  );

  @override
  Stream<CatalogSnapshot> watchCatalog() => Stream.value(_snapshot);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}
}
