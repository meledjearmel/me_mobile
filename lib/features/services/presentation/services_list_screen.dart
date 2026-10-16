import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../core/models/publication_status.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../../../shared/widgets/ai_badge.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_sheet.dart';
import '../../../shared/widgets/status_tones.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/service.dart';
import '../data/service_repository.dart';
import 'service_form_screen.dart';

final serviceListProvider = AsyncNotifierProvider<ServiceListController, ListState<Service>>(ServiceListController.new);

class ServiceListController extends PaginatedListController<Service> {
  @override
  Future<Paginated<Service>> fetchPage({required int page, required ListQuery query}) => ref
      .read(serviceRepositoryProvider)
      .list(page: page, search: query.search, status: query.filters['status'] as String?);
}

/// Offres de la page « Services », dans leur ordre d'affichage.
class ServicesListScreen extends ConsumerWidget {
  const ServicesListScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ServiceFormScreen(id: id)));
    ref.invalidate(serviceListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceListProvider);
    final notifier = ref.read(serviceListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<Service>(
      title: 'Services',
      searchHint: 'Titre, ancre…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(serviceListProvider),
      onCreate: () => _open(context, ref),
      emptyIcon: Icons.storefront_outlined,
      emptyTitle: 'Aucune offre pour l\'instant',
      emptyDescription: 'Sans offre publiée, la page « Services » du site n\'existe pas.',
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
      itemBuilder: (context, service) {
        final isDraft = service.status == PublicationStatus.draft;
        return GestureDetector(
          // Appui long : publier ou repasser en brouillon sans ouvrir le formulaire.
          onLongPress: () => showStatusSheet(
            context,
            ref,
            type: 'service',
            id: service.id,
            title: service.title.display,
            current: service.status.wireValue,
            options: [for (final s in PublicationStatus.values) (value: s.wireValue, label: s.label)],
            onChanged: () => ref.invalidate(serviceListProvider),
          ),
          child: ListCardTile(
            onTap: () => _open(context, ref, id: service.id),
            leading: const IconTile(Icons.storefront_outlined),
            title: service.title.display,
            subtitle: [
              service.priceMode.label,
              if (service.tagline.display.isNotEmpty) service.tagline.display,
            ].join(' · '),
            badge: StatusWithAiBadge(
              draftedBy: service.draftedBy,
              isDraft: isDraft,
              status: TypedStatusBadge(type: 'service', status: service.status.wireValue, label: service.status.label),
            ),
          ),
        );
      },
      header: Text(
        'Appui long sur une offre : changer son statut.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
