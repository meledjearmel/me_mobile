import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../application/testimonial_list_controller.dart';
import '../../data/testimonial.dart';
import '../../data/testimonial_repository.dart';
import 'review_invitations_screen.dart';
import 'testimonial_edit_screen.dart';

/// Onglet Avis : balayer une carte pour approuver ou rejeter, avec une
/// possibilité d'annuler ; « Modifier » (au tap) pour corriger le texte (§4.2).
class TestimonialsTab extends ConsumerStatefulWidget {
  const TestimonialsTab({super.key, this.autoOpenId});

  final int? autoOpenId;

  @override
  ConsumerState<TestimonialsTab> createState() => _TestimonialsTabState();
}

class _TestimonialsTabState extends ConsumerState<TestimonialsTab> {
  static const _statuses = [null, 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEdit(widget.autoOpenId!));
    }
  }

  void _openEdit(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => TestimonialEditScreen(id: id)));
  }

  /// Modération rapide en un geste : retire la carte tout de suite, laisse
  /// 4 secondes pour annuler avant d'envoyer réellement la décision au serveur.
  void _moderate(Testimonial testimonial, TestimonialStatus target) {
    ref.read(testimonialListProvider.notifier).removeItem((t) => t.id == testimonial.id);

    final messenger = ScaffoldMessenger.of(context);
    var cancelled = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(target == TestimonialStatus.approved ? 'Avis approuvé' : 'Avis rejeté'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            cancelled = true;
            ref.invalidate(testimonialListProvider);
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
        await ref.read(testimonialRepositoryProvider).updateStatus(testimonial.id, target);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          ref.invalidate(testimonialListProvider);
        }
      }
    });
  }

  String _statusLabel(String? status) => switch (status) {
    null => 'Tous',
    'pending' => TestimonialStatus.pending.label,
    'approved' => TestimonialStatus.approved.label,
    _ => TestimonialStatus.rejected.label,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testimonialListProvider);
    final notifier = ref.read(testimonialListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;

    return ResourceListView<Testimonial>(
      searchHint: 'Auteur, e-mail, rôle, contenu…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(testimonialListProvider),
      emptyIcon: Icons.reviews_outlined,
      emptyTitle: 'Aucun avis pour l\'instant',
      emptyDescription: 'Les avis déposés sur le site public apparaîtront ici.',
      wrapInCard: false,
      header: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReviewInvitationsScreen())),
          icon: const Icon(Icons.forward_to_inbox_outlined),
          label: const Text('Demandes d\'avis'),
        ),
      ),
      filterChips: [
        for (final status in _statuses)
          PillFilterChip(
            label: _statusLabel(status),
            selected: current == status,
            onTap: () => notifier.setFilters({'status': status}),
          ),
      ],
      itemBuilder: (context, item) => Dismissible(
        key: ValueKey(item.id),
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
        onDismissed: (direction) => _moderate(
          item,
          direction == DismissDirection.startToEnd ? TestimonialStatus.approved : TestimonialStatus.rejected,
        ),
        child: _TestimonialCard(testimonial: item, onTap: () => _openEdit(item.id)),
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

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial, required this.onTap});

  final Testimonial testimonial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsTile(testimonial.authorName, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(testimonial.authorName, style: theme.textTheme.titleSmall)),
              if (testimonial.video != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.videocam_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                    semanticLabel: 'Avis vidéo',
                  ),
                ),
              if (testimonial.isFeatured)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.star_rounded, size: 18, color: context.appColors.accent),
                ),
              StatusBadge(testimonial.status.label, prominent: testimonial.status == TestimonialStatus.pending),
            ],
          ),
          if (testimonial.authorRole?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              testimonial.authorRole!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          if (!testimonial.highlight.isEmpty) ...[
            Text(
              '« ${testimonial.highlight.display} »',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            testimonial.content.display,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          if (testimonial.submittedAt != null)
            Text(relativeDate(testimonial.submittedAt!), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
