import 'dart:convert';

import '../../../../core/domain/pokemon_id.dart';
import '../../domain/pokemon_summary.dart';

/// Forma de los datos de PokéAPI. El dominio recibe [PokemonSummary].
final class PokemonCatalogDto {
  PokemonCatalogDto.fromJson(Map<String, dynamic> json)
    : id = _positiveInt(json['id'], 'id'),
      name = _nonEmptyString(json['name'], 'name'),
      nationalNumber = _positiveInt(json['nationalNumber'], 'nationalNumber'),
      types = _parseTypes(json['types']),
      _sprites = _parseSprites(json['sprites']);

  final int id;
  final String name;
  final int nationalNumber;
  final List<String> types;
  final Map<String, dynamic> _sprites;

  PokemonSummary toDomain() {
    final other = _sprites['other'];
    final artwork = other is Map ? other['official-artwork'] : null;
    return PokemonSummary(
      id: PokemonId(id),
      name: name,
      nationalNumber: nationalNumber,
      types: types,
      artworkUrl: _imageUri(artwork is Map ? artwork['front_default'] : null),
      spriteUrl: _imageUri(_sprites['front_default']),
    );
  }

  static int _positiveInt(Object? value, String field) {
    if (value is! int || value <= 0) {
      throw FormatException('Campo inválido en el catálogo: $field');
    }
    return value;
  }

  static String _nonEmptyString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo inválido en el catálogo: $field');
    }
    return value;
  }

  static List<String> _parseTypes(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException('El Pokémon debe tener al menos un tipo');
    }
    return [
      for (final entry in value)
        if (entry case {'type': {'name': final Object? name}})
          _nonEmptyString(name, 'type.name')
        else
          throw const FormatException('Tipo de Pokémon inválido'),
    ];
  }

  static Map<String, dynamic> _parseSprites(Object? value) {
    if (value is! List) {
      throw const FormatException('La relación de sprites debe ser una lista');
    }
    if (value.isEmpty) return const {};

    final row = value.first;
    if (row is! Map<String, dynamic> || !row.containsKey('sprites')) {
      throw const FormatException('Registro de sprites inválido');
    }
    final sprites = row['sprites'];
    final decoded = sprites is String ? jsonDecode(sprites) : sprites;
    if (decoded == null) return const {};
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El contenido de sprites debe ser un objeto');
    }
    return decoded;
  }

  static Uri? _imageUri(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }
}
