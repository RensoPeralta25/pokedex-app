import 'package:drift_flutter/drift_flutter.dart';

import '../core/data/demo_connectivity_service.dart';
import '../core/database/app_database.dart';
import '../core/domain/connectivity_service.dart';
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
  const AppDependencies({
    required this.catalog,
    required this.favorites,
    required this.connectivity,
  });

  factory AppDependencies.production() {
    final database = AppDatabase(driftDatabase(name: 'pokedex'));
    return AppDependencies(
      catalog: ObservableCatalogRepository(
        remote: PokeApiCatalogSource(),
        local: DriftCatalogLocalStore(database),
      ),
      favorites: DriftFavoritesRepository(database),
      // TODO(KAN-13): reemplazar por el monitor real de conectividad.
      connectivity: DemoConnectivityService(),
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
}
