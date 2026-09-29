import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../application/contact_list_controller.dart';
import '../../data/contact.dart';
import 'contact_detail_screen.dart';

/// Onglet Messages de la boîte de réception (§4.2).
class ContactsTab extends ConsumerStatefulWidget {
  const ContactsTab({super.key, this.autoOpenId});

  /// Id à ouvrir directement (tap sur une notification), le temps d'un premier build.
  final int? autoOpenId;

  @override
  ConsumerState<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends ConsumerState<ContactsTab> {
  static const _statuses = [null, 'new', 'read', 'replied'];

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.autoOpenId!));
    }
  }

  void _openDetail(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ContactDetailScreen(id: id)));
  }

  String _statusLabel(String? status) => switch (status) {
    null => 'Tous',
    'new' => ContactStatus.newMessage.label,
    'read' => ContactStatus.read.label,
    _ => ContactStatus.replied.label,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactListProvider);
    final notifier = ref.read(contactListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;

    return ResourceListView<Contact>(
      searchHint: 'Nom, e-mail, sujet…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(contactListProvider),
      emptyIcon: Icons.mail_outline_rounded,
      emptyTitle: 'Aucun message pour l\'instant',
      emptyDescription: 'Les messages du formulaire de contact du site apparaîtront ici.',
      wrapInCard: false,
      filterChips: [
        for (final status in _statuses)
          PillFilterChip(
            label: _statusLabel(status),
            selected: current == status,
            onTap: () => notifier.setFilters({'status': status}),
          ),
      ],
      itemBuilder: (context, item) => _ContactTile(contact: item, onTap: () => _openDetail(item.id)),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = contact.status == ContactStatus.newMessage;

    return ListCardTile(
      onTap: onTap,
      leading: InitialsTile(contact.name),
      title: contact.name,
      unread: isNew,
      meta: contact.createdAt == null ? null : relativeDate(contact.createdAt!),
      subtitle: contact.subject?.isNotEmpty == true ? contact.subject! : contact.message,
      badge: contact.status == ContactStatus.replied ? StatusBadge(contact.status.label) : null,
    );
  }
}
