import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_sheet.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../../../shared/widgets/ai_badge.dart';
import '../application/education_list_controller.dart';
import '../data/education.dart';
import 'education_form_screen.dart';

class EducationsListScreen extends ConsumerWidget {
  const EducationsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => EducationFormScreen(id: id)));
    ref.invalidate(educationListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(educationListProvider);
    final notifier = ref.read(educationListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<Education>(
      title: 'Formations',
      searchHint: 'Établissement, diplôme…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(educationListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.school_outlined,
      emptyTitle: 'Aucune formation pour l\'instant',
      emptyDescription: 'Créez votre première formation avec le bouton +.',
      filterChips: [
        for (final status in PublicationStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: currentStatus == status.wireValue,
            onSelected: (_) =>
                notifier.setFilters(currentStatus == status.wireValue ? const {} : {'status': status.wireValue}),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, education) => ListTile(
        onTap: () => _openForm(context, ref, id: education.id),
        // Appui long : publier ou repasser en brouillon sans ouvrir le formulaire.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'education',
          id: education.id,
          title: education.degree.display,
          current: education.status.wireValue,
          options: [for (final s in PublicationStatus.values) (value: s.wireValue, label: s.label)],
          onChanged: () => ref.invalidate(educationListProvider),
        ),
        leading: const Icon(Icons.school_outlined),
        title: Text(education.institution),
        subtitle: Text(education.degree.display),
        trailing: StatusWithAiBadge(
          draftedBy: education.draftedBy,
          isDraft: education.status == PublicationStatus.draft,
          status: TypedStatusBadge(
            type: 'education',
            status: education.status.wireValue,
            label: education.status.label,
          ),
        ),
      ),
    );
  }
}
