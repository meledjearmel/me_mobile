import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/engagement_list_controller.dart';
import '../../data/engagement.dart';
import 'engagement_detail_screen.dart';

class EngagementsTab extends ConsumerStatefulWidget {
  const EngagementsTab({super.key, this.autoOpenId});

  final int? autoOpenId;

  @override
  ConsumerState<EngagementsTab> createState() => _EngagementsTabState();
}

class _EngagementsTabState extends ConsumerState<EngagementsTab> {
  static const _statuses = [null, 'new', 'handled'];
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
      ref.read(engagementListProvider.notifier).loadMore();
    }
  }

  void _openDetail(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => EngagementDetailScreen(id: id)));
  }

  String _statusLabel(String? status) => switch (status) {
        null => 'Toutes',
        'new' => EngagementStatus.newRequest.label,
        _ => EngagementStatus.handled.label,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(engagementListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => ref.read(engagementListProvider.notifier).setSearch(value),
            decoration: InputDecoration(
              hintText: 'Nom, e-mail, société, sujet…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(engagementListProvider.notifier).setSearch('');
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
                onTap: () => ref.read(engagementListProvider.notifier).setFilters({'status': status}),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Impossible de charger les demandes.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => ref.invalidate(engagementListProvider), child: const Text('Réessayer')),
                ],
              ),
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return const Center(
                  child: ComingSoon(
                    icon: Icons.handshake_outlined,
                    title: 'Aucune demande pour l\'instant',
                    description: 'Les demandes de collaboration (freelance ou embauche) apparaîtront ici.',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(engagementListProvider.notifier).refresh(),
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
                    final engagement = data.items[index];
                    return _EngagementTile(engagement: engagement, onTap: () => _openDetail(engagement.id));
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

class _EngagementTile extends StatelessWidget {
  const _EngagementTile({required this.engagement, required this.onTap});

  final Engagement engagement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = engagement.status == EngagementStatus.newRequest;

    return ListTile(
      onTap: onTap,
      leading: Icon(engagement.type == EngagementType.hiring ? Icons.badge_outlined : Icons.work_outline_rounded),
      title: Text(
        engagement.name,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: isNew ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(
        [
          if (engagement.company?.isNotEmpty == true) engagement.company,
          engagement.subject,
        ].whereType<String>().join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (engagement.createdAt != null)
            Text(relativeDate(engagement.createdAt!), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          StatusBadge(engagement.status.label, color: isNew ? theme.colorScheme.primary : null, prominent: isNew),
        ],
      ),
    );
  }
}
