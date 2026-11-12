import 'package:flutter/material.dart';

import '../domain/pokemon_summary.dart';

class PokemonCatalogCard extends StatelessWidget {
  const PokemonCatalogCard({
    super.key,
    required this.pokemon,
    required this.onTap,
  });

  final PokemonSummary pokemon;
  final VoidCallback onTap;

  static const _typeNames = {
    'normal': 'Normal',
    'fighting': 'Lucha',
    'flying': 'Volador',
    'poison': 'Veneno',
    'ground': 'Tierra',
    'rock': 'Roca',
    'bug': 'Bicho',
    'ghost': 'Fantasma',
    'steel': 'Acero',
    'fire': 'Fuego',
    'water': 'Agua',
    'grass': 'Planta',
    'electric': 'Eléctrico',
    'psychic': 'Psíquico',
    'ice': 'Hielo',
    'dragon': 'Dragón',
    'dark': 'Siniestro',
    'fairy': 'Hada',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = pokemon.nationalNumber;
    final types = pokemon.types
        .map((type) => _typeNames[type] ?? type)
        .join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _PokemonImage(
                      artworkUrl: pokemon.artworkUrl,
                      spriteUrl: pokemon.spriteUrl,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (number != null)
                Text(
                  '#${number.toString().padLeft(3, '0')}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                pokemon.name,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (types.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  types,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PokemonImage extends StatelessWidget {
  const _PokemonImage({this.artworkUrl, this.spriteUrl});

  final Uri? artworkUrl;
  final Uri? spriteUrl;

  static const _placeholder = Icon(Icons.catching_pokemon, size: 32);

  Widget _loadImage(Uri url, {required Widget fallback}) => Image.network(
    url.toString(),
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    frameBuilder: (context, child, frame, synchronouslyLoaded) =>
        frame == null && !synchronouslyLoaded ? _placeholder : child,
    errorBuilder: (context, error, stackTrace) => fallback,
  );

  @override
  Widget build(BuildContext context) {
    final artwork = artworkUrl;
    final sprite = spriteUrl;
    if (artwork == null && sprite == null) return _placeholder;

    if (artwork != null && sprite != null && artwork != sprite) {
      return _loadImage(
        artwork,
        fallback: _loadImage(sprite, fallback: _placeholder),
      );
    }

    return _loadImage(artwork ?? sprite!, fallback: _placeholder);
  }
}
