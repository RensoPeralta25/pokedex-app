import 'dart:collection';
import 'dart:math';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

abstract interface class CatalogImagePrefetcher {
  Future<void> prefetch(Iterable<Uri> urls);
}

final class CacheImagePrefetcher implements CatalogImagePrefetcher {
  CacheImagePrefetcher({
    required this.isCached,
    required this.download,
    this.concurrency = 4,
  });

  factory CacheImagePrefetcher.forCache(BaseCacheManager cache) =>
      CacheImagePrefetcher(
        isCached: (url) async => await cache.getFileFromCache(url) != null,
        download: (url) => cache.downloadFile(url),
      );

  final Future<bool> Function(String url) isCached;
  final Future<void> Function(String url) download;
  final int concurrency;

  @override
  Future<void> prefetch(Iterable<Uri> urls) async {
    final pending = Queue.of({for (final url in urls) url.toString()});

    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final url = pending.removeFirst();
        try {
          if (!await isCached(url)) await download(url);
        } on Object {
          // Sin red o imagen inexistente: la tarjeta usará el respaldo.
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < min(concurrency, pending.length); i++) worker(),
    ]);
  }
}
