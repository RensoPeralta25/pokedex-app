import 'dart:convert';
import 'dart:io';

import 'package:dart_final_project/core/data/graphql_health_check.dart';
import 'package:dart_final_project/core/domain/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Uri endpoint;
  late Future<void> Function(HttpRequest request) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    endpoint = Uri.http('127.0.0.1:${server.port}', '/v1beta2');
    server.listen((request) => handler(request));
  });

  Future<void> reply(HttpRequest request, int status, Object body) async {
    await utf8.decoder.bind(request).join();
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  test('respuesta GraphQL válida → online', () async {
    handler = (request) => reply(request, 200, {
      'data': {'__typename': 'query_root'},
    });
    expect(await checkGraphqlService(endpoint), ConnectivityStatus.online);
  });

  test('HTTP 500 o errores GraphQL → servicio no disponible', () async {
    handler = (request) => reply(request, 500, {'message': 'caído'});
    expect(
      await checkGraphqlService(endpoint),
      ConnectivityStatus.serviceUnavailable,
    );

    handler = (request) => reply(request, 200, {
      'errors': [
        {'message': 'fallo'},
      ],
    });
    expect(
      await checkGraphqlService(endpoint),
      ConnectivityStatus.serviceUnavailable,
    );
  });

  test('sin respuesta dentro del límite → servicio no disponible', () async {
    handler = (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // El cliente ya cerró la conexión por el límite de tiempo.
      await reply(request, 200, {'data': {}}).catchError((Object _) {});
    };
    expect(
      await checkGraphqlService(
        endpoint,
        timeout: const Duration(milliseconds: 100),
      ),
      ConnectivityStatus.serviceUnavailable,
    );
  });

  test(
    'conexión rechazada con red presente → servicio no disponible',
    () async {
      final closed = Uri.http('127.0.0.1:${server.port}', '/');
      await server.close(force: true);
      expect(
        await checkGraphqlService(closed),
        ConnectivityStatus.serviceUnavailable,
      );
    },
  );
}
