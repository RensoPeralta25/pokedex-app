import 'dart:async';

import 'package:dart_final_project/core/database/app_database.dart';
import 'package:dart_final_project/features/catalog/data/local/drift_catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/data/observable_catalog_repository.dart';
import 'package:dart_final_project/features/catalog/data/remote/poke_api_catalog_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCatalogLocalStore local;
  late ObservableCatalogRepository repository;
  late DateTime now;
  late List<int> offsets;
  late Map<String, dynamic> Function(int offset) response;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    local = DriftCatalogLocalStore(db);
    now = DateTime.utc(2026, 11, 15, 18);
    offsets = [];
    response = (offset) => _response([_row(offset + 1)]);
    repository = ObservableCatalogRepository(
      local: local,
      remote: PokeApiCatalogSource(
        request: (_, variables) async {
          final offset = variables['offset']! as int;
          offsets.add(offset);
          return response(offset);
        },
      ),
      now: () => now,
    );
  });

  test('refresh guarda desde GraphQL y repetirlo actualiza por ID', () async {
    final snapshots = StreamIterator(repository.watchCatalog());
    addTearDown(snapshots.cancel);
    expect(await snapshots.moveNext(), isTrue);
    expect(snapshots.current.items, isEmpty);
    expect(offsets, isEmpty);

    await repository.refresh();
    expect(await snapshots.moveNext(), isTrue);
    expect(snapshots.current.items.single.name, 'pokemon-1');
    expect(snapshots.current.lastUpdated, now);

    now = now.add(const Duration(minutes: 1));
    response = (_) => _response([_row(1, name: 'bulbasaur')]);
    await repository.refresh();
    expect(await snapshots.moveNext(), isTrue);
    expect(snapshots.current.items.single.name, 'bulbasaur');
    expect(snapshots.current.lastUpdated, now);
    expect(offsets, [0, 0]);
  });

  test(
    'una respuesta inválida conserva datos, fecha y desplazamiento',
    () async {
      response = (offset) => offset == 0
          ? _response(List.generate(21, (index) => _row(index + 1)))
          : _response([_row(20, name: 'actualizado'), _row(21)]);
      await repository.refresh();
      final saved = await repository.watchCatalog().first;
      expect(saved.items, hasLength(20));
      expect(saved.hasMore, isTrue);

      final valid = response;
      response = (_) => {
        'data': {
          'pokemon': [null],
        },
      };
      final failedAt = now.add(const Duration(minutes: 1));
      now = failedAt;
      await expectLater(repository.loadNextPage(), throwsFormatException);
      final afterFailure = await repository.watchCatalog().first;
      expect(afterFailure.items.map((p) => p.id), saved.items.map((p) => p.id));
      expect(afterFailure.lastUpdated, saved.lastUpdated);
      expect(await local.readNextOffset(), 20);

      response = valid;
      await repository.loadNextPage();
      final updated = await repository.watchCatalog().first;
      expect(updated.items, hasLength(21));
      expect(updated.items[19].name, 'actualizado');
      expect(updated.lastUpdated, failedAt);
      expect(updated.hasMore, isFalse);

      await repository.loadNextPage();
      expect(offsets, [0, 20, 20]);
    },
  );

  test(
    'la paginación espera a refresh y usa el desplazamiento guardado',
    () async {
      response = (offset) => offset == 0
          ? _response(List.generate(21, (index) => _row(index + 1)))
          : _response([_row(21)]);

      await Future.wait([repository.refresh(), repository.loadNextPage()]);

      expect(offsets, [0, 20]);
      final snapshot = await repository.watchCatalog().first;
      expect(snapshot.items, hasLength(21));
      expect(snapshot.hasMore, isFalse);
    },
  );
}

Map<String, dynamic> _response(List<Map<String, Object>> rows) => {
  'data': {'pokemon': rows},
};

Map<String, Object> _row(int id, {String? name}) => {
  'id': id,
  'nationalNumber': id,
  'name': name ?? 'pokemon-$id',
  'types': [
    {
      'type': {'name': 'grass'},
    },
  ],
  'sprites': [],
};
