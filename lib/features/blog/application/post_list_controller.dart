import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/post.dart';
import '../data/post_repository.dart';

final postListProvider = AsyncNotifierProvider<PostListController, ListState<Post>>(PostListController.new);

class PostListController extends PaginatedListController<Post> {
  @override
  Future<Paginated<Post>> fetchPage({required int page, required ListQuery query}) => ref
      .read(postRepositoryProvider)
      .list(
        page: page,
        search: query.search,
        status: query.filters['status'] as String?,
        isFeatured: query.filters['is_featured'] as bool?,
      );
}
