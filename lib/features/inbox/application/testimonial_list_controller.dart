import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/testimonial.dart';
import '../data/testimonial_repository.dart';

final testimonialListProvider = AsyncNotifierProvider<TestimonialListController, ListState<Testimonial>>(
  TestimonialListController.new,
);

class TestimonialListController extends PaginatedListController<Testimonial> {
  @override
  Future<Paginated<Testimonial>> fetchPage({required int page, required ListQuery query}) {
    final isFeatured = query.filters['is_featured'];
    return ref.read(testimonialRepositoryProvider).list(
          page: page,
          search: query.search,
          status: query.filters['status'] as String?,
          isFeatured: isFeatured as bool?,
        );
  }
}
