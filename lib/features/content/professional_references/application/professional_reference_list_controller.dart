import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/professional_reference.dart';
import '../data/professional_reference_repository.dart';

final professionalReferenceListProvider =
    AsyncNotifierProvider<ProfessionalReferenceListController, ListState<ProfessionalReference>>(
  ProfessionalReferenceListController.new,
);

class ProfessionalReferenceListController extends PaginatedListController<ProfessionalReference> {
  @override
  Future<Paginated<ProfessionalReference>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(professionalReferenceRepositoryProvider)
        .list(page: page, search: query.search, isPublic: query.filters['is_public'] as bool?);
  }
}
