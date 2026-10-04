import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/certification.dart';
import '../data/certification_repository.dart';

final certificationListProvider = AsyncNotifierProvider<CertificationListController, ListState<Certification>>(
  CertificationListController.new,
);

class CertificationListController extends PaginatedListController<Certification> {
  @override
  Future<Paginated<Certification>> fetchPage({required int page, required ListQuery query}) => ref
      .read(certificationRepositoryProvider)
      .list(page: page, search: query.search, kind: query.filters['kind'] as String?);
}
