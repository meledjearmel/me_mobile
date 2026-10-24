import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/proposal.dart';
import '../data/proposal_repository.dart';

final proposalListProvider = AsyncNotifierProvider<ProposalListController, ListState<Proposal>>(
  ProposalListController.new,
);

class ProposalListController extends PaginatedListController<Proposal> {
  @override
  Future<Paginated<Proposal>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(proposalRepositoryProvider)
        .list(
          page: page,
          search: query.search,
          platform: query.filters['platform'] as String?,
          status: query.filters['status'] as String?,
        );
  }
}
