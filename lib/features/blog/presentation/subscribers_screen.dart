import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/blog_admin_controllers.dart';
import '../data/blog_admin.dart';

/// Abonnés à la newsletter du blog, avec les compteurs par statut.
class SubscribersScreen extends ConsumerWidget {
  const SubscribersScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Subscriber subscriber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ${subscriber.email} ?'),
        content: const Text('Suppression définitive : l\'adresse pourra se réinscrire depuis le blog.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(blogAdminRepositoryProvider).deleteSubscriber(subscriber.id);
      ref.read(subscriberListProvider.notifier).removeItem((s) => s.id == subscriber.id);
      ref.invalidate(subscriberSummaryProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriberListProvider);
    final notifier = ref.read(subscriberListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;
    final summary = ref.watch(subscriberSummaryProvider).asData?.value;

    String chipLabel(SubscriberStatus status) {
      final count = switch (status) {
        SubscriberStatus.active => summary?.active,
        SubscriberStatus.pending => summary?.pending,
        SubscriberStatus.unsubscribed => summary?.unsubscribed,
      };
      return count == null ? status.label : '${status.label} ($count)';
    }

    return ResourceListScaffold<Subscriber>(
      title: 'Abonnés',
      searchHint: 'E-mail…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: () async {
        ref.invalidate(subscriberSummaryProvider);
        await notifier.refresh();
      },
      onRetry: () => ref.invalidate(subscriberListProvider),
      emptyIcon: Icons.mark_email_read_outlined,
      emptyTitle: 'Aucun abonné pour l\'instant',
      emptyDescription: 'Les inscriptions à la newsletter du blog apparaîtront ici.',
      filterChips: [
        for (final status in SubscriberStatus.values)
          ChoiceChip(
            label: Text(chipLabel(status)),
            selected: current == status.wireValue,
            onSelected: (_) =>
                notifier.setFilters(current == status.wireValue ? const {} : {'status': status.wireValue}),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, subscriber) => ListTile(
        leading: CircleAvatar(child: Text(subscriber.locale.toUpperCase(), style: const TextStyle(fontSize: 12))),
        title: Text(subscriber.email, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subscriber.createdAt == null ? null : Text('Inscrit ${relativeDate(subscriber.createdAt!)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(subscriber.status.label, prominent: subscriber.status == SubscriberStatus.pending),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context, ref, subscriber),
            ),
          ],
        ),
      ),
    );
  }
}
