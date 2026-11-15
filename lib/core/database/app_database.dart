import 'package:drift/drift.dart';

import '../../features/catalog/data/local/catalog_tables.dart';
import '../../features/favorites/data/local/favorites_table.dart';
import 'sync_metadata_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    PokemonTable,
    TypesTable,
    PokemonTypesTable,
    FavoritesTable,
    SyncMetadataTable,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // SQLite desactiva las claves foráneas en cada conexión nueva.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
