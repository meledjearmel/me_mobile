import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../application/celebration_list_controller.dart';
import '../data/celebration.dart';
import 'celebration_form_screen.dart';
import 'congratulations_screen.dart';

/// Surprises d'Armi : bonnes nouvelles annoncées au hasard aux visiteurs du site.
class CelebrationsListScreen extends ConsumerWidget {
  const CelebrationsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => CelebrationFormScreen(id: id)));
    ref.invalidate(celebrationListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(celebrationListProvider);
    final notifier = ref.read(celebrationListProvider.notifier);

    return ResourceListScaffold<Celebration>(
      title: 'Surprises',
      searchHint: 'Message…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(celebrationListProvider),
      onCreate: () => _openForm(context, ref),
      actions: [
        IconButton(
          tooltip: 'Félicitations reçues',
          icon: const Icon(Icons.emoji_events_outlined),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CongratulationsScreen())),
        ),
      ],
      emptyIcon: Icons.celebration_outlined,
      emptyTitle: 'Aucune surprise pour l\'instant',
      emptyDescription: 'Annoncez une bonne nouvelle aux visiteurs avec le bouton +.',
      itemBuilder: (context, celebration) => ListCardTile(
        onTap: () => _openForm(context, ref, id: celebration.id),
        leading: const IconTile(Icons.celebration_outlined, size: 38),
        title: celebration.message.display,
        subtitle:
            '${celebration.congratulationsCount} félicitation${celebration.congratulationsCount > 1 ? 's' : ''}'
            ' · ${celebration.chancePercent} % des visites',
        badge: StatusBadge(celebration.statusLabel, color: celebration.isLive ? context.appColors.accent : null),
      ),
    );
  }
}
