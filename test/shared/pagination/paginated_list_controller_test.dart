import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/paginated.dart';
import 'package:me_mobile/shared/pagination/list_query.dart';
import 'package:me_mobile/shared/pagination/paginated_list_controller.dart';

class _Item {
  const _Item(this.id);

  final int id;
}

/// Fournit les données brutes à paginer : surchargé par test, comme un vrai
/// dépôt le serait pour une ressource.
final _sourceProvider = Provider<List<_Item>>((ref) => throw UnimplementedError('overridden per test'));

class _FakeController extends PaginatedListController<_Item> {
  static const pageSize = 2;
  int fetchCalls = 0;

  @override
  Future<Paginated<_Item>> fetchPage({required int page, required ListQuery query}) async {
    fetchCalls++;
    final all = ref.read(_sourceProvider);
    final filtered = query.search.isEmpty ? all : all.where((i) => '${i.id}'.contains(query.search)).toList();
    final start = (page - 1) * pageSize;
    final items = start >= filtered.length ? <_Item>[] : filtered.sublist(start, (start + pageSize).clamp(0, filtered.length));
    final lastPage = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    return Paginated(items: items, currentPage: page, lastPage: lastPage, perPage: pageSize, total: filtered.length);
  }
}

final _listProvider = AsyncNotifierProvider<_FakeController, ListState<_Item>>(_FakeController.new);

void main() {
  test('charge la première page au démarrage', () async {
    final container = ProviderContainer(
      overrides: [_sourceProvider.overrideWithValue([for (var i = 1; i <= 5; i++) _Item(i)])],
    );
    addTearDown(container.dispose);

    final state = await container.read(_listProvider.future);

    expect(state.items.map((i) => i.id), [1, 2]);
    expect(state.hasMore, isTrue);
    expect(state.total, 5);
  });

  test('loadMore ajoute la page suivante sans dupliquer', () async {
    final container = ProviderContainer(
      overrides: [_sourceProvider.overrideWithValue([for (var i = 1; i <= 5; i++) _Item(i)])],
    );
    addTearDown(container.dispose);
    await container.read(_listProvider.future);

    await container.read(_listProvider.notifier).loadMore();
    final state = container.read(_listProvider).value!;

    expect(state.items.map((i) => i.id), [1, 2, 3, 4]);
    expect(state.hasMore, isTrue);

    await container.read(_listProvider.notifier).loadMore();
    final finalState = container.read(_listProvider).value!;
    expect(finalState.items.map((i) => i.id), [1, 2, 3, 4, 5]);
    expect(finalState.hasMore, isFalse);
  });

  test('loadMore ne fait rien une fois hasMore à false', () async {
    final container = ProviderContainer(overrides: [_sourceProvider.overrideWithValue([_Item(1)])]);
    addTearDown(container.dispose);
    await container.read(_listProvider.future);
    final controller = container.read(_listProvider.notifier);
    expect(container.read(_listProvider).value!.hasMore, isFalse);

    await controller.loadMore();

    expect(controller.fetchCalls, 1); // un seul appel réseau, pas un de plus pour rien.
  });

  test('setSearch relance depuis la page 1 avec le filtre', () async {
    final container = ProviderContainer(
      overrides: [_sourceProvider.overrideWithValue([for (var i = 1; i <= 25; i++) _Item(i)])],
    );
    addTearDown(container.dispose);
    await container.read(_listProvider.future);

    await container.read(_listProvider.notifier).setSearch('12');
    final state = container.read(_listProvider).value!;

    expect(state.items.map((i) => i.id), [12]);
    expect(state.query.search, '12');
  });

  test('refresh garde la recherche en cours', () async {
    final container = ProviderContainer(
      overrides: [_sourceProvider.overrideWithValue([for (var i = 1; i <= 25; i++) _Item(i)])],
    );
    addTearDown(container.dispose);
    await container.read(_listProvider.future);
    await container.read(_listProvider.notifier).setSearch('1');

    await container.read(_listProvider.notifier).refresh();

    expect(container.read(_listProvider).value!.query.search, '1');
  });

  test('updateItem modifie un élément localement sans recharger', () async {
    final container = ProviderContainer(overrides: [_sourceProvider.overrideWithValue([_Item(1), _Item(2)])]);
    addTearDown(container.dispose);
    await container.read(_listProvider.future);
    final controller = container.read(_listProvider.notifier);
    final callsBefore = controller.fetchCalls;

    controller.updateItem((i) => i.id == 2, (i) => _Item(20));

    expect(container.read(_listProvider).value!.items.map((i) => i.id), [1, 20]);
    expect(controller.fetchCalls, callsBefore); // aucune requête déclenchée.
  });

  test('removeItem retire un élément et décrémente le total', () async {
    final container = ProviderContainer(overrides: [_sourceProvider.overrideWithValue([_Item(1), _Item(2)])]);
    addTearDown(container.dispose);
    await container.read(_listProvider.future);

    container.read(_listProvider.notifier).removeItem((i) => i.id == 1);
    final state = container.read(_listProvider).value!;

    expect(state.items.map((i) => i.id), [2]);
    expect(state.total, 1);
  });
}
