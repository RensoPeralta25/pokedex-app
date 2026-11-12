import '../../../core/domain/pokemon_id.dart';

/// Datos básicos del Pokémon para catálogo, detalle y favoritos.
final class PokemonSummary {
  PokemonSummary({
    required this.id,
    required this.name,
    this.nationalNumber,
    List<String> types = const [],
    this.artworkUrl,
    this.spriteUrl,
  }) : types = List.unmodifiable(types);

  final PokemonId id;
  final String name;
  final int? nationalNumber;
  final List<String> types;
  final Uri? artworkUrl;
  final Uri? spriteUrl;
}
