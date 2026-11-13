import 'package:flutter/material.dart';

import '../../pokemon_detail/presentation/pokemon_detail_page.dart';
import '../domain/catalog_repository.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/pokemon_summary.dart';
import 'pokemon_catalog_card.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Stream<CatalogSnapshot> _catalog;
  bool _retrying = false;
  bool _refreshFailed = false;
  int _repositoryVersion = 0;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.watchCatalog();
  }

  @override
  void didUpdateWidget(CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _repositoryVersion++;
      _catalog = widget.repository.watchCatalog();
      _retrying = false;
      _refreshFailed = false;
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final repository = widget.repository;
    final version = _repositoryVersion;
    setState(() {
      _retrying = true;
      _refreshFailed = false;
    });

    try {
      await repository.refresh();
      if (!mounted || version != _repositoryVersion) return;
      // A new subscription also recovers when the failing stream ended.
      final catalog = repository.watchCatalog();
      setState(() {
        _catalog = catalog;
        _retrying = false;
      });
    } catch (_) {
      if (!mounted || version != _repositoryVersion) return;
      setState(() {
        _refreshFailed = true;
        _retrying = false;
      });
    }
  }

  void _openDetail(PokemonSummary pokemon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PokemonDetailPage(pokemon: pokemon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pokédex')),
    body: SafeArea(
      top: false,
      bottom: false,
      child: StreamBuilder<CatalogSnapshot>(
        key: ObjectKey(_catalog),
        stream: _catalog,
        builder: (context, snapshot) {
          if (_retrying ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando catálogo',
              ),
            );
          }

          if (_refreshFailed || snapshot.hasError) {
            return _CatalogMessage(
              icon: Icons.cloud_off_outlined,
              message: 'No se pudo cargar el catálogo.',
              action: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            );
          }

          final items = snapshot.data?.items ?? const <PokemonSummary>[];
          if (items.isEmpty) {
            return const _CatalogMessage(
              icon: Icons.catching_pokemon,
              message: 'No hay Pokémon disponibles.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final minCardWidth = 152 * textScale.clamp(1.0, 2.0);
              final columns =
                  ((constraints.maxWidth - 20) / (minCardWidth + 12))
                      .floor()
                      .clamp(1, 4);

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 128 + 112 * textScale,
                ),
                itemBuilder: (context, index) {
                  final pokemon = items[index];
                  return PokemonCatalogCard(
                    key: ValueKey(pokemon.id),
                    pokemon: pokemon,
                    onTap: () => _openDetail(pokemon),
                  );
                },
              );
            },
          );
        },
      ),
    ),
  );
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action case final button?) ...[
            const SizedBox(height: 16),
            button,
          ],
        ],
      ),
    ),
  );
}
