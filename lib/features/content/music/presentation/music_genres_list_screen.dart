import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/music_genre_list_controller.dart';
import '../data/music_genre.dart';
import 'music_genre_form_screen.dart';

class MusicGenresListScreen extends ConsumerWidget {
  const MusicGenresListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => MusicGenreFormScreen(id: id)));
    ref.invalidate(musicGenreListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicGenreListProvider);
    final notifier = ref.read(musicGenreListProvider.notifier);

    return ResourceListScaffold<MusicGenre>(
      title: 'Registres',
      searchHint: 'Clé, libellé…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(musicGenreListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.category_outlined,
      emptyTitle: 'Aucun registre pour l\'instant',
      emptyDescription: 'Créez votre premier registre avec le bouton +.',
      itemBuilder: (context, genre) => ListTile(
        onTap: () => _openForm(context, ref, id: genre.id),
        leading: const Icon(Icons.category_outlined),
        title: Text(genre.label.display),
        subtitle: Text(genre.key),
      ),
    );
  }
}
