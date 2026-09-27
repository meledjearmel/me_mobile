import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/list_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/testimonial_list_controller.dart';
import '../../data/testimonial.dart';
import '../../data/testimonial_repository.dart';
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
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEdit(widget.autoOpenId!));
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
      ref.read(testimonialListProvider.notifier).loadMore();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => ref.read(testimonialListProvider.notifier).setSearch(value),
            decoration: InputDecoration(
              hintText: 'Auteur, e-mail, rôle, contenu…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(testimonialListProvider.notifier).setSearch('');
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
                onTap: () => ref.read(testimonialListProvider.notifier).setFilters({'status': status}),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: state.when(
            loading: () => const ListSkeleton(),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Impossible de charger les avis.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => ref.invalidate(testimonialListProvider), child: const Text('Réessayer')),
                ],
              ),
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return const Center(
                  child: ComingSoon(
                    icon: Icons.reviews_outlined,
                    title: 'Aucun avis pour l\'instant',
                    description: 'Les avis déposés sur le site public apparaîtront ici.',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(testimonialListProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= data.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final testimonial = data.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(testimonial.id),
                        background: _SwipeBackground(
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
                          testimonial,
                          direction == DismissDirection.startToEnd
                              ? TestimonialStatus.approved
                              : TestimonialStatus.rejected,
                        ),
                        child: _TestimonialCard(
                          testimonial: testimonial,
                          onTap: () => _openEdit(testimonial.id),
                        ),
                      ),
                    );
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(testimonial.authorName, style: theme.textTheme.titleSmall),
                  ),
                  if (testimonial.isFeatured)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                    ),
                  StatusBadge(
                    testimonial.status.label,
                    prominent: testimonial.status == TestimonialStatus.pending,
                  ),
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
        ),
      ),
    );
  }
}
