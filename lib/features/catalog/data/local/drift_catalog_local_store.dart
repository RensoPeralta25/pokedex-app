import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_metadata_table.dart';
import '../../../../core/domain/pokemon_id.dart';
import '../../domain/catalog_snapshot.dart';
import '../../domain/pokemon_summary.dart';
import 'catalog_local_store.dart';

final class DriftCatalogLocalStore implements CatalogLocalStore {
  DriftCatalogLocalStore(this._db);

  static const resourceKey = 'catalog';

  final AppDatabase _db;

  @override
  Stream<CatalogSnapshot> watchCatalog() {
    // Drift vuelve a emitir esta consulta al confirmarse cualquier escritura
    // sobre estas tablas; cada emisión relee el catálogo completo.
    final changes = _db.customSelect(
      'SELECT 1',
      readsFrom: {
        _db.pokemonTable,
        _db.pokemonTypesTable,
        _db.syncMetadataTable,
      },
    );
    return changes.watch().asyncMap((_) => _readSnapshot());
  }

  @override
  Future<int?> readNextOffset() async => (await _readMetadata())?.nextOffset;

  @override
  Future<void> upsertPage({
    required List<PokemonSummary> items,
    required int? nextOffset,
    required DateTime updatedAt,
  }) {
    final utc = updatedAt.toUtc();
    final ids = [for (final pokemon in items) pokemon.id.value];
    final typeNames = {for (final pokemon in items) ...pokemon.types};

    return _db.transaction(() async {
      await _db.batch((batch) {
        if (items.isNotEmpty) {
          batch.insertAll(_db.typesTable, [
            for (final name in typeNames)
              TypesTableCompanion.insert(name: name),
          ], mode: InsertMode.insertOrIgnore);

          // ON CONFLICT DO UPDATE, no INSERT OR REPLACE: REPLACE borra la fila
          // y dispararía la cascada sobre pokemon_types.
          batch.insertAllOnConflictUpdate(_db.pokemonTable, [
            for (final pokemon in items)
              PokemonTableCompanion.insert(
                id: Value(pokemon.id.value),
                name: pokemon.name,
                nationalNumber: Value(pokemon.nationalNumber),
                artworkUrl: Value(pokemon.artworkUrl?.toString()),
                spriteUrl: Value(pokemon.spriteUrl?.toString()),
                updatedAt: utc,
              ),
          ]);

          batch.deleteWhere(
            _db.pokemonTypesTable,
            (row) => row.pokemonId.isIn(ids),
          );
          batch.insertAll(_db.pokemonTypesTable, [
            for (final pokemon in items)
              for (final (index, type) in pokemon.types.indexed)
                PokemonTypesTableCompanion.insert(
                  pokemonId: pokemon.id.value,
                  slot: index + 1,
                  typeName: type,
                ),
          ]);
        }

        batch.insertAllOnConflictUpdate(_db.syncMetadataTable, [
          SyncMetadataTableCompanion.insert(
            resourceKey: resourceKey,
            lastSuccessAt: Value(utc),
            nextOffset: Value(nextOffset),
            status: SyncStatus.success,
          ),
        ]);
      });
    });
  }

  /// Se lee en una transacción para no mezclar dos estados de la base.
  Future<CatalogSnapshot> _readSnapshot() => _db.transaction(() async {
    final pokemon =
        await (_db.select(_db.pokemonTable)..orderBy([
              (row) => OrderingTerm(
                expression: row.nationalNumber,
                nulls: NullsOrder.last,
              ),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    final typeRows =
        await (_db.select(_db.pokemonTypesTable)..orderBy([
              (row) => OrderingTerm.asc(row.pokemonId),
              (row) => OrderingTerm.asc(row.slot),
            ]))
            .get();
    final metadata = await _readMetadata();

    final typesByPokemon = <int, List<String>>{};
    for (final row in typeRows) {
      (typesByPokemon[row.pokemonId] ??= []).add(row.typeName);
    }

    return CatalogSnapshot(
      items: [
        for (final row in pokemon)
          PokemonSummary(
            id: PokemonId(row.id),
            name: row.name,
            nationalNumber: row.nationalNumber,
            types: typesByPokemon[row.id] ?? const [],
            artworkUrl: _parseUri(row.artworkUrl),
            spriteUrl: _parseUri(row.spriteUrl),
          ),
      ],
      hasMore: metadata?.nextOffset != null,
      lastUpdated: metadata?.lastSuccessAt?.toUtc(),
    );
  });

  Future<SyncMetadataRow?> _readMetadata() => (_db.select(
    _db.syncMetadataTable,
  )..where((row) => row.resourceKey.equals(resourceKey))).getSingleOrNull();

  static Uri? _parseUri(String? value) =>
      value == null ? null : Uri.tryParse(value);
}
