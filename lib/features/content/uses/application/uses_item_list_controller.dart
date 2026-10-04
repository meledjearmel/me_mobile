import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/uses_item.dart';
import '../data/uses_item_repository.dart';

final usesItemListProvider = AsyncNotifierProvider<UsesItemListController, ListState<UsesItem>>(
  UsesItemListController.new,
);

class UsesItemListController extends PaginatedListController<UsesItem> {
  @override
  Future<Paginated<UsesItem>> fetchPage({required int page, required ListQuery query}) => ref
      .read(usesItemRepositoryProvider)
      .list(
        page: page,
        search: query.search,
        category: query.filters['category'] as String?,
        status: query.filters['status'] as String?,
      );
}
