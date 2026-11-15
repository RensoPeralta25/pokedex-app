import 'dart:async';
import 'dart:collection';

import 'package:dart_final_project/core/data/api_connectivity_service.dart';
import 'package:dart_final_project/core/domain/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<bool> network;
  late Queue<ConnectivityStatus> results;
  late int checks;
  late ApiConnectivityService service;
  late List<ConnectivityStatus> emitted;

  ApiConnectivityService create({required bool initialNetwork}) {
    final created = ApiConnectivityService(
      networkChanges: network.stream,
      hasNetwork: () async => initialNetwork,
      checkService: () async {
        checks++;
        return results.isEmpty
            ? ConnectivityStatus.online
            : results.removeFirst();
      },
      pollInterval: const Duration(hours: 1),
      confirmDelay: const Duration(milliseconds: 20),
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    network = StreamController<bool>();
    addTearDown(network.close);
    results = Queue();
    checks = 0;
    emitted = [];
  });

  void listen() {
    final subscription = service.watchStatus().listen(emitted.add);
    addTearDown(subscription.cancel);
  }

  test(
    'empieza en unknown y pasa a online solo tras responder GraphQL',
    () async {
      service = create(initialNetwork: true);
      listen();
      await settle();
      expect(emitted, [ConnectivityStatus.unknown, ConnectivityStatus.online]);
      expect(checks, 1);
    },
  );

  test('sin red pasa a offline sin consultar GraphQL', () async {
    service = create(initialNetwork: false);
    listen();
    await settle();

    expect(emitted.last, ConnectivityStatus.offline);
    expect(checks, 0);
  });

  test('con red pero sin respuesta válida nunca declara online', () async {
    results.addAll([
      ConnectivityStatus.serviceUnavailable,
      ConnectivityStatus.serviceUnavailable,
    ]);
    service = create(initialNetwork: true);
    listen();
    await settle();

    expect(emitted, [
      ConnectivityStatus.unknown,
      ConnectivityStatus.serviceUnavailable,
    ]);
  });

  test('un fallo aislado no quita online; dos seguidos sí', () async {
    service = create(initialNetwork: true);
    listen();
    await settle();
    expect(service.current, ConnectivityStatus.online);

    results.addAll([
      ConnectivityStatus.serviceUnavailable,
      ConnectivityStatus.online,
    ]);
    network.add(true);
    await settle();
    expect(service.current, ConnectivityStatus.online);

    results.addAll([
      ConnectivityStatus.serviceUnavailable,
      ConnectivityStatus.serviceUnavailable,
    ]);
    network.add(true);
    await settle();
    expect(service.current, ConnectivityStatus.serviceUnavailable);
    expect(emitted, [
      ConnectivityStatus.unknown,
      ConnectivityStatus.online,
      ConnectivityStatus.serviceUnavailable,
    ]);
  });

  test('perder la red es inmediato y recuperarla vuelve a online', () async {
    service = create(initialNetwork: true);
    listen();
    await settle();

    network.add(false);
    await settle();
    expect(service.current, ConnectivityStatus.offline);

    network.add(true);
    await settle();
    expect(emitted, [
      ConnectivityStatus.unknown,
      ConnectivityStatus.online,
      ConnectivityStatus.offline,
      ConnectivityStatus.online,
    ]);
  });

  test('las comprobaciones simultáneas se comparten', () async {
    final pending = Completer<ConnectivityStatus>();
    var calls = 0;
    service = ApiConnectivityService(
      networkChanges: network.stream,
      hasNetwork: () async => true,
      checkService: () {
        calls++;
        return pending.future;
      },
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(service.dispose);
    listen();
    await Future<void>.delayed(Duration.zero);
    network
      ..add(true)
      ..add(true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    pending.complete(ConnectivityStatus.online);
    await settle();
    expect(service.current, ConnectivityStatus.online);
  });

  test('vuelve a comprobar periódicamente mientras hay red', () async {
    service = ApiConnectivityService(
      networkChanges: network.stream,
      hasNetwork: () async => true,
      checkService: () async {
        checks++;
        return checks < 3
            ? ConnectivityStatus.serviceUnavailable
            : ConnectivityStatus.online;
      },
      pollInterval: const Duration(milliseconds: 30),
    );
    addTearDown(service.dispose);
    listen();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(checks, greaterThanOrEqualTo(3));
    expect(service.current, ConnectivityStatus.online);
  });
}
