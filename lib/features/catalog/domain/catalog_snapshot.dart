import 'pokemon_summary.dart';

/// Vista inmutable de los elementos disponibles, no una respuesta de red.
final class CatalogSnapshot {
  CatalogSnapshot({
    required List<PokemonSummary> items,
    required this.hasMore,
    this.lastUpdated,
  }) : items = List.unmodifiable(items);

  final List<PokemonSummary> items;
  final bool hasMore;
  final DateTime? lastUpdated;
}
