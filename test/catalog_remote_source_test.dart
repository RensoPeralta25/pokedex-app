import 'dart:convert';

import 'package:dart_final_project/features/catalog/data/remote/poke_api_catalog_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mapea campos y reserva el siguiente registro para la próxima página',
    () async {
      final calls = <Map<String, Object>>[];
      final source = PokeApiCatalogSource(
        request: (_, variables) async {
          calls.add(variables);
          return {
            'data': {
              'pokemon': variables['offset'] == 0
                  ? [_pokemon(25, 25), _pokemon(26, 26), _pokemon(27, 27)]
                  : [_pokemon(27, 27), _pokemon(28, 28)],
            },
          };
        },
      );

      final first = await source.fetchPage(pageSize: 2);
      final second = await source.fetchPage(
        pageSize: 2,
        offset: first.nextOffset!,
      );

      expect(calls, [
        {'limit': 3, 'offset': 0},
        {'limit': 3, 'offset': 2},
      ]);
      expect(first.items.map((pokemon) => pokemon.id.value), [25, 26]);
      expect(second.items.map((pokemon) => pokemon.id.value), [27, 28]);
      expect(first.hasMore, isTrue);
      expect(second.hasMore, isFalse);
      expect(second.nextOffset, isNull);

      final pikachu = first.items.first;
      expect(pikachu.name, 'pikachu');
      expect(pikachu.nationalNumber, 25);
      expect(pikachu.types, ['electric']);
      expect(
        pikachu.artworkUrl.toString(),
        'https://example.com/artwork/25.png',
      );
      expect(
        pikachu.spriteUrl.toString(),
        'https://example.com/sprites/25.png',
      );
    },
  );

  test(
    'conserva el número nacional separado del ID y admite imágenes ausentes',
    () async {
      final source = PokeApiCatalogSource(
        request: (_, _) async => {
          'data': {
            'pokemon': [_pokemon(10100, 25)..['sprites'] = []],
          },
        },
      );

      final pokemon = (await source.fetchPage()).items.single;
      expect(pokemon.id.value, 10100);
      expect(pokemon.nationalNumber, 25);
      expect(pokemon.artworkUrl, isNull);
      expect(pokemon.spriteUrl, isNull);
    },
  );

  test(
    'rechaza errores GraphQL aunque la respuesta incluya datos parciales',
    () async {
      final source = PokeApiCatalogSource(
        request: (_, _) async => {
          'data': {
            'pokemon': [_pokemon(25, 25)],
          },
          'errors': [
            {'message': 'Fallo de GraphQL'},
          ],
        },
      );

      await expectLater(source.fetchPage(), throwsStateError);
    },
  );

  test(
    'una página inválida falla sin aparentar que terminó el catálogo',
    () async {
      final source = PokeApiCatalogSource(
        request: (_, _) async => {
          'data': {
            'pokemon': [_pokemon(25, 25)..['types'] = null],
          },
        },
      );

      await expectLater(source.fetchPage(), throwsFormatException);
    },
  );
}

Map<String, dynamic> _pokemon(int id, int nationalNumber) => {
  'id': id,
  'nationalNumber': nationalNumber,
  'name': id == 25 ? 'pikachu' : 'pokemon-$id',
  'types': [
    {
      'type': {'name': 'electric'},
    },
  ],
  'sprites': [
    {
      'sprites': jsonEncode({
        'front_default': 'https://example.com/sprites/$id.png',
        'other': {
          'official-artwork': {
            'front_default': 'https://example.com/artwork/$id.png',
          },
        },
      }),
    },
  ],
};
