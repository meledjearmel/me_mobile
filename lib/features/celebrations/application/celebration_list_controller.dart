import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/celebration.dart';
import '../data/celebration_repository.dart';

final celebrationListProvider = AsyncNotifierProvider<CelebrationListController, ListState<Celebration>>(
  CelebrationListController.new,
);

class CelebrationListController extends PaginatedListController<Celebration> {
  @override
  Future<Paginated<Celebration>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(celebrationRepositoryProvider).list(page: page, search: query.search);
  }
}
