import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../application/uses_item_list_controller.dart';
import '../data/uses_item.dart';
import 'uses_item_form_screen.dart';

/// Page « Uses » du site : matériel, outils, applications et services.
class UsesItemsListScreen extends ConsumerWidget {
  const UsesItemsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => UsesItemFormScreen(id: id)));
    ref.invalidate(usesItemListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usesItemListProvider);
    final notifier = ref.read(usesItemListProvider.notifier);
    final currentCategory = state.value?.query.filters['category'] as String?;

    return ResourceListScaffold<UsesItem>(
      title: 'Uses',
      searchHint: 'Nom, description…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(usesItemListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.devices_other_outlined,
      emptyTitle: 'Aucun élément pour l\'instant',
      emptyDescription: 'Ajoutez votre matériel, vos outils et vos services avec le bouton +.',
      filterChips: [
        for (final category in UsesCategory.values)
          ChoiceChip(
            label: Text(category.label),
            selected: currentCategory == category.wireValue,
            onSelected: (_) => notifier.setFilters(
              currentCategory == category.wireValue ? const {} : {'category': category.wireValue},
            ),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, item) => ListTile(
        onTap: () => _openForm(context, ref, id: item.id),
        leading: Icon(item.category.icon),
        title: Text(item.name),
        subtitle: Text(
          item.description.display.isEmpty ? item.category.label : item.description.display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: item.status == PublicationStatus.draft ? const StatusBadge('Brouillon', prominent: true) : null,
      ),
    );
  }
}
