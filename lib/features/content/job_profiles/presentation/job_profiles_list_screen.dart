import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../application/job_profile_list_controller.dart';
import '../data/job_profile.dart';
import 'job_profile_form_screen.dart';

class JobProfilesListScreen extends ConsumerWidget {
  const JobProfilesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => JobProfileFormScreen(id: id)));
    ref.invalidate(jobProfileListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobProfileListProvider);
    final notifier = ref.read(jobProfileListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<JobProfile>(
      title: 'Profils métier',
      searchHint: 'Clé, libellé…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(jobProfileListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.assignment_ind_outlined,
      emptyTitle: 'Aucun profil métier pour l\'instant',
      emptyDescription: 'Créez votre premier profil métier avec le bouton +.',
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
      itemBuilder: (context, jobProfile) => ListTile(
        onTap: () => _openForm(context, ref, id: jobProfile.id),
        leading: const Icon(Icons.assignment_ind_outlined),
        title: Text(jobProfile.label.display),
        subtitle: Text(jobProfile.key),
        trailing: StatusBadge(jobProfile.status.label, prominent: jobProfile.status == PublicationStatus.draft),
      ),
    );
  }
}
