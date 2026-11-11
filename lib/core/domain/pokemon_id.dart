/// ID del recurso Pokémon de la API; no el ID de especie o forma.
final class PokemonId {
  PokemonId(this.value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'Debe ser mayor que cero');
    }
  }

  final int value;

  @override
  bool operator ==(Object other) => other is PokemonId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}
