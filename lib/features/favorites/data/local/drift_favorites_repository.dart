import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/pokemon_id.dart';
import '../../domain/favorites_repository.dart';

final class DriftFavoritesRepository implements FavoritesRepository {
  DriftFavoritesRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<Set<PokemonId>> watchFavoriteIds() => _db
      .select(_db.favoritesTable)
      .watch()
      .map(
        (rows) => Set<PokemonId>.unmodifiable({
          for (final row in rows) PokemonId(row.pokemonId),
        }),
      )
      .distinct(_sameIds);

  @override
  Future<void> setFavorite(PokemonId id, {required bool isFavorite}) async {
    if (isFavorite) {
      // insertOrIgnore conserva el created_at original al repetir la operación.
      await _db
          .into(_db.favoritesTable)
          .insert(
            FavoritesTableCompanion.insert(
              pokemonId: Value(id.value),
              createdAt: _now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(
        _db.favoritesTable,
      )..where((row) => row.pokemonId.equals(id.value))).go();
    }
  }

  static bool _sameIds(Set<PokemonId> a, Set<PokemonId> b) =>
      a.length == b.length && a.containsAll(b);
}
