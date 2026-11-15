import 'dart:async';

import 'package:dart_final_project/core/data/demo_value.dart';
import 'package:dart_final_project/features/catalog/data/catalog_image_prefetcher.dart';
import 'package:dart_final_project/features/catalog/data/local/catalog_local_store.dart';
import 'package:dart_final_project/features/catalog/data/observable_catalog_repository.dart';
import 'package:dart_final_project/features/catalog/data/remote/poke_api_catalog_source.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheImagePrefetcher', () {
    test('descarga solo las que faltan, una vez cada una', () async {
      final downloaded = <String>[];
      final prefetcher = CacheImagePrefetcher(
        isCached: (url) async => url.endsWith('/1.png'),
        download: (url) async => downloaded.add(url),
      );

      await prefetcher.prefetch([
        Uri.parse('https://img.test/1.png'),
        Uri.parse('https://img.test/2.png'),
        Uri.parse('https://img.test/2.png'),
        Uri.parse('https://img.test/3.png'),
      ]);

      expect(
        downloaded,
        unorderedEquals(['https://img.test/2.png', 'https://img.test/3.png']),
      );
    });

    test(
      'limita las descargas simultáneas y un error no corta las demás',
      () async {
        var running = 0;
        var maxRunning = 0;
        final downloaded = <String>[];
        final prefetcher = CacheImagePrefetcher(
          isCached: (_) async => false,
          concurrency: 2,
          download: (url) async {
            running++;
            maxRunning = running > maxRunning ? running : maxRunning;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            running--;
            if (url.endsWith('/2.png')) throw StateError('sin red');
            downloaded.add(url);
          },
        );

        await prefetcher.prefetch([
          for (var i = 1; i <= 5; i++) Uri.parse('https://img.test/$i.png'),
        ]);

        expect(maxRunning, 2);
        expect(downloaded, hasLength(4));
      },
    );
  });

  group('ObservableCatalogRepository', () {
    late _MemoryStore local;
    late _FakePrefetcher prefetcher;
    late ObservableCatalogRepository repository;

    setUp(() {
      local = _MemoryStore();
      addTearDown(local.dispose);
      prefetcher = _FakePrefetcher();
      repository = ObservableCatalogRepository(
        local: local,
        images: prefetcher,
        remote: PokeApiCatalogSource(
          request: (_, _) async => {
            'data': {
              'pokemon': [_row(1, artwork: true), _row(2, artwork: false)],
            },
          },
        ),
      );
    });

    test('precarga arte oficial o sprite de la página guardada', () async {
      await repository.refresh();

      expect(prefetcher.requested, [
        Uri.parse('https://img.test/art/1.png'),
        Uri.parse('https://img.test/sprite/2.png'),
      ]);
      expect(local.saved, 2);
    });

    test('la sincronización no espera ni falla por la precarga', () async {
      prefetcher.pending = Completer<void>();
      await repository.refresh();
      expect((await repository.watchCatalog().first).items, hasLength(2));

      prefetcher.pending!.completeError(StateError('sin red'));
      await pumpEventQueue();
    });
  });
}

Map<String, Object> _row(int id, {required bool artwork}) => {
  'id': id,
  'nationalNumber': id,
  'name': 'pokemon-$id',
  'types': [
    {
      'type': {'name': 'grass'},
    },
  ],
  'sprites': [
    {
      'sprites': {
        'front_default': 'https://img.test/sprite/$id.png',
        if (artwork)
          'other': {
            'official-artwork': {
              'front_default': 'https://img.test/art/$id.png',
            },
          },
      },
    },
  ],
};

final class _FakePrefetcher implements CatalogImagePrefetcher {
  final requested = <Uri>[];
  Completer<void>? pending;

  @override
  Future<void> prefetch(Iterable<Uri> urls) {
    requested.addAll(urls);
    return pending?.future ?? Future.value();
  }
}

final class _MemoryStore implements CatalogLocalStore {
  final _catalog = DemoValue(CatalogSnapshot(items: [], hasMore: false));
  int saved = 0;

  @override
  Stream<CatalogSnapshot> watchCatalog() => _catalog.watch();

  @override
  Future<int?> readNextOffset() async => null;

  @override
  Future<void> upsertPage({
    required List<PokemonSummary> items,
    required int? nextOffset,
    required DateTime updatedAt,
  }) async {
    saved += items.length;
    _catalog.update(CatalogSnapshot(items: items, hasMore: false));
  }

  Future<void> dispose() => _catalog.dispose();
}
