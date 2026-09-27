import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/technology_list_controller.dart';
import '../data/technology.dart';
import 'technology_form_screen.dart';

class TechnologiesListScreen extends ConsumerWidget {
  const TechnologiesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => TechnologyFormScreen(id: id)));
    ref.invalidate(technologyListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(technologyListProvider);
    final notifier = ref.read(technologyListProvider.notifier);
    final currentCategory = state.value?.query.filters['category'] as String?;

    return ResourceListScaffold<Technology>(
      title: 'Technologies',
      searchHint: 'Nom…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(technologyListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.memory_rounded,
      emptyTitle: 'Aucune technologie pour l\'instant',
      emptyDescription: 'Créez votre première technologie avec le bouton +.',
      filterChips: [
        for (final category in TechnologyCategory.values)
          ChoiceChip(
            label: Text(category.label),
            selected: currentCategory == category.wireValue,
            onSelected: (_) => notifier.setFilters(
              currentCategory == category.wireValue ? const {} : {'category': category.wireValue},
            ),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, technology) => ListTile(
        onTap: () => _openForm(context, ref, id: technology.id),
        leading: const Icon(Icons.memory_rounded),
        title: Text(technology.name),
        subtitle: Text(technology.category.label),
      ),
    );
  }
}
