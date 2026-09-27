import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/status_badge.dart';
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
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.autoOpenId!));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(contactListProvider.notifier).loadMore();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => ref.read(contactListProvider.notifier).setSearch(value),
            decoration: InputDecoration(
              hintText: 'Nom, e-mail, sujet…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(contactListProvider.notifier).setSearch('');
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _statuses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final status = _statuses[index];
              final current = state.value?.query.filters['status'] as String?;
              return PillFilterChip(
                label: _statusLabel(status),
                selected: current == status,
                onTap: () => ref.read(contactListProvider.notifier).setFilters({'status': status}),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(onRetry: () => ref.invalidate(contactListProvider)),
            data: (data) {
              if (data.items.isEmpty) {
                return const _EmptyState();
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(contactListProvider.notifier).refresh(),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    if (index >= data.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final contact = data.items[index];
                    return _ContactTile(contact: contact, onTap: () => _openDetail(contact.id));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = contact.status == ContactStatus.newMessage;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Text(contact.name.isEmpty ? '?' : contact.name[0].toUpperCase()),
      ),
      title: Text(
        contact.name,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: isNew ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(
        contact.subject?.isNotEmpty == true ? contact.subject! : contact.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (contact.createdAt != null)
            Text(relativeDate(contact.createdAt!), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          StatusBadge(
            contact.status.label,
            color: isNew ? theme.colorScheme.primary : null,
            prominent: isNew,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ComingSoon(
        icon: Icons.mail_outline_rounded,
        title: 'Aucun message pour l\'instant',
        description: 'Les messages du formulaire de contact du site apparaîtront ici.',
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Impossible de charger les messages.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
