import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:dart_final_project/features/favorites/data/demo_favorites_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El ID es positivo y tiene igualdad por valor entre módulos', () {
    expect(() => PokemonId(0), throwsArgumentError);
    expect(() => PokemonId(-1), throwsArgumentError);
    expect(PokemonId(25), PokemonId(25));
    expect({PokemonId(25), PokemonId(25)}, hasLength(1));
  });

  test('Una vista de catálogo no puede modificarse desde fuera', () {
    final source = [PokemonSummary(id: PokemonId(1), name: 'Bulbasaur')];
    final snapshot = CatalogSnapshot(items: source, hasMore: false);
    source.clear();
    expect(snapshot.items, hasLength(1));
    expect(() => snapshot.items.clear(), throwsUnsupportedError);
  });

  test('Favoritos emite el estado inicial y cambios idempotentes', () async {
    final repository = DemoFavoritesRepository();
    addTearDown(repository.dispose);
    final id = PokemonId(25);
    final observed = expectLater(
      repository.watchFavoriteIds(),
      emitsInOrder([
        isEmpty,
        equals({id}),
        isEmpty,
      ]),
    );

    await repository.setFavorite(id, isFavorite: true);
    await repository.setFavorite(PokemonId(25), isFavorite: true);
    await repository.setFavorite(id, isFavorite: false);
    await observed;
  });

  test('Varios observadores reciben el valor actual inmutable', () async {
    final repository = DemoFavoritesRepository();
    addTearDown(repository.dispose);
    final id = PokemonId(4);
    final first = expectLater(
      repository.watchFavoriteIds(),
      emitsInOrder([
        isEmpty,
        equals({id}),
      ]),
    );
    final second = expectLater(
      repository.watchFavoriteIds(),
      emitsInOrder([
        isEmpty,
        equals({id}),
      ]),
    );
    await repository.setFavorite(id, isFavorite: true);
    await Future.wait([first, second]);

    final latest = await repository.watchFavoriteIds().first;
    expect(latest, {id});
    expect(() => latest.clear(), throwsUnsupportedError);
  });
}
