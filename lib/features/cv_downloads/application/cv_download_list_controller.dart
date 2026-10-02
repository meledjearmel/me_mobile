import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/cv_download.dart';
import '../data/cv_download_repository.dart';

final cvDownloadListProvider = AsyncNotifierProvider<CvDownloadListController, ListState<CvDownload>>(
  CvDownloadListController.new,
);

class CvDownloadListController extends PaginatedListController<CvDownload> {
  @override
  Future<Paginated<CvDownload>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(cvDownloadRepositoryProvider)
        .list(page: page, search: query.search, locale: query.filters['locale'] as String?);
  }
}
