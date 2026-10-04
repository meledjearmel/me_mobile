import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/review_invitation.dart';

final reviewInvitationListProvider = AsyncNotifierProvider<ReviewInvitationListController, ListState<ReviewInvitation>>(
  ReviewInvitationListController.new,
);

class ReviewInvitationListController extends PaginatedListController<ReviewInvitation> {
  @override
  Future<Paginated<ReviewInvitation>> fetchPage({required int page, required ListQuery query}) => ref
      .read(reviewInvitationRepositoryProvider)
      .list(page: page, search: query.search, status: query.filters['status'] as String?);
}
