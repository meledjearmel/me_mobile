import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/paginated.dart';
import 'list_query.dart';

/// État d'une liste infinie, recherchable et filtrable (§3.3).
@immutable
class ListState<T> {
  const ListState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.query = const ListQuery(),
    this.isLoadingMore = false,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final int total;
  final ListQuery query;

  /// Chargement de la page suivante en cours (défilement infini) : la liste
  /// déjà affichée ne repasse pas par un état de chargement plein écran.
  final bool isLoadingMore;

  ListState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    int? total,
    ListQuery? query,
    bool? isLoadingMore,
  }) =>
      ListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        total: total ?? this.total,
        query: query ?? this.query,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

/// Base commune aux listes de ressources : chargement, pagination infinie,
/// recherche, filtres, et mises à jour optimistes après une mutation.
///
/// Chaque ressource fournit juste [fetchPage] ; le reste (état, pagination,
/// recherche) est partagé.
abstract class PaginatedListController<T> extends AsyncNotifier<ListState<T>> {
  Future<Paginated<T>> fetchPage({required int page, required ListQuery query});

  @override
  Future<ListState<T>> build() => _load(const ListQuery());

  Future<ListState<T>> _load(ListQuery query) async {
    final result = await fetchPage(page: 1, query: query);
    return ListState(items: result.items, page: 1, hasMore: result.hasMore, total: result.total, query: query);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await fetchPage(page: current.page + 1, query: current.query);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: current.page + 1,
          hasMore: next.hasMore,
          total: next.total,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Le prochain "tirer pour rafraîchir" ou défilement retentera ; on ne
      // casse pas la liste déjà affichée pour un échec de page suivante.
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  /// Tirer pour rafraîchir : garde la recherche et les filtres en cours.
  Future<void> refresh() => _reload(state.value?.query ?? const ListQuery());

  Future<void> setSearch(String search) => _reload((state.value?.query ?? const ListQuery()).copyWith(search: search));

  Future<void> setFilters(Map<String, Object?> filters) =>
      _reload((state.value?.query ?? const ListQuery()).copyWith(filters: filters));

  Future<void> _reload(ListQuery query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(query));
  }

  /// Met à jour localement un élément déjà chargé (après un `PUT` réussi),
  /// sans tout recharger.
  void updateItem(bool Function(T) matches, T Function(T) update) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(items: [for (final item in current.items) matches(item) ? update(item) : item]));
  }

  /// Retire localement un élément déjà chargé (après un `DELETE` réussi).
  void removeItem(bool Function(T) matches) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        items: current.items.where((item) => !matches(item)).toList(),
        total: current.total > 0 ? current.total - 1 : 0,
      ),
    );
  }
}
