import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../application/experience_list_controller.dart';
import '../data/experience.dart';
import 'experience_form_screen.dart';

class ExperiencesListScreen extends ConsumerWidget {
  const ExperiencesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExperienceFormScreen(id: id)));
    ref.invalidate(experienceListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(experienceListProvider);
    final notifier = ref.read(experienceListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<Experience>(
      title: 'Expériences',
      searchHint: 'Société, rôle, lieu…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(experienceListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.timeline_rounded,
      emptyTitle: 'Aucune expérience pour l\'instant',
      emptyDescription: 'Créez votre première expérience avec le bouton +.',
      filterChips: [
        for (final status in PublicationStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: currentStatus == status.wireValue,
            onSelected: (_) => notifier.setFilters(
              currentStatus == status.wireValue ? const {} : {'status': status.wireValue},
            ),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, experience) => ListTile(
        onTap: () => _openForm(context, ref, id: experience.id),
        leading: const Icon(Icons.timeline_rounded),
        title: Text(experience.company),
        subtitle: Text(experience.role.display),
        trailing: StatusBadge(experience.status.label, prominent: experience.status == PublicationStatus.draft),
      ),
    );
  }
}
