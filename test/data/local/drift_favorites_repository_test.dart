import 'dart:async';

import 'package:dart_final_project/core/database/app_database.dart';
import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/data/local/drift_catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:dart_final_project/features/favorites/data/local/drift_favorites_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftFavoritesRepository favorites;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    now = DateTime.utc(2026, 11, 15, 9);
    favorites = DriftFavoritesRepository(db, now: () => now);
  });

  Future<List<FavoriteRow>> rows() => db.select(db.favoritesTable).get();

  test('agregar es idempotente y conserva la fecha original', () async {
    await favorites.setFavorite(PokemonId(25), isFavorite: true);
    now = now.add(const Duration(hours: 1));
    await favorites.setFavorite(PokemonId(25), isFavorite: true);

    final saved = await rows();
    expect(saved, hasLength(1));
    expect(saved.single.createdAt, DateTime.utc(2026, 11, 15, 9));
    expect(await favorites.watchFavoriteIds().first, {PokemonId(25)});
  });

  test('eliminar quita el favorito y repetirlo no falla', () async {
    await favorites.setFavorite(PokemonId(1), isFavorite: true);
    await favorites.setFavorite(PokemonId(4), isFavorite: true);

    await favorites.setFavorite(PokemonId(1), isFavorite: false);
    await favorites.setFavorite(PokemonId(1), isFavorite: false);

    expect(await favorites.watchFavoriteIds().first, {PokemonId(4)});
  });

  test('varios observadores reciben el estado actual y los cambios', () async {
    final first = StreamIterator(favorites.watchFavoriteIds());
    final second = StreamIterator(favorites.watchFavoriteIds());
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    expect(await first.moveNext(), isTrue);
    expect(await second.moveNext(), isTrue);
    expect(first.current, isEmpty);

    await favorites.setFavorite(PokemonId(7), isFavorite: true);

    expect(await first.moveNext(), isTrue);
    expect(await second.moveNext(), isTrue);
    expect(first.current, {PokemonId(7)});
    expect(second.current, {PokemonId(7)});
    expect(() => first.current.add(PokemonId(1)), throwsUnsupportedError);
  });

  test('la sincronización del catálogo no altera favoritos, ni siquiera de IDs '
      'que aún no están en el catálogo local', () async {
    await favorites.setFavorite(PokemonId(1), isFavorite: true);
    await favorites.setFavorite(PokemonId(150), isFavorite: true);
    final before = await rows();

    final catalog = DriftCatalogLocalStore(db);
    await catalog.upsertPage(
      items: [
        PokemonSummary(id: PokemonId(1), name: 'bulbasaur', types: ['grass']),
      ],
      nextOffset: 20,
      updatedAt: now,
    );
    await catalog.upsertPage(
      items: [
        PokemonSummary(id: PokemonId(1), name: 'cambiado', types: ['fire']),
      ],
      nextOffset: null,
      updatedAt: now,
    );

    final after = await rows();
    expect(
      after.map((r) => (r.pokemonId, r.createdAt)),
      before.map((r) => (r.pokemonId, r.createdAt)),
    );
    expect(await favorites.watchFavoriteIds().first, {
      PokemonId(1),
      PokemonId(150),
    });
  });
}
