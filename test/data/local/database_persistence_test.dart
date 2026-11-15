import 'dart:io';

import 'package:dart_final_project/core/database/app_database.dart';
import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/data/local/drift_catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:dart_final_project/features/favorites/data/local/drift_favorites_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pokedex_db_');
    addTearDown(() => directory.delete(recursive: true));
    file = File('${directory.path}${Platform.pathSeparator}pokedex.sqlite');
  });

  test(
    'catálogo, metadatos y favoritos sobreviven al reabrir la base',
    () async {
      final updatedAt = DateTime.utc(2026, 11, 15, 10, 42, 7, 123);

      final first = AppDatabase(NativeDatabase(file));
      await DriftCatalogLocalStore(first).upsertPage(
        items: [
          PokemonSummary(
            id: PokemonId(1),
            name: 'bulbasaur',
            nationalNumber: 1,
            types: ['grass', 'poison'],
            artworkUrl: Uri.parse('https://img.test/art/1.png'),
          ),
          PokemonSummary(
            id: PokemonId(4),
            name: 'charmander',
            nationalNumber: 4,
            types: ['fire'],
          ),
        ],
        nextOffset: 20,
        updatedAt: updatedAt,
      );
      await DriftFavoritesRepository(first)
          .setFavorite(PokemonId(4), isFavorite: true);
      await first.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final store = DriftCatalogLocalStore(reopened);

      final snapshot = await store.watchCatalog().first;
      expect(snapshot.items.map((p) => p.name), ['bulbasaur', 'charmander']);
      expect(snapshot.items.first.types, ['grass', 'poison']);
      expect(
        snapshot.items.first.artworkUrl,
        Uri.parse('https://img.test/art/1.png'),
      );
      expect(snapshot.hasMore, isTrue);
      expect(snapshot.lastUpdated, updatedAt);
      expect(await store.readNextOffset(), 20);
      expect(
        await DriftFavoritesRepository(reopened).watchFavoriteIds().first,
        {PokemonId(4)},
      );
    },
  );
}
