import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché en disco de las imágenes: al pasar el límite se borran las
/// menos usadas recientemente.
final class PokedexImageCache extends CacheManager with ImageCacheManager {
  PokedexImageCache._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: maxImages,
        ),
      );

  static const key = 'pokedex_images';
  static const maxImages = 1200;

  static final instance = PokedexImageCache._();
}
