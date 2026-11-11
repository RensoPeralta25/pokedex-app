import 'catalog_snapshot.dart';

abstract interface class CatalogRepository {
  /// Cada suscriptor recibe la vista actual y sus cambios posteriores.
  /// La implementación real leerá desde persistencia local.
  Stream<CatalogSnapshot> watchCatalog();

  /// Actualiza la primera página sin borrar los datos disponibles si falla.
  /// Los cambios se entregan mediante [watchCatalog]; los errores, por el Future.
  Future<void> refresh();

  /// Agrega la siguiente página sin duplicar IDs. Sin efecto si no hay más.
  /// Los fallos se comunican por el Future; no invalidan la vista anterior.
  Future<void> loadNextPage();
}
