import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pagination/paginated_list_controller.dart';
import 'feedback.dart';
import 'glass.dart';
import 'list_skeleton.dart';
import 'surfaces.dart';

/// Coque commune à toutes les listes de contenu (§5) : recherche, puces de
/// filtre fournies par l'appelant, défilement infini, tirer pour rafraîchir,
/// état vide et erreur, bouton de création.
///
/// Chaque écran ne fournit que ce qui lui est propre : le titre, l'état
/// (`ref.watch` du provider concerné), comment dessiner un élément, et les
/// puces de filtre (déjà construites, car elles connaissent le provider).
class ResourceListScaffold<T> extends StatelessWidget {
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
    this.header,
    this.searchController,
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

  /// Actions de la barre du haut (accès à une sous-table, par exemple).
  final List<Widget> actions;

  /// Bloc affiché entre le titre et la recherche (synthèse chiffrée…).
  final Widget? header;

  /// Pour remplir la recherche depuis l'écran ; sinon le champ gère le sien.
  final TextEditingController? searchController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(actions: actions),
      floatingActionButton: onCreate == null
          ? null
          : GlassFab(
              icon: Icons.add_rounded,
              tooltip: 'Ajouter',
              onPressed: onCreate!,
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
      body: ResourceListView<T>(
        title: title,
        searchHint: searchHint,
        state: state,
        itemBuilder: itemBuilder,
        emptyIcon: emptyIcon,
        emptyTitle: emptyTitle,
        emptyDescription: emptyDescription,
        onSearch: onSearch,
        onLoadMore: onLoadMore,
        onRefresh: onRefresh,
        onRetry: onRetry,
        filterChips: filterChips,
        header: header,
        searchController: searchController,
        extraBottom: onCreate == null ? 0 : 72,
      ),
    );
  }
}

/// Corps de liste sans Scaffold : titre facultatif, recherche et puces qui
/// défilent avec la page (sous les barres flottantes), puis les éléments en cartes.
class ResourceListView<T> extends StatefulWidget {
  const ResourceListView({
    super.key,
    this.title,
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
    this.filterChips = const [],
    this.wrapInCard = true,
    this.extraBottom = 0,
    this.header,
    this.searchController,
  });

  final String? title;
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
  final List<Widget> filterChips;

  /// `false` quand l'appelant dessine déjà sa propre carte (glisser pour modérer…).
  final bool wrapInCard;

  /// Place réservée en bas en plus des barres flottantes (bouton +).
  final double extraBottom;

  /// Bloc affiché entre le titre et la recherche.
  final Widget? header;

  /// Contrôleur de recherche fourni par l'appelant (non libéré ici).
  final TextEditingController? searchController;

  @override
  State<ResourceListView<T>> createState() => _ResourceListViewState<T>();
}

class _ResourceListViewState<T> extends State<ResourceListView<T>> {
  final _scrollController = ScrollController();
  final _ownSearchController = TextEditingController();

  TextEditingController get _searchController => widget.searchController ?? _ownSearchController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ownSearchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = pageInsets(context, bottom: 24 + widget.extraBottom);

    final header = SliverPadding(
      padding: EdgeInsets.only(top: insets.top),
      sliver: SliverList.list(
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(widget.title!, style: theme.textTheme.headlineMedium),
            ),
          if (widget.header != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: widget.header),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SearchPill(controller: _searchController, hintText: widget.searchHint, onSubmitted: widget.onSearch),
          ),
          if (widget.filterChips.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.filterChips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Center(child: widget.filterChips[index]),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );

    final content = widget.state.when(
      loading: () => const SliverFillRemaining(child: ListSkeleton()),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger la liste.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: widget.onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ComingSoon(icon: widget.emptyIcon, title: widget.emptyTitle, description: widget.emptyDescription),
            ),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, insets.bottom),
          sliver: SliverList.separated(
            itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final item = widget.itemBuilder(context, data.items[index]);
              // Chaque élément devient une carte ; l'appelant ne dessine que son contenu.
              return widget.wrapInCard ? SurfaceCard(radius: 20, padding: EdgeInsets.zero, child: item) : item;
            },
          ),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      edgeOffset: insets.top,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [header, content],
      ),
    );
  }
}
