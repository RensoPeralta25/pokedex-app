import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/data/pokedex_image_cache.dart';

import '../domain/pokemon_summary.dart';

class PokemonCatalogCard extends StatelessWidget {
  PokemonCatalogCard({
    super.key,
    required this.pokemon,
    required this.onTap,
    this.imageGeneration = 0,
    BaseCacheManager? imageCache,
  }) : imageCache = imageCache ?? PokedexImageCache.instance;

  final PokemonSummary pokemon;
  final VoidCallback onTap;

  /// Al cambiar, las imágenes que fallaron se vuelven a intentar.
  final int imageGeneration;
  final BaseCacheManager imageCache;

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
                      key: ValueKey(imageGeneration),
                      cacheManager: imageCache,
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
  const _PokemonImage({
    super.key,
    required this.cacheManager,
    this.artworkUrl,
    this.spriteUrl,
  });

  final BaseCacheManager cacheManager;
  final Uri? artworkUrl;
  final Uri? spriteUrl;

  static const _placeholder = Icon(Icons.catching_pokemon, size: 32);

  @override
  Widget build(BuildContext context) {
    final artwork = artworkUrl;
    final sprite = spriteUrl;
    if (artwork == null && sprite == null) return _placeholder;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Se decodifica al tamaño del hueco, no al original (RNF-REN-04).
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .round()
            : null;

        Widget load(Uri url, {required Widget fallback}) => CachedNetworkImage(
          imageUrl: url.toString(),
          cacheManager: cacheManager,
          memCacheWidth: width,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => _placeholder,
          errorWidget: (context, url, error) => fallback,
        );

        final image = artwork != null && sprite != null && artwork != sprite
            ? load(artwork, fallback: load(sprite, fallback: _placeholder))
            : load(artwork ?? sprite!, fallback: _placeholder);
        return ExcludeSemantics(child: image);
      },
    );
  }
}
