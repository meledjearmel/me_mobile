import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/track_player_controller.dart';

/// Barre de lecture persistante (§4.3), affichée au-dessus de la navigation
/// de [AppShell] tant qu'une piste est chargée (en lecture ou en pause),
/// même après avoir quitté l'écran Pistes.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(trackPlayerProvider);
    final track = player.track;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final controller = ref.read(trackPlayerProvider.notifier);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: controller.positionStream,
              builder: (context, snapshot) {
                final durationMs = controller.duration?.inMilliseconds ?? 0;
                final progress = durationMs == 0 ? 0.0 : (snapshot.data?.inMilliseconds ?? 0) / durationMs;
                return LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: player.isLoading
                        ? 'Chargement…'
                        : player.isPlaying
                            ? 'Mettre en pause'
                            : 'Reprendre la lecture',
                    icon: player.isLoading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                    onPressed: player.isLoading ? null : controller.togglePlayPause,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          track.artist?.isNotEmpty == true ? track.artist! : 'Artiste inconnu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Arrêter la lecture',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: controller.stop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
