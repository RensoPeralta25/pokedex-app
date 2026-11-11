import '../../../core/domain/pokemon_id.dart';

/// Datos mínimos compartidos por catálogo, detalle y favoritos.
final class PokemonSummary {
  const PokemonSummary({required this.id, required this.name});

  final PokemonId id;
  final String name;
}
