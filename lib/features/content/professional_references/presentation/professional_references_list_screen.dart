import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/professional_reference_list_controller.dart';
import '../data/professional_reference.dart';
import 'professional_reference_form_screen.dart';

class ProfessionalReferencesListScreen extends ConsumerWidget {
  const ProfessionalReferencesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfessionalReferenceFormScreen(id: id)));
    ref.invalidate(professionalReferenceListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(professionalReferenceListProvider);
    final notifier = ref.read(professionalReferenceListProvider.notifier);
    final currentIsPublic = state.value?.query.filters['is_public'] as bool?;

    return ResourceListScaffold<ProfessionalReference>(
      title: 'Références',
      searchHint: 'Nom, rôle, société, e-mail…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(professionalReferenceListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.handshake_outlined,
      emptyTitle: 'Aucune référence pour l\'instant',
      emptyDescription: 'Créez votre première référence avec le bouton +.',
      filterChips: [
        ChoiceChip(
          label: const Text('Jointes au CV'),
          selected: currentIsPublic == true,
          onSelected: (_) => notifier.setFilters(currentIsPublic == true ? const {} : {'is_public': true}),
          showCheckmark: false,
        ),
      ],
      itemBuilder: (context, reference) => ListTile(
        onTap: () => _openForm(context, ref, id: reference.id),
        leading: Icon(reference.isPublic ? Icons.badge_rounded : Icons.badge_outlined),
        title: Text(reference.name),
        subtitle: Text(
          [reference.role, reference.company].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      ),
    );
  }
}
