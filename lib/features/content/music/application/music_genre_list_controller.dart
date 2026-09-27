import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/pagination/list_query.dart';
import '../../../../shared/pagination/paginated_list_controller.dart';
import '../data/music_genre.dart';
import '../data/music_genre_repository.dart';

final musicGenreListProvider = AsyncNotifierProvider<MusicGenreListController, ListState<MusicGenre>>(
  MusicGenreListController.new,
);

class MusicGenreListController extends PaginatedListController<MusicGenre> {
  @override
  Future<Paginated<MusicGenre>> fetchPage({required int page, required ListQuery query}) {
    return ref.read(musicGenreRepositoryProvider).list(page: page, search: query.search);
  }
}
