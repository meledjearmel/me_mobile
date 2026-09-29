import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/congratulation.dart';
import '../data/congratulation_repository.dart';

final congratulationListProvider = AsyncNotifierProvider<CongratulationListController, ListState<Congratulation>>(
  CongratulationListController.new,
);

class CongratulationListController extends PaginatedListController<Congratulation> {
  @override
  Future<Paginated<Congratulation>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(congratulationRepositoryProvider)
        .list(page: page, search: query.search, source: query.filters['source']);
  }
}
