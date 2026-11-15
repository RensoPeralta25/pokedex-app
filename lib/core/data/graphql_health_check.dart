import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/connectivity_service.dart';

Future<ConnectivityStatus> checkGraphqlService(
  Uri endpoint, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final healthy = await _query(client, endpoint).timeout(timeout);
    return healthy
        ? ConnectivityStatus.online
        : ConnectivityStatus.serviceUnavailable;
  } on SocketException catch (error) {
    return _isNetworkMissing(error)
        ? ConnectivityStatus.offline
        : ConnectivityStatus.serviceUnavailable;
  } on Object {
    return ConnectivityStatus.serviceUnavailable;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _query(HttpClient client, Uri endpoint) async {
  final request = await client.postUrl(endpoint);
  request.headers.contentType = ContentType.json;
  request.add(utf8.encode(jsonEncode({'query': 'query { __typename }'})));
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  if (response.statusCode != HttpStatus.ok) return false;

  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic> &&
      decoded['data'] != null &&
      decoded['errors'] == null;
}

/// Sin DNS o sin ruta es falta de Internet; otros fallos de socket son del
/// servicio.
bool _isNetworkMissing(SocketException error) {
  final message = '${error.message} ${error.osError?.message ?? ''}'
      .toLowerCase();
  return message.contains('host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('no address associated');
}
