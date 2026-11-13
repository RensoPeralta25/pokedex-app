import '../../domain/catalog_snapshot.dart';
import '../../domain/pokemon_summary.dart';

/// Operaciones que el adaptador de persistencia de KAN-8 debe proporcionar.
abstract interface class CatalogLocalStore {
  /// Emite el catálogo actual y los cambios después de cada escritura exitosa.
  Stream<CatalogSnapshot> watchCatalog();

  /// Devuelve null antes de la primera descarga o al agotar el catálogo.
  Future<int?> readNextOffset();

  /// Inserta o actualiza por PokemonId y conserva los demás registros.
  ///
  /// Los registros, el desplazamiento y la fecha se guardan en una transacción.
  /// Si falla, se conserva toda la vista anterior y no se emiten cambios.
  Future<void> upsertPage({
    required List<PokemonSummary> items,
    required int? nextOffset,
    required DateTime updatedAt,
  });
}
