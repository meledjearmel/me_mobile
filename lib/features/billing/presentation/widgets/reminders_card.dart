import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../data/commercial_document.dart';
import '../document_detail_screen.dart';
import '../documents_list_screen.dart';

/// Documents dont une relance est suggérée (devis sans réponse, facture en retard).
final documentRemindersProvider = FutureProvider.autoDispose<Paginated<CommercialDocument>>(
  (ref) => ref.watch(commercialDocumentRepositoryProvider).list(page: 1, reminder: true),
);

/// Carte « À relancer » de l'accueil : rien ne s'affiche tant qu'aucune relance
/// n'est suggérée, ni si la liste ne se charge pas (l'accueil reste lisible).
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  static const _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(documentRemindersProvider).value;
    if (page == null || page.total == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Future<void> openAll() async {
      await ref.read(documentListProvider.notifier).setFilters({'reminder': true});
      if (context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const DocumentsListScreen()));
      }
      ref.invalidate(documentRemindersProvider);
    }

    Future<void> open(int id) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => DocumentDetailScreen(id: id)));
      ref.invalidate(documentRemindersProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SurfaceCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        onTap: openAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(Icons.notifications_active_outlined, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text('À relancer', style: theme.textTheme.titleSmall)),
                Text(
                  '${page.total}',
                  style: theme.textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
            for (final document in page.items.take(_shown)) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => open(document.id),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(document.client, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            [
                              document.number ?? document.type.label,
                              document.isQuote ? 'sans réponse' : 'paiement en retard',
                            ].join(' · '),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatMoney(document.total, document.currency), style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ],
            if (page.total > _shown) ...[
              const SizedBox(height: 8),
              Text('Et ${page.total - _shown} de plus', style: muted),
            ],
          ],
        ),
      ),
    );
  }
}
