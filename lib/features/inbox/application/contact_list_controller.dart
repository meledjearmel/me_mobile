import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/contact.dart';
import '../data/contact_repository.dart';

final contactListProvider = AsyncNotifierProvider<ContactListController, ListState<Contact>>(ContactListController.new);

class ContactListController extends PaginatedListController<Contact> {
  @override
  Future<Paginated<Contact>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(contactRepositoryProvider).list(
          page: page,
          search: query.search,
          status: query.filters['status'] as String?,
        );
  }
}
