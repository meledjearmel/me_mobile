import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/mcp_activity.dart';

final mcpActivityListProvider = AsyncNotifierProvider<McpActivityListController, ListState<McpActivity>>(
  McpActivityListController.new,
);

/// Clients et outils connus, mis à jour à chaque page chargée.
final mcpActivityFilterOptionsProvider = StateProvider<McpActivityFilterOptions>(
  (ref) => const McpActivityFilterOptions(),
);

class McpActivityListController extends PaginatedListController<McpActivity> {
  @override
  Future<Paginated<McpActivity>> fetchPage({required int page, required ListQuery query}) async {
    final result = await ref
        .read(mcpActivityRepositoryProvider)
        .list(
          page: page,
          search: query.search,
          client: query.filters['client'] as String?,
          name: query.filters['name'] as String?,
          kind: query.filters['kind'] as String?,
          status: query.filters['status'] as String?,
          days: query.filters['days'] as int?,
        );
    ref.read(mcpActivityFilterOptionsProvider.notifier).state = result.filters;
    return result.page;
  }

  /// Change un seul filtre en gardant les autres ; `null` le retire.
  Future<void> setFilter(String key, Object? value) {
    final filters = {...?state.value?.query.filters}..remove(key);
    return setFilters({...filters, key: ?value});
  }
}
