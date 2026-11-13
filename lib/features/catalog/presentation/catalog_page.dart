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
  bool _refreshing = false;
  bool _loadingNextPage = false;
  bool _nextPageFailed = false;
  bool _refreshFailed = false;
  int _repositoryVersion = 0;

  @override
  void initState() {
    super.initState();
    _catalog = _watchCatalogAndRefresh();
  }

  @override
  void didUpdateWidget(CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _repositoryVersion++;
      _catalog = _watchCatalogAndRefresh();
      _refreshing = false;
      _loadingNextPage = false;
      _nextPageFailed = false;
      _refreshFailed = false;
    }
  }

  Stream<CatalogSnapshot> _watchCatalogAndRefresh() {
    final version = _repositoryVersion;
    var refreshScheduled = false;
    return widget.repository.watchCatalog().map((snapshot) {
      if (!refreshScheduled) {
        refreshScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && version == _repositoryVersion) {
            _refresh();
          }
        });
      }
      return snapshot;
    });
  }

  Future<void> _refresh({bool resubscribe = false}) async {
    if (_refreshing || _loadingNextPage) return;
    final repository = widget.repository;
    final version = _repositoryVersion;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });

    try {
      await repository.refresh();
      if (!mounted || version != _repositoryVersion) return;
      setState(() {
        // Recover even if the stream that reported a read error has closed.
        if (resubscribe) _catalog = repository.watchCatalog();
        _refreshing = false;
        _nextPageFailed = false;
      });
    } catch (_) {
      if (!mounted || version != _repositoryVersion) return;
      setState(() {
        _refreshFailed = true;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingNextPage || _refreshing) return;
    final version = _repositoryVersion;
    setState(() {
      _loadingNextPage = true;
      _nextPageFailed = false;
    });

    try {
      await widget.repository.loadNextPage();
    } catch (_) {
      if (mounted && version == _repositoryVersion) {
        _nextPageFailed = true;
      }
    } finally {
      if (mounted && version == _repositoryVersion) {
        setState(() => _loadingNextPage = false);
      }
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
          final items = snapshot.data?.items ?? const <PokemonSummary>[];
          if (items.isEmpty &&
              (_refreshing ||
                  snapshot.connectionState == ConnectionState.waiting)) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando catálogo',
              ),
            );
          }

          if (items.isEmpty && (_refreshFailed || snapshot.hasError)) {
            return _CatalogMessage(
              icon: Icons.cloud_off_outlined,
              message: 'No se pudo cargar el catálogo.',
              action: FilledButton.icon(
                onPressed: () => _refresh(resubscribe: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            );
          }

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

              final grid = GridView.builder(
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

              return Column(
                children: [
                  Expanded(child: grid),
                  if (_refreshing)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Actualizando catálogo',
                    ),
                  if (_refreshFailed)
                    _CatalogFooter(
                      message: 'No se pudo actualizar el catálogo.',
                      action: TextButton(
                        onPressed: _loadingNextPage ? null : _refresh,
                        child: const Text('Reintentar actualización'),
                      ),
                    ),
                  if (_loadingNextPage)
                    const _CatalogFooter(
                      action: CircularProgressIndicator(
                        semanticsLabel: 'Cargando más Pokémon',
                      ),
                    )
                  else if (snapshot.data?.hasMore ?? false)
                    _CatalogFooter(
                      message: _nextPageFailed
                          ? 'No se pudo cargar la siguiente página.'
                          : null,
                      action: FilledButton.tonal(
                        onPressed: _refreshing ? null : _loadNextPage,
                        child: Text(
                          _nextPageFailed ? 'Reintentar página' : 'Cargar más',
                        ),
                      ),
                    ),
                ],
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

class _CatalogFooter extends StatelessWidget {
  const _CatalogFooter({required this.action, this.message});

  final Widget action;
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        if (message case final text?) Text(text, textAlign: TextAlign.center),
        action,
      ],
    ),
  );
}
