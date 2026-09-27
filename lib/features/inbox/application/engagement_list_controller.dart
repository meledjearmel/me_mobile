import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/engagement.dart';
import '../data/engagement_repository.dart';

final engagementListProvider = AsyncNotifierProvider<EngagementListController, ListState<Engagement>>(
  EngagementListController.new,
);

class EngagementListController extends PaginatedListController<Engagement> {
  @override
  Future<Paginated<Engagement>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(engagementRepositoryProvider).list(
          page: page,
          search: query.search,
          type: query.filters['type'] as String?,
          status: query.filters['status'] as String?,
        );
  }
}
