import 'dart:async';

import 'package:dart_final_project/app/app_dependencies.dart';
import 'package:dart_final_project/app/connectivity_indicator.dart';
import 'package:dart_final_project/app/pokedex_app.dart';
import 'package:dart_final_project/core/data/demo_connectivity_service.dart';
import 'package:dart_final_project/core/data/sync_activity_tracker.dart';
import 'package:dart_final_project/core/domain/connectivity_service.dart';
import 'package:dart_final_project/core/domain/sync_activity_monitor.dart';
import 'package:dart_final_project/features/catalog/data/demo_catalog_repository.dart';
import 'package:dart_final_project/features/favorites/data/demo_favorites_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoConnectivityService connectivity;
  late SyncActivityTracker sync;
  late DemoFavoritesRepository favorites;

  setUp(() {
    connectivity = DemoConnectivityService();
    sync = SyncActivityTracker();
    favorites = DemoFavoritesRepository();
    addTearDown(connectivity.dispose);
    addTearDown(sync.dispose);
    addTearDown(favorites.dispose);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PokedexApp(
        dependencies: AppDependencies(
          catalog: DemoCatalogRepository(),
          favorites: favorites,
          connectivity: connectivity,
          syncActivity: sync,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra cada estado con texto, icono y etiqueta Semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    expect(find.text('Verificando conexión…'), findsOneWidget);
    expect(find.text('Sin datos guardados'), findsOneWidget);

    connectivity.set(ConnectivityStatus.online);
    await tester.pumpAndSettle();
    expect(find.text('En línea'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Estado de conexión: En línea\.')),
      findsOneWidget,
    );

    connectivity.set(ConnectivityStatus.offline);
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsWidgets);

    connectivity.set(ConnectivityStatus.serviceUnavailable);
    await tester.pumpAndSettle();
    expect(find.text('Servicio no disponible'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('muestra Sincronizando solo con el servicio disponible', (
    tester,
  ) async {
    final pending = Completer<void>();
    unawaited(sync.track(() => pending.future));
    connectivity.set(ConnectivityStatus.offline);
    await pumpApp(tester);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Sincronizando…'), findsNothing);

    connectivity.set(ConnectivityStatus.online);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sincronizando…'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('En línea'), findsOneWidget);
  });

  testWidgets('sigue visible al abrir el detalle', (tester) async {
    connectivity.set(ConnectivityStatus.online);
    await pumpApp(tester);

    await tester.tap(find.text('Bulbasaur'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de Bulbasaur · #1'), findsOneWidget);
    expect(find.text('En línea'), findsOneWidget);
  });

  testWidgets('no se recorta con el texto al 200 %', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    connectivity.set(ConnectivityStatus.serviceUnavailable);

    await pumpApp(tester);
    expect(find.text('Servicio no disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('combina disponibilidad y sincronización sin contradicciones', () {
    expect(
      IndicatorState.from(ConnectivityStatus.offline, SyncActivity.syncing),
      IndicatorState.offline,
    );
    expect(
      IndicatorState.from(ConnectivityStatus.online, SyncActivity.syncing),
      IndicatorState.syncing,
    );
    expect(
      IndicatorState.from(ConnectivityStatus.unknown, SyncActivity.idle),
      IndicatorState.checking,
    );
  });

  test('describe la vigencia de los datos con la hora local', () {
    final now = DateTime(2026, 11, 15, 12);
    expect(dataFreshnessLabel(null, now), 'Sin datos guardados');
    expect(
      dataFreshnessLabel(DateTime(2026, 11, 15, 9, 5), now),
      'Última actualización: 09:05',
    );
    expect(
      dataFreshnessLabel(DateTime(2026, 11, 14, 22, 30), now),
      'Última actualización: 14/11 22:30',
    );
  });
}
