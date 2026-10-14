import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/job_application.dart';
import '../data/job_application_repository.dart';

final jobApplicationListProvider = AsyncNotifierProvider<JobApplicationListController, ListState<JobApplication>>(
  JobApplicationListController.new,
);

class JobApplicationListController extends PaginatedListController<JobApplication> {
  @override
  Future<Paginated<JobApplication>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(jobApplicationRepositoryProvider)
        .list(page: page, search: query.search, status: query.filters['status'] as String?);
  }
}
