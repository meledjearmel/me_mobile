import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/surfaces.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.autoOpenId!));
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
    final notifier = ref.read(engagementListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;

    return ResourceListView<Engagement>(
      searchHint: 'Nom, e-mail, société, sujet…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(engagementListProvider),
      emptyIcon: Icons.handshake_outlined,
      emptyTitle: 'Aucune demande pour l\'instant',
      emptyDescription: 'Les demandes de collaboration (freelance ou embauche) apparaîtront ici.',
      wrapInCard: false,
      filterChips: [
        for (final status in _statuses)
          PillFilterChip(
            label: _statusLabel(status),
            selected: current == status,
            onTap: () => notifier.setFilters({'status': status}),
          ),
      ],
      itemBuilder: (context, item) => _EngagementTile(engagement: item, onTap: () => _openDetail(item.id)),
    );
  }
}

class _EngagementTile extends StatelessWidget {
  const _EngagementTile({required this.engagement, required this.onTap});

  final Engagement engagement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = engagement.status == EngagementStatus.newRequest;

    return ListCardTile(
      onTap: onTap,
      leading: IconTile(engagement.type == EngagementType.hiring ? Icons.badge_outlined : Icons.work_outline_rounded),
      title: engagement.name,
      unread: isNew,
      meta: engagement.createdAt == null ? null : relativeDate(engagement.createdAt!),
      subtitle: [
        if (engagement.company?.isNotEmpty == true) engagement.company,
        engagement.subject,
      ].whereType<String>().join(' · '),
      badge: isNew ? null : StatusBadge(engagement.status.label),
    );
  }
}
