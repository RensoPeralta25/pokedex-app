import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';
import 'local/catalog_local_store.dart';
import 'remote/poke_api_catalog_source.dart';

/// Consulta PokéAPI y publica el catálogo exclusivamente desde la fuente local.
final class ObservableCatalogRepository implements CatalogRepository {
  ObservableCatalogRepository({
    required this.remote,
    required this.local,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PokeApiCatalogSource remote;
  final CatalogLocalStore local;
  final DateTime Function() _now;
  Future<void> _pending = Future.value();

  @override
  Stream<CatalogSnapshot> watchCatalog() => local.watchCatalog();

  @override
  Future<void> refresh() => _enqueue(() => _downloadAndStore(0));

  @override
  Future<void> loadNextPage() => _enqueue(() async {
    final offset = await local.readNextOffset();
    if (offset != null) await _downloadAndStore(offset);
  });

  Future<void> _downloadAndStore(int offset) async {
    final page = await remote.fetchPage(offset: offset);
    await local.upsertPage(
      items: page.items,
      nextOffset: page.nextOffset,
      updatedAt: _now().toUtc(),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    // El fallo llega al solicitante y la cola queda disponible para reintentos.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
