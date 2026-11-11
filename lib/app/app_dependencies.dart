import '../core/data/demo_connectivity_service.dart';
import '../core/domain/connectivity_service.dart';
import '../features/catalog/data/demo_catalog_repository.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/favorites/data/demo_favorites_repository.dart';
import '../features/favorites/domain/favorites_repository.dart';

/// Punto de composición: las pantallas reciben contratos, no crean servicios.
final class AppDependencies {
  const AppDependencies({
    required this.catalog,
    required this.favorites,
    required this.connectivity,
  });

  factory AppDependencies.demo() => AppDependencies(
    catalog: DemoCatalogRepository(),
    favorites: DemoFavoritesRepository(),
    connectivity: DemoConnectivityService(),
  );

  final CatalogRepository catalog;
  final FavoritesRepository favorites;
  final ConnectivityService connectivity;
}
