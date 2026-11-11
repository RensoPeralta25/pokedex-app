import '../../../core/domain/pokemon_id.dart';

abstract interface class FavoritesRepository {
  /// Emite el conjunto actual inmutable y cada cambio posterior.
  Stream<Set<PokemonId>> watchFavoriteIds();

  /// Operación idempotente: repetir el mismo valor no invierte el favorito.
  /// El Future termina cuando se guarda; si falla, conserva el estado previo.
  Future<void> setFavorite(PokemonId id, {required bool isFavorite});
}
