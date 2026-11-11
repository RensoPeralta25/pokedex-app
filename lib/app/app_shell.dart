import 'package:flutter/material.dart';

import '../features/catalog/presentation/catalog_page.dart';
import '../features/favorites/presentation/favorites_page.dart';
import '../features/trivia/presentation/trivia_page.dart';
import 'app_dependencies.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        CatalogPage(repository: widget.dependencies.catalog),
        FavoritesPage(repository: widget.dependencies.favorites),
        const TriviaPage(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.catching_pokemon),
          label: 'Catálogo',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          label: 'Favoritos',
        ),
        NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'Trivia'),
      ],
    ),
  );
}
