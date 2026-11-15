import 'package:drift_flutter/drift_flutter.dart';

import '../core/data/api_connectivity_service.dart';
import '../core/data/demo_connectivity_service.dart';
import '../core/data/pokedex_image_cache.dart';
import '../core/data/sync_activity_tracker.dart';
import '../core/database/app_database.dart';
import '../core/domain/connectivity_service.dart';
import '../core/domain/sync_activity_monitor.dart';
import '../features/catalog/data/catalog_image_prefetcher.dart';
import '../features/catalog/data/demo_catalog_repository.dart';
import '../features/catalog/data/local/drift_catalog_local_store.dart';
import '../features/catalog/data/observable_catalog_repository.dart';
import '../features/catalog/data/remote/poke_api_catalog_source.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/favorites/data/demo_favorites_repository.dart';
import '../features/favorites/data/local/drift_favorites_repository.dart';
import '../features/favorites/domain/favorites_repository.dart';

/// Punto de composición: las pantallas reciben contratos, no crean servicios.
final class AppDependencies {
  AppDependencies({
    required this.catalog,
    required this.favorites,
    required this.connectivity,
    SyncActivityMonitor? syncActivity,
  }) : syncActivity = syncActivity ?? SyncActivityTracker();

  factory AppDependencies.production() {
    final database = AppDatabase(driftDatabase(name: 'pokedex'));
    final syncActivity = SyncActivityTracker();
    return AppDependencies(
      catalog: ObservableCatalogRepository(
        remote: PokeApiCatalogSource(),
        local: DriftCatalogLocalStore(database),
        activity: syncActivity,
        images: CacheImagePrefetcher.forCache(PokedexImageCache.instance),
      ),
      favorites: DriftFavoritesRepository(database),
      connectivity: ApiConnectivityService.forDevice(
        Uri.https('graphql.pokeapi.co', '/v1beta2'),
      ),
      syncActivity: syncActivity,
    );
  }

  factory AppDependencies.demo() => AppDependencies(
    catalog: DemoCatalogRepository(),
    favorites: DemoFavoritesRepository(),
    connectivity: DemoConnectivityService(),
  );

  final CatalogRepository catalog;
  final FavoritesRepository favorites;
  final ConnectivityService connectivity;
  final SyncActivityMonitor syncActivity;
}
