import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/surfaces.dart';
import '../application/job_application_list_controller.dart';
import '../data/job_application.dart';
import 'job_application_detail_screen.dart';
import 'job_application_form_screen.dart';
import 'widgets/job_application_status_badge.dart';

class JobApplicationsListScreen extends ConsumerWidget {
  const JobApplicationsListScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
    ref.invalidate(jobApplicationListProvider);
  }

  /// Après une création, la fiche s'ouvre pour partager le lien tout de suite.
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context)
        .push<Object?>(MaterialPageRoute(builder: (context) => const JobApplicationFormScreen()));
    if (created is JobApplication && context.mounted) {
      await _open(context, ref, JobApplicationDetailScreen(id: created.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobApplicationListProvider);
    final notifier = ref.read(jobApplicationListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<JobApplication>(
      title: 'Candidatures',
      searchHint: 'Entreprise, poste, contact…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(jobApplicationListProvider),
      onCreate: () => _create(context, ref),
      emptyIcon: Icons.send_outlined,
      emptyTitle: 'Aucune page de candidature pour l\'instant',
      emptyDescription: 'Créez-en une avec le bouton +, ou laissez l\'IA la préparer à partir d\'une offre.',
      filterChips: [
        for (final status in JobApplicationStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: currentStatus == status.wireValue,
            onSelected: (_) =>
                notifier.setFilters(currentStatus == status.wireValue ? const {} : {'status': status.wireValue}),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, application) => ListCardTile(
        onTap: () => _open(context, ref, JobApplicationDetailScreen(id: application.id)),
        leading: InitialsTile(application.company),
        title: application.company,
        subtitle: application.position,
        meta:
            '${application.viewsCount} vue${application.viewsCount > 1 ? 's' : ''} · '
            '${application.cvDownloadsCount} CV',
        badge: JobApplicationStatusBadge(application),
      ),
    );
  }
}
