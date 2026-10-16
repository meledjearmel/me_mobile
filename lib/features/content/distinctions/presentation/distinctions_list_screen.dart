import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/status_sheet.dart';
import '../../../../shared/widgets/ai_badge.dart';
import '../application/distinction_list_controller.dart';
import '../data/distinction.dart';
import 'distinction_form_screen.dart';

class DistinctionsListScreen extends ConsumerWidget {
  const DistinctionsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => DistinctionFormScreen(id: id)));
    ref.invalidate(distinctionListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(distinctionListProvider);
    final notifier = ref.read(distinctionListProvider.notifier);
    final isDraftFilter = state.value?.query.filters['status'] == 'draft';

    return ResourceListScaffold<Distinction>(
      title: 'Distinctions',
      searchHint: 'Intitulé, organisme…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(distinctionListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.emoji_events_outlined,
      emptyTitle: 'Aucune distinction pour l\'instant',
      emptyDescription: 'Ajoutez un prix reçu avec le bouton +.',
      filterChips: [
        ChoiceChip(
          label: const Text('Brouillon'),
          selected: isDraftFilter,
          onSelected: (_) => notifier.setFilters(isDraftFilter ? const {} : const {'status': 'draft'}),
          showCheckmark: false,
        ),
      ],
      itemBuilder: (context, distinction) => ListTile(
        onTap: () => _openForm(context, ref, id: distinction.id),
        // Appui long : publier ou repasser en brouillon sans ouvrir le formulaire.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'distinction',
          id: distinction.id,
          title: distinction.title.display,
          current: distinction.status.wireValue,
          options: [for (final s in PublicationStatus.values) (value: s.wireValue, label: s.label)],
          onChanged: () => ref.invalidate(distinctionListProvider),
        ),
        leading: const SizedBox.square(dimension: 40, child: Icon(Icons.emoji_events_outlined)),
        title: Text(distinction.title.display),
        subtitle: Text(
          [
            distinction.issuer,
            if (distinction.contextLabel != null && distinction.contextLabel!.isNotEmpty) distinction.contextLabel!,
            DateFormat('MMM y', 'fr_FR').format(distinction.awardedOn),
            '${distinction.congratulationsCount} félicitation${distinction.congratulationsCount > 1 ? 's' : ''}',
          ].join(' · '),
        ),
        trailing: distinction.status == PublicationStatus.draft
            ? StatusWithAiBadge(
                draftedBy: distinction.draftedBy,
                isDraft: true,
                status: const StatusBadge('Brouillon', prominent: true),
              )
            : null,
      ),
    );
  }
}
