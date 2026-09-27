import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/technology.dart';
import '../data/technology_repository.dart';

final technologyListProvider = AsyncNotifierProvider<TechnologyListController, ListState<Technology>>(
  TechnologyListController.new,
);

class TechnologyListController extends PaginatedListController<Technology> {
  @override
  Future<Paginated<Technology>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(technologyRepositoryProvider)
        .list(page: page, search: query.search, category: query.filters['category'] as String?);
  }
}
