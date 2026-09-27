import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/skill.dart';
import '../data/skill_repository.dart';

final skillListProvider = AsyncNotifierProvider<SkillListController, ListState<Skill>>(SkillListController.new);

class SkillListController extends PaginatedListController<Skill> {
  @override
  Future<Paginated<Skill>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(skillRepositoryProvider).list(
          page: page,
          search: query.search,
          domainId: query.filters['domain_id'] as int?,
          status: query.filters['status'] as String?,
        );
  }
}
