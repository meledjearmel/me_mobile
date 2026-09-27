import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/reference_repository.dart';
import '../application/skill_list_controller.dart';
import '../data/skill.dart';
import 'skill_form_screen.dart';

class SkillsListScreen extends ConsumerWidget {
  const SkillsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => SkillFormScreen(id: id)));
    ref.invalidate(skillListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(skillListProvider);
    final notifier = ref.read(skillListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;
    final currentDomainId = state.value?.query.filters['domain_id'] as int?;
    final domains = ref.watch(domainsRefProvider).value ?? [];

    return ResourceListScaffold<Skill>(
      title: 'Compétences',
      searchHint: 'Nom…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(skillListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.psychology_outlined,
      emptyTitle: 'Aucune compétence pour l\'instant',
      emptyDescription: 'Créez votre première compétence avec le bouton +.',
      filterChips: [
        for (final status in PublicationStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: currentStatus == status.wireValue,
            onSelected: (_) {
              final filters = Map<String, Object?>.from(state.value?.query.filters ?? const {});
              if (currentStatus == status.wireValue) {
                filters.remove('status');
              } else {
                filters['status'] = status.wireValue;
              }
              notifier.setFilters(filters);
            },
            showCheckmark: false,
          ),
        for (final domain in domains)
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: parseHexColor(domain.color), radius: 8),
            label: Text(domain.label.display),
            selected: currentDomainId == domain.id,
            onSelected: (_) {
              final filters = Map<String, Object?>.from(state.value?.query.filters ?? const {});
              if (currentDomainId == domain.id) {
                filters.remove('domain_id');
              } else {
                filters['domain_id'] = domain.id;
              }
              notifier.setFilters(filters);
            },
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, skill) => ListTile(
        onTap: () => _openForm(context, ref, id: skill.id),
        leading: skill.domain != null
            ? CircleAvatar(backgroundColor: parseHexColor(skill.domain!.color), radius: 14)
            : const Icon(Icons.psychology_outlined),
        title: Text(skill.name.display),
        subtitle: Text(skill.domain?.label.display ?? ''),
        trailing: StatusBadge(skill.status.label, prominent: skill.status == PublicationStatus.draft),
      ),
    );
  }
}
