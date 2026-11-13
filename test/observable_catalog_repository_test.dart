import 'dart:async';

import 'package:dart_final_project/core/data/demo_value.dart';
import 'package:dart_final_project/features/catalog/data/local/catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/data/observable_catalog_repository.dart';
import 'package:dart_final_project/features/catalog/data/remote/poke_api_catalog_source.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryCatalogStore local;
  late ObservableCatalogRepository repository;
  late DateTime now;
  late List<int> offsets;
  late Map<String, dynamic> Function(int offset) response;

  setUp(() {
    local = _MemoryCatalogStore();
    addTearDown(local.dispose);
    now = DateTime.utc(2026, 11, 12, 18);
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

  test('releer el catálogo usa datos locales y repetir la descarga actualiza por ID', () async {
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
    expect((await repository.watchCatalog().first).items, hasLength(1));
    expect(offsets, [0, 0]);
  });

  test(
    'un fallo remoto o local mantiene registros, fecha y siguiente página',
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
      now = now.add(const Duration(minutes: 1));
      await expectLater(repository.loadNextPage(), throwsFormatException);
      expect(await repository.watchCatalog().first, same(saved));
      expect(await local.readNextOffset(), 20);

      response = valid;
      local.failWrite = true;
      await expectLater(repository.loadNextPage(), throwsStateError);
      expect(await repository.watchCatalog().first, same(saved));
      expect(await local.readNextOffset(), 20);

      local.failWrite = false;
      await repository.loadNextPage();
      final updated = await repository.watchCatalog().first;
      expect(updated.items, hasLength(21));
      expect(updated.items[19].name, 'actualizado');
      expect(updated.lastUpdated, now);
      expect(updated.hasMore, isFalse);
      await repository.loadNextPage();
      expect(offsets, [0, 20, 20, 20]);
    },
  );

  test(
    'la paginación espera la actualización y usa el cursor guardado',
    () async {
      response = (offset) => offset == 0
          ? _response(List.generate(21, (index) => _row(index + 1)))
          : _response([_row(21)]);
      final pendingWrite = Completer<void>();
      local.pendingWrite = pendingWrite.future;
      final refresh = repository.refresh();
      final next = repository.loadNextPage();

      await local.writeStarted.future;
      expect(offsets, [0]);
      expect((await repository.watchCatalog().first).items, isEmpty);

      pendingWrite.complete();
      await Future.wait([refresh, next]);
      expect(offsets, [0, 20]);
      expect((await repository.watchCatalog().first).items, hasLength(21));
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

final class _MemoryCatalogStore implements CatalogLocalStore {
  final _catalog = DemoValue(CatalogSnapshot(items: [], hasMore: false));
  int? _nextOffset;
  bool failWrite = false;
  Future<void>? pendingWrite;
  final writeStarted = Completer<void>();

  @override
  Stream<CatalogSnapshot> watchCatalog() => _catalog.watch();

  @override
  Future<int?> readNextOffset() async => _nextOffset;

  @override
  Future<void> upsertPage({
    required List<PokemonSummary> items,
    required int? nextOffset,
    required DateTime updatedAt,
  }) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await pendingWrite;
    if (failWrite) throw StateError('Error al guardar');

    final records = {
      for (final pokemon in _catalog.value.items) pokemon.id: pokemon,
      for (final pokemon in items) pokemon.id: pokemon,
    };
    _nextOffset = nextOffset;
    _catalog.update(
      CatalogSnapshot(
        items: records.values.toList(),
        hasMore: nextOffset != null,
        lastUpdated: updatedAt,
      ),
    );
  }

  Future<void> dispose() => _catalog.dispose();
}
