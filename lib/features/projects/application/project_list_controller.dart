import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/project.dart';
import '../data/project_repository.dart';

final projectListProvider = AsyncNotifierProvider<ProjectListController, ListState<Project>>(ProjectListController.new);

class ProjectListController extends PaginatedListController<Project> {
  @override
  Future<Paginated<Project>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(projectRepositoryProvider).list(
          page: page,
          search: query.search,
          status: query.filters['status'] as String?,
          isFeatured: query.filters['is_featured'] as bool?,
          isOpenSource: query.filters['is_open_source'] as bool?,
        );
  }
}
