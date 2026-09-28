import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../application/technology_category_list_controller.dart';
import '../data/technology_category.dart';
import 'technology_category_form_screen.dart';

class TechnologyCategoriesListScreen extends ConsumerWidget {
  const TechnologyCategoriesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => TechnologyCategoryFormScreen(id: id)));
    ref.invalidate(technologyCategoryListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(technologyCategoryListProvider);
    final notifier = ref.read(technologyCategoryListProvider.notifier);

    return ResourceListScaffold<TechnologyCategory>(
      title: 'Catégories de technologies',
      searchHint: 'Clé, libellé…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(technologyCategoryListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.label_outline_rounded,
      emptyTitle: 'Aucune catégorie pour l\'instant',
      emptyDescription: 'Créez votre première catégorie avec le bouton +.',
      itemBuilder: (context, category) => ListTile(
        onTap: () => _openForm(context, ref, id: category.id),
        leading: const Icon(Icons.label_outline_rounded),
        title: Text(category.label.display),
        subtitle: Text(category.key),
      ),
    );
  }
}
