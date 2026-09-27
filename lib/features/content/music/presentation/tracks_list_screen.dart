import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/track_list_controller.dart';
import '../application/track_player_controller.dart';
import '../data/music_genre_repository.dart';
import '../data/track.dart';
import 'track_form_screen.dart';

class TracksListScreen extends ConsumerWidget {
  const TracksListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await ref.read(trackPlayerProvider.notifier).stop();
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => TrackFormScreen(id: id)));
    ref.invalidate(trackListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackListProvider);
    final notifier = ref.read(trackListProvider.notifier);
    final player = ref.watch(trackPlayerProvider);
    final currentGenreId = state.value?.query.filters['music_genre_id'] as int?;
    final genres = ref.watch(musicGenresAllProvider).value ?? [];

    return ResourceListScaffold<Track>(
      title: 'Pistes',
      searchHint: 'Titre, artiste…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(trackListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.music_note_outlined,
      emptyTitle: 'Aucune piste pour l\'instant',
      emptyDescription: 'Ajoutez votre première piste avec le bouton +.',
      filterChips: [
        for (final genre in genres)
          ChoiceChip(
            label: Text(genre.label.display),
            selected: currentGenreId == genre.id,
            onSelected: (_) => notifier.setFilters(
              currentGenreId == genre.id ? const {} : {'music_genre_id': genre.id},
            ),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, track) {
        final isCurrentTrack = player.playingTrackId == track.id;
        return ListTile(
          onTap: () => _openForm(context, ref, id: track.id),
          leading: track.audioUrl == null
              ? const Icon(Icons.music_off_outlined)
              : IconButton(
                  tooltip: isCurrentTrack && player.isLoading
                      ? 'Chargement…'
                      : isCurrentTrack
                          ? 'Mettre en pause'
                          : 'Lire cette piste',
                  icon: isCurrentTrack && player.isLoading
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isCurrentTrack ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                  onPressed: () => ref.read(trackPlayerProvider.notifier).toggle(track.id, track.audioUrl!),
                ),
          title: Text(track.title),
          subtitle: Text(track.artist?.isNotEmpty == true ? track.artist! : 'Artiste inconnu'),
        );
      },
    );
  }
}
