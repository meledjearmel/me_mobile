import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/job_profile.dart';
import '../data/job_profile_repository.dart';

final jobProfileListProvider = AsyncNotifierProvider<JobProfileListController, ListState<JobProfile>>(
  JobProfileListController.new,
);

class JobProfileListController extends PaginatedListController<JobProfile> {
  @override
  Future<Paginated<JobProfile>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(jobProfileRepositoryProvider)
        .list(page: page, search: query.search, status: query.filters['status'] as String?);
  }
}
