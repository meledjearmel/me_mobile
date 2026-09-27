import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/trash_item.dart';
import '../data/trash_repository.dart';

final trashListProvider = AsyncNotifierProvider<TrashListController, ListState<TrashItem>>(TrashListController.new);

class TrashListController extends PaginatedListController<TrashItem> {
  @override
  Future<Paginated<TrashItem>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(trashRepositoryProvider).list(page: page, search: query.search, type: query.filters['type'] as String?);
  }
}
