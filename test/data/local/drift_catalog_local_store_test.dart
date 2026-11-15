import 'dart:async';

import 'package:dart_final_project/core/database/app_database.dart';
import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/data/local/drift_catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCatalogLocalStore store;
  final updatedAt = DateTime.utc(2026, 11, 15, 10, 42, 7, 123, 456);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    store = DriftCatalogLocalStore(db);
  });

  Future<Map<String, int>> counts() async => {
    for (final table in ['pokemon', 'types', 'pokemon_types'])
      table:
          (await db
                  .customSelect('SELECT COUNT(*) AS c FROM $table')
                  .getSingle())
              .read<int>('c'),
  };

  test('emite la vista vacía al suscribirse', () async {
    final snapshot = await store.watchCatalog().first;

    expect(snapshot.items, isEmpty);
    expect(snapshot.hasMore, isFalse);
    expect(snapshot.lastUpdated, isNull);
    expect(await store.readNextOffset(), isNull);
  });

  test('guarda una página y la emite ordenada con tipos y metadatos', () async {
    final snapshots = StreamIterator(store.watchCatalog());
    addTearDown(snapshots.cancel);
    expect(await snapshots.moveNext(), isTrue);

    await store.upsertPage(
      items: [
        _pokemon(4, 'charmander', ['fire']),
        _pokemon(10001, 'sin-numero', ['normal'], nationalNumber: null),
        _pokemon(1, 'bulbasaur', ['grass', 'poison']),
      ],
      nextOffset: 20,
      updatedAt: updatedAt,
    );

    expect(await snapshots.moveNext(), isTrue);
    final snapshot = snapshots.current;
    expect(snapshot.items.map((p) => p.name), [
      'bulbasaur',
      'charmander',
      'sin-numero',
    ]);
    final bulbasaur = snapshot.items.first;
    expect(bulbasaur.id, PokemonId(1));
    expect(bulbasaur.nationalNumber, 1);
    expect(bulbasaur.types, ['grass', 'poison']);
    expect(bulbasaur.artworkUrl, Uri.parse('https://img.test/art/1.png'));
    expect(bulbasaur.spriteUrl, Uri.parse('https://img.test/sprite/1.png'));
    expect(snapshot.hasMore, isTrue);
    expect(snapshot.lastUpdated, updatedAt);
    expect(snapshot.lastUpdated!.isUtc, isTrue);
    expect(await store.readNextOffset(), 20);
  });

  test(
    'repetir la misma página no duplica registros y reemplaza los tipos',
    () async {
      final page = [
        _pokemon(1, 'bulbasaur', ['grass', 'poison']),
        _pokemon(4, 'charmander', ['fire']),
      ];
      await store.upsertPage(items: page, nextOffset: 2, updatedAt: updatedAt);
      final before = await counts();

      for (var i = 0; i < 3; i++) {
        await store.upsertPage(
          items: page,
          nextOffset: 2,
          updatedAt: updatedAt,
        );
      }
      expect(await counts(), before);
      expect(before, {'pokemon': 2, 'types': 3, 'pokemon_types': 3});

      await store.upsertPage(
        items: [
          _pokemon(4, 'charmander', ['fire', 'dragon']),
        ],
        nextOffset: null,
        updatedAt: updatedAt,
      );
      final snapshot = await store.watchCatalog().first;
      expect(snapshot.items.map((p) => p.name), ['bulbasaur', 'charmander']);
      expect(snapshot.items.last.types, ['fire', 'dragon']);
      expect(snapshot.items.first.types, ['grass', 'poison']);
      expect(snapshot.hasMore, isFalse);
      expect(await store.readNextOffset(), isNull);
    },
  );

  test(
    'un fallo dentro de la transacción no deja cambios ni emite una vista',
    () async {
      await store.upsertPage(
        items: [
          _pokemon(1, 'bulbasaur', ['grass']),
        ],
        nextOffset: 1,
        updatedAt: updatedAt,
      );
      final emitted = <CatalogSnapshot>[];
      final subscription = store.watchCatalog().listen(emitted.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(emitted, hasLength(1));
      final before = await counts();

      // El CHECK rechaza nextOffset negativo después de guardar los Pokémon.
      await expectLater(
        store.upsertPage(
          items: [
            _pokemon(1, 'cambiado', ['fire']),
            _pokemon(2, 'ivysaur', ['grass']),
          ],
          nextOffset: -1,
          updatedAt: updatedAt.add(const Duration(hours: 1)),
        ),
        throwsA(isA<Exception>()),
      );
      await pumpEventQueue();

      expect(emitted, hasLength(1));
      expect(await counts(), before);
      final current = await store.watchCatalog().first;
      expect(current.items.single.name, 'bulbasaur');
      expect(current.items.single.types, ['grass']);
      expect(current.lastUpdated, updatedAt);
      expect(await store.readNextOffset(), 1);
    },
  );
}

PokemonSummary _pokemon(
  int id,
  String name,
  List<String> types, {
  int? nationalNumber = -1,
}) => PokemonSummary(
  id: PokemonId(id),
  name: name,
  nationalNumber: nationalNumber == -1 ? id : nationalNumber,
  types: types,
  artworkUrl: Uri.parse('https://img.test/art/$id.png'),
  spriteUrl: Uri.parse('https://img.test/sprite/$id.png'),
);
