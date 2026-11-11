import 'package:dart_final_project/app/app_dependencies.dart';
import 'package:dart_final_project/app/pokedex_app.dart';
import 'package:dart_final_project/core/data/demo_connectivity_service.dart';
import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_repository.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:dart_final_project/features/favorites/data/demo_favorites_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La aplicación navega entre las secciones y abre el detalle', (
    tester,
  ) async {
    final dependencies = AppDependencies.demo();
    addTearDown((dependencies.favorites as DemoFavoritesRepository).dispose);
    await tester.pumpWidget(PokedexApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulbasaur'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de Bulbasaur · #1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(find.text('Mis favoritos'), findsOneWidget);
    expect(find.text('Favoritos disponibles: 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Trivia Pokémon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.catching_pokemon));
    await tester.pumpAndSettle();
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La pantalla acepta un repositorio distinto sin modificarla', (
    tester,
  ) async {
    final favorites = DemoFavoritesRepository();
    addTearDown(favorites.dispose);
    await tester.pumpWidget(
      PokedexApp(
        dependencies: AppDependencies(
          catalog: _TestCatalogRepository(),
          favorites: favorites,
          connectivity: DemoConnectivityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pikachu de prueba'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);

    await favorites.setFavorite(PokemonId(25), isFavorite: true);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(find.text('Favoritos disponibles: 1'), findsOneWidget);
  });
}

final class _TestCatalogRepository implements CatalogRepository {
  @override
  Stream<CatalogSnapshot> watchCatalog() => Stream.value(
    CatalogSnapshot(
      items: [PokemonSummary(id: PokemonId(25), name: 'Pikachu de prueba')],
      hasMore: false,
    ),
  );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}
}
