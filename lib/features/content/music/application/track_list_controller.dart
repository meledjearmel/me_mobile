import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/track.dart';
import '../data/track_repository.dart';

final trackListProvider = AsyncNotifierProvider<TrackListController, ListState<Track>>(TrackListController.new);

class TrackListController extends PaginatedListController<Track> {
  @override
  Future<Paginated<Track>> fetchPage({required int page, required ListQuery query}) {
    return ref
        .read(trackRepositoryProvider)
        .list(page: page, search: query.search, musicGenreId: query.filters['music_genre_id'] as int?);
  }
}
