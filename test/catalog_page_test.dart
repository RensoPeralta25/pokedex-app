import 'dart:async';

import 'package:dart_final_project/core/domain/pokemon_id.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_repository.dart';
import 'package:dart_final_project/features/catalog/domain/catalog_snapshot.dart';
import 'package:dart_final_project/features/catalog/domain/pokemon_summary.dart';
import 'package:dart_final_project/features/catalog/presentation/catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra carga hasta que llega el catálogo vacío', (
    tester,
  ) async {
    final snapshots = StreamController<CatalogSnapshot>();
    addTearDown(snapshots.close);
    final repository = _CatalogRepository(watch: () => snapshots.stream);

    await tester.pumpWidget(
      MaterialApp(home: CatalogPage(repository: repository)),
    );
    expect(find.bySemanticsLabel('Cargando catálogo'), findsOneWidget);

    snapshots.add(CatalogSnapshot(items: [], hasMore: false));
    await tester.pumpAndSettle();
    expect(find.text('No hay Pokémon disponibles.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('reintenta tras un error de lectura o de actualización', (
    tester,
  ) async {
    var refreshed = 0;
    final repository = _CatalogRepository(
      watch: () => refreshed == 2
          ? Stream.value(_snapshot())
          : Stream.error(StateError('Fallo de lectura')),
      refreshCatalog: () async {
        refreshed++;
        if (refreshed == 1) throw StateError('Fallo de actualización');
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: CatalogPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar el catálogo.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Venusaur'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(refreshed, 2);
  });

  testWidgets(
    'adapta la cuadrícula y presenta el número nacional y los tipos',
    (tester) async {
      final repository = _CatalogRepository(
        watch: () => Stream.value(_snapshot()),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CatalogPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final grid = find.byType(GridView);
      final narrow =
          tester.widget<GridView>(grid).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(narrow.crossAxisCount, 1);
      expect(find.text('#003'), findsOneWidget);
      expect(find.text('Planta · Veneno'), findsOneWidget);
      expect(find.byIcon(Icons.catching_pokemon), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(1000, 640));
      await tester.pumpAndSettle();
      final wide =
          tester.widget<GridView>(grid).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(wide.crossAxisCount, greaterThan(narrow.crossAxisCount));
      expect(tester.takeException(), isNull);
    },
  );
}

CatalogSnapshot _snapshot() => CatalogSnapshot(
  items: [
    PokemonSummary(
      id: PokemonId(10033),
      nationalNumber: 3,
      name: 'Venusaur',
      types: ['grass', 'poison'],
    ),
  ],
  hasMore: false,
);

final class _CatalogRepository implements CatalogRepository {
  _CatalogRepository({required this.watch, this.refreshCatalog});

  final Stream<CatalogSnapshot> Function() watch;
  final Future<void> Function()? refreshCatalog;

  @override
  Stream<CatalogSnapshot> watchCatalog() => watch();

  @override
  Future<void> refresh() async {
    await refreshCatalog?.call();
  }

  @override
  Future<void> loadNextPage() async {}
}
