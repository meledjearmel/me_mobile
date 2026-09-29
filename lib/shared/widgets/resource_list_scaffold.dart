import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pagination/paginated_list_controller.dart';
import 'feedback.dart';
import 'list_skeleton.dart';

/// Coque commune à toutes les listes de contenu (§5) : recherche, puces de
/// filtre fournies par l'appelant, défilement infini, tirer pour rafraîchir,
/// état vide et erreur, bouton de création.
///
/// Chaque écran ne fournit que ce qui lui est propre : le titre, l'état
/// (`ref.watch` du provider concerné), comment dessiner un élément, et les
/// puces de filtre (déjà construites, car elles connaissent le provider).
class ResourceListScaffold<T> extends StatefulWidget {
  const ResourceListScaffold({
    super.key,
    required this.title,
    required this.searchHint,
    required this.state,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onSearch,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onRetry,
    this.onCreate,
    this.filterChips = const [],
    this.actions = const [],
  });

  final String title;
  final String searchHint;
  final AsyncValue<ListState<T>> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;
  final ValueChanged<String> onSearch;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  /// `null` : pas de bouton d'ajout (aucun cas dans cette app, gardé au cas où).
  final VoidCallback? onCreate;

  /// Puces déjà construites par l'appelant (elles connaissent leur provider).
  final List<Widget> filterChips;

  /// Actions de l'AppBar (accès à une sous-table, par exemple).
  final List<Widget> actions;

  @override
  State<ResourceListScaffold<T>> createState() => _ResourceListScaffoldState<T>();
}

class _ResourceListScaffoldState<T> extends State<ResourceListScaffold<T>> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton(onPressed: widget.onCreate, child: const Icon(Icons.add_rounded)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearch('');
                        },
                      ),
              ),
            ),
          ),
          if (widget.filterChips.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.filterChips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => widget.filterChips[index],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: widget.state.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Impossible de charger la liste.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: widget.onRetry, child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return Center(
                    child: ComingSoon(
                      icon: widget.emptyIcon,
                      title: widget.emptyTitle,
                      description: widget.emptyDescription,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return widget.itemBuilder(context, data.items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
