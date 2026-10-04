import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/blog_admin.dart';

final postTagListProvider = AsyncNotifierProvider<PostTagListController, ListState<PostTag>>(PostTagListController.new);

class PostTagListController extends PaginatedListController<PostTag> {
  @override
  Future<Paginated<PostTag>> fetchPage({required int page, required ListQuery query}) =>
      ref.read(blogAdminRepositoryProvider).tags(page: page, search: query.search);
}

final subscriberListProvider = AsyncNotifierProvider<SubscriberListController, ListState<Subscriber>>(
  SubscriberListController.new,
);

class SubscriberListController extends PaginatedListController<Subscriber> {
  @override
  Future<Paginated<Subscriber>> fetchPage({required int page, required ListQuery query}) => ref
      .read(blogAdminRepositoryProvider)
      .subscribers(page: page, search: query.search, status: query.filters['status'] as String?);
}
