import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/domain.dart';
import '../data/domain_repository.dart';

final domainListProvider = AsyncNotifierProvider<DomainListController, ListState<Domain>>(DomainListController.new);

class DomainListController extends PaginatedListController<Domain> {
  @override
  Future<Paginated<Domain>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(domainRepositoryProvider)
        .list(page: page, search: query.search, status: query.filters['status'] as String?);
  }
}
