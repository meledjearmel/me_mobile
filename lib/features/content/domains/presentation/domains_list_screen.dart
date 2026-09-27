import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../application/domain_list_controller.dart';
import '../data/domain.dart';
import 'domain_form_screen.dart';

class DomainsListScreen extends ConsumerWidget {
  const DomainsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => DomainFormScreen(id: id)));
    ref.invalidate(domainListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(domainListProvider);
    final notifier = ref.read(domainListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<Domain>(
      title: 'Domaines',
      searchHint: 'Clé, libellé…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(domainListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.category_outlined,
      emptyTitle: 'Aucun domaine pour l\'instant',
      emptyDescription: 'Créez votre premier domaine avec le bouton +.',
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
      itemBuilder: (context, domain) => ListTile(
        onTap: () => _openForm(context, ref, id: domain.id),
        leading: CircleAvatar(backgroundColor: parseHexColor(domain.color), radius: 14),
        title: Text(domain.label.display),
        subtitle: Text(domain.key),
        trailing: StatusBadge(domain.status.label, prominent: domain.status == PublicationStatus.draft),
      ),
    );
  }
}
