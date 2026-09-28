import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/technology_list_controller.dart';
import '../data/technology.dart';
import '../data/technology_category_repository.dart';
import 'technology_form_screen.dart';
import 'technology_logo.dart';

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
    final currentCategory = state.value?.query.filters['category_id'] as int?;
    final categories = ref.watch(technologyCategoriesAllProvider).value ?? const [];

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
        for (final category in categories)
          ChoiceChip(
            label: Text(category.label.display),
            selected: currentCategory == category.id,
            onSelected: (_) => notifier.setFilters(
              currentCategory == category.id ? const {} : {'category_id': category.id},
            ),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, technology) => ListTile(
        onTap: () => _openForm(context, ref, id: technology.id),
        leading: TechnologyLogo(lightUrl: technology.iconLightUrl, darkUrl: technology.iconDarkUrl),
        title: Text(technology.name),
        subtitle: Text(technology.category?.label.display ?? '—'),
      ),
    );
  }
}
