import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/experience.dart';
import '../data/experience_repository.dart';

final experienceListProvider = AsyncNotifierProvider<ExperienceListController, ListState<Experience>>(
  ExperienceListController.new,
);

class ExperienceListController extends PaginatedListController<Experience> {
  @override
  Future<Paginated<Experience>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(experienceRepositoryProvider)
        .list(page: page, search: query.search, status: query.filters['status'] as String?);
  }
}
