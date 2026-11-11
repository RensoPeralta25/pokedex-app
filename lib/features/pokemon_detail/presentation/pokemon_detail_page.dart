import 'package:flutter/material.dart';

import '../../catalog/domain/pokemon_summary.dart';

/// Destino inicial; las consultas y el detalle completo pertenecen a PKD-15/16.
class PokemonDetailPage extends StatelessWidget {
  const PokemonDetailPage({super.key, required this.pokemon});

  final PokemonSummary pokemon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(pokemon.name)),
    body: Center(child: Text('Detalle de ${pokemon.name} · #${pokemon.id}')),
  );
}
