import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/education.dart';
import '../data/education_repository.dart';

final educationListProvider = AsyncNotifierProvider<EducationListController, ListState<Education>>(
  EducationListController.new,
);

class EducationListController extends PaginatedListController<Education> {
  @override
  Future<Paginated<Education>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(educationRepositoryProvider)
        .list(page: page, search: query.search, status: query.filters['status'] as String?);
  }
}
