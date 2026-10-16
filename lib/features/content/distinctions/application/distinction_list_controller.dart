import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/distinction.dart';
import '../data/distinction_repository.dart';

final distinctionListProvider = AsyncNotifierProvider<DistinctionListController, ListState<Distinction>>(
  DistinctionListController.new,
);

class DistinctionListController extends PaginatedListController<Distinction> {
  @override
  Future<Paginated<Distinction>> fetchPage({required int page, required ListQuery query}) => ref
      .read(distinctionRepositoryProvider)
      .list(page: page, search: query.search, status: query.filters['status'] as String?);
}
