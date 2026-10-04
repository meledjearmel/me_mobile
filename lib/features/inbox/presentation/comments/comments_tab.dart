import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../application/post_comment_list_controller.dart';
import '../../data/post_comment.dart';
import 'comment_detail_screen.dart';

/// Onglet Commentaires : balayer une carte pour approuver ou rejeter, avec
/// une possibilité d'annuler, comme pour les avis.
class CommentsTab extends ConsumerStatefulWidget {
  const CommentsTab({super.key, this.autoOpenId});

  final int? autoOpenId;

  @override
  ConsumerState<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<CommentsTab> {
  static const _statuses = [null, 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.autoOpenId!));
    }
  }

  void _openDetail(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => CommentDetailScreen(id: id)));
  }

  /// Retire la carte tout de suite, laisse 4 secondes pour annuler avant
  /// d'envoyer la décision au serveur.
  void _moderate(PostComment comment, CommentStatus target) {
    ref.read(postCommentListProvider.notifier).removeItem((c) => c.id == comment.id);

    final messenger = ScaffoldMessenger.of(context);
    var cancelled = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(target == CommentStatus.approved ? 'Commentaire approuvé' : 'Commentaire rejeté'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            cancelled = true;
            ref.invalidate(postCommentListProvider);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    controller.closed.then((_) async {
      if (cancelled || !mounted) {
        return;
      }
      try {
        await ref.read(postCommentRepositoryProvider).moderate(comment.id, target);
        ref.invalidate(dashboardProvider);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          ref.invalidate(postCommentListProvider);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postCommentListProvider);
    final notifier = ref.read(postCommentListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;

    return ResourceListView<PostComment>(
      searchHint: 'Auteur, e-mail, commentaire…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(postCommentListProvider),
      emptyIcon: Icons.forum_outlined,
      emptyTitle: 'Aucun commentaire pour l\'instant',
      emptyDescription: 'Les commentaires laissés sous les articles du blog apparaîtront ici.',
      wrapInCard: false,
      filterChips: [
        for (final status in _statuses)
          PillFilterChip(
            label: status == null ? 'Tous' : CommentStatus.fromWire(status).label,
            selected: current == status,
            onTap: () => notifier.setFilters({'status': status}),
          ),
      ],
      itemBuilder: (context, item) => Dismissible(
        key: ValueKey(item.id),
        // Seul un commentaire en attente se modère d'un geste.
        direction: item.status == CommentStatus.pending ? DismissDirection.horizontal : DismissDirection.none,
        background: const _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: Colors.green,
          icon: Icons.check_rounded,
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: Theme.of(context).colorScheme.error,
          icon: Icons.close_rounded,
        ),
        onDismissed: (direction) =>
            _moderate(item, direction == DismissDirection.startToEnd ? CommentStatus.approved : CommentStatus.rejected),
        child: _CommentCard(comment: item, onTap: () => _openDetail(item.id)),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.alignment, required this.color, required this.icon});

  final Alignment alignment;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
      child: Icon(icon, color: color),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onTap});

  final PostComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsTile(comment.authorName, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(comment.authorName, style: theme.textTheme.titleSmall)),
              StatusBadge(comment.status.label, prominent: comment.status == CommentStatus.pending),
            ],
          ),
          if (comment.postTitle != null) ...[
            const SizedBox(height: 4),
            Text('Sur « ${comment.postTitle} »', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          ],
          const SizedBox(height: 10),
          Text(comment.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          if (comment.createdAt != null) ...[
            const SizedBox(height: 10),
            Text(relativeDate(comment.createdAt!), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
