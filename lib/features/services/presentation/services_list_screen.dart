import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/content_status_repository.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/publication_status.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../../../shared/widgets/ai_badge.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
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

  /// Publier ou repasser en brouillon sans ouvrir le formulaire.
  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Service service) async {
    final target = service.status == PublicationStatus.published
        ? PublicationStatus.draft
        : PublicationStatus.published;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          target == PublicationStatus.published
              ? 'Publier « ${service.title.display} » ?'
              : 'Masquer « ${service.title.display} » ?',
        ),
        content: Text(
          target == PublicationStatus.published
              ? 'L\'offre apparaîtra sur la page « Services » du site.'
              : 'L\'offre disparaîtra de la page « Services » du site.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(target == PublicationStatus.published ? 'Publier' : 'Masquer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final status = await ref.read(contentStatusRepositoryProvider).update('service', service.id, target.wireValue);
      ref
          .read(serviceListProvider.notifier)
          .updateItem((s) => s.id == service.id, (s) => s.copyWith(status: PublicationStatus.fromWire(status)));
      messenger.showSnackBar(
        SnackBar(content: Text(target == PublicationStatus.published ? 'Offre publiée.' : 'Offre masquée.')),
      );
    } on ValidationException catch (e) {
      // Publier sans le titre anglais est refusé.
      messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((m) => m).firstOrNull ?? e.message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
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
          onLongPress: () => _toggleStatus(context, ref, service),
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
              status: StatusBadge(service.status.label, prominent: isDraft),
            ),
          ),
        );
      },
      header: Text(
        'Appui long sur une offre : la publier ou la masquer.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
