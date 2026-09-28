import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/technology_category.dart';
import '../data/technology_category_repository.dart';

final technologyCategoryListProvider = AsyncNotifierProvider<TechnologyCategoryListController, ListState<TechnologyCategory>>(
  TechnologyCategoryListController.new,
);

class TechnologyCategoryListController extends PaginatedListController<TechnologyCategory> {
  @override
  Future<Paginated<TechnologyCategory>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(technologyCategoryRepositoryProvider).list(page: page, search: query.search);
  }
}
