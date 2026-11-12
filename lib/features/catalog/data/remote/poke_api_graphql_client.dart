import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef CatalogGraphqlRequest = Future<Map<String, dynamic>> Function(
  String query,
  Map<String, Object> variables,
);

final class PokeApiGraphqlClient {
  PokeApiGraphqlClient({
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  }) : endpoint = endpoint ?? Uri.https('graphql.pokeapi.co', '/v1beta2') {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Debe ser positivo');
    }
  }

  final Uri endpoint;
  final Duration timeout;

  Future<Map<String, dynamic>> query(
    String query,
    Map<String, Object> variables,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _post(client, query, variables).timeout(timeout);
    } finally {
      // También cancela una petición que agote el tiempo durante la lectura.
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post(
    HttpClient client,
    String query,
    Map<String, Object> variables,
  ) async {
    final request = await client.postUrl(endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.add(
      utf8.encode(jsonEncode({'query': query, 'variables': variables})),
    );

    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'PokéAPI respondió HTTP ${response.statusCode}',
        uri: endpoint,
      );
    }

    final decoded = jsonDecode(await utf8.decoder.bind(response).join());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta GraphQL debe ser un objeto JSON',
      );
    }
    return decoded;
  }
}
