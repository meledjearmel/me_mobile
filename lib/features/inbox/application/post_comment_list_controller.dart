import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/post_comment.dart';

final postCommentListProvider = AsyncNotifierProvider<PostCommentListController, ListState<PostComment>>(
  PostCommentListController.new,
);

class PostCommentListController extends PaginatedListController<PostComment> {
  @override
  Future<Paginated<PostComment>> fetchPage({required int page, required ListQuery query}) => ref
      .read(postCommentRepositoryProvider)
      .list(page: page, search: query.search, status: query.filters['status'] as String?);
}
