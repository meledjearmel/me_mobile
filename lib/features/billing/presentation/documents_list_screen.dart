import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_sheet.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/commercial_document.dart';
import 'document_detail_screen.dart';
import 'document_form_screen.dart';
import 'widgets/document_status_badge.dart';

final _money = NumberFormat.decimalPattern('fr_FR');

/// « 1 250 000 XOF ».
String formatMoney(int amount, String currency) => '${_money.format(amount)} $currency';

final documentListProvider = AsyncNotifierProvider<DocumentListController, ListState<CommercialDocument>>(
  DocumentListController.new,
);

class DocumentListController extends PaginatedListController<CommercialDocument> {
  @override
  Future<Paginated<CommercialDocument>> fetchPage({required int page, required ListQuery query}) => ref
      .read(commercialDocumentRepositoryProvider)
      .list(
        page: page,
        search: query.search,
        type: query.filters['type'] as String?,
        status: query.filters['status'] as String?,
        reminder: query.filters['reminder'] == true,
      );

  /// Change un filtre en gardant les autres ; `null` le retire.
  Future<void> setFilter(String key, Object? value) {
    final filters = {...?state.value?.query.filters}..remove(key);
    return setFilters({...filters, key: ?value});
  }
}

/// Devis, proformas et factures, du plus récent au plus ancien.
class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => DocumentDetailScreen(id: id)));
    ref.invalidate(documentListProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<DocumentType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in DocumentType.values)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(switch (type) {
                  DocumentType.quote => 'Nouveau devis',
                  DocumentType.proforma => 'Nouvelle proforma',
                  DocumentType.invoice => 'Nouvelle facture',
                }),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) {
      return;
    }
    final created = await Navigator.of(context)
        .push<CommercialDocument>(MaterialPageRoute(builder: (context) => DocumentFormScreen(type: type)));
    ref.invalidate(documentListProvider);
    if (created != null && context.mounted) {
      await _open(context, ref, created.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentListProvider);
    final notifier = ref.read(documentListProvider.notifier);
    final filters = state.value?.query.filters ?? const {};
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget chip(String key, Object value, String label) => ChoiceChip(
      label: Text(label),
      selected: filters[key] == value,
      showCheckmark: false,
      onSelected: (_) => notifier.setFilter(key, filters[key] == value ? null : value),
    );

    return ResourceListScaffold<CommercialDocument>(
      title: 'Devis et factures',
      searchHint: 'Numéro, client, projet…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(documentListProvider),
      onCreate: () => _create(context, ref),
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'Aucun document pour l\'instant',
      emptyDescription: 'Crée un devis avec le bouton +, ou depuis une demande gagnée.',
      filterChips: [
        chip('reminder', true, 'À relancer'),
        for (final type in DocumentType.values) chip('type', type.wireValue, type.label),
        for (final status in DocumentStatus.values) chip('status', status.wireValue, status.label),
      ],
      itemBuilder: (context, document) => GestureDetector(
        // Appui long : émettre, marquer accepté, payé… sans ouvrir la fiche.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'commercial_document',
          id: document.id,
          title: document.client,
          current: document.status.wireValue,
          options: [for (final s in DocumentStatus.values) (value: s.wireValue, label: s.label)],
          onChanged: () => ref.invalidate(documentListProvider),
        ),
        child: ListCardTile(
          onTap: () => _open(context, ref, document.id),
          leading: IconTile(switch (document.type) {
            DocumentType.quote => Icons.request_quote_outlined,
            DocumentType.proforma => Icons.description_outlined,
            DocumentType.invoice => Icons.receipt_long_outlined,
          }),
          title: document.client,
          subtitle: [document.number ?? document.type.label, document.title].join(' · '),
          meta: formatMoney(document.total, document.currency),
          badge: DocumentStatusBadge(document),
        ),
      ),
      header: Text(
        'Une relance n\'est jamais envoyée seule : « À relancer » liste celles suggérées.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      ),
    );
  }
}
