import '../../../core/data/demo_value.dart';
import '../../../core/domain/pokemon_id.dart';
import '../domain/favorites_repository.dart';

/// Doble en memoria; sus cambios se pierden al cerrar la aplicación.
final class DemoFavoritesRepository implements FavoritesRepository {
  final _ids = DemoValue<Set<PokemonId>>(Set.unmodifiable(<PokemonId>{}));

  @override
  Stream<Set<PokemonId>> watchFavoriteIds() => _ids.watch();

  @override
  Future<void> setFavorite(PokemonId id, {required bool isFavorite}) async {
    if (_ids.value.contains(id) == isFavorite) return;
    final next = Set<PokemonId>.of(_ids.value);
    if (isFavorite) {
      next.add(id);
    } else {
      next.remove(id);
    }
    _ids.update(Set.unmodifiable(next));
  }

  Future<void> dispose() => _ids.dispose();
}
