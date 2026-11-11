import 'package:flutter/material.dart';

import '../../pokemon_detail/presentation/pokemon_detail_page.dart';
import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';

/// Pantalla mínima para verificar navegación e inyección, previa a PKD-05.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Stream<CatalogSnapshot> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.watchCatalog();
  }

  @override
  void didUpdateWidget(CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _catalog = widget.repository.watchCatalog();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pokédex')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Base del proyecto · Datos de demostración'),
        ),
        Expanded(
          child: StreamBuilder<CatalogSnapshot>(
            stream: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('No se pudo leer el catálogo.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.requireData.items;
              if (items.isEmpty) {
                return const Center(child: Text('No hay Pokémon disponibles.'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final pokemon = items[index];
                  return ListTile(
                    key: ValueKey(pokemon.id),
                    leading: Text('#${pokemon.id}'),
                    title: Text(pokemon.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PokemonDetailPage(pokemon: pokemon),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
