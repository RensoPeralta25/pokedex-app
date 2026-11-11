import 'package:flutter/material.dart';

import '../../../core/domain/pokemon_id.dart';
import '../domain/favorites_repository.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.repository});

  final FavoritesRepository repository;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Stream<Set<PokemonId>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = widget.repository.watchFavoriteIds();
  }

  @override
  void didUpdateWidget(FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _favorites = widget.repository.watchFavoriteIds();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis favoritos')),
    body: StreamBuilder<Set<PokemonId>>(
      stream: _favorites,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron leer los favoritos.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text('Favoritos disponibles: ${snapshot.requireData.length}'),
        );
      },
    ),
  );
}
