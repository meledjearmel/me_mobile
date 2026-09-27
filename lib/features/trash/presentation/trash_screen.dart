import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../content/data/reference_repository.dart';
import '../../content/domains/application/domain_list_controller.dart';
import '../../content/educations/application/education_list_controller.dart';
import '../../content/experiences/application/experience_list_controller.dart';
import '../../content/job_profiles/application/job_profile_list_controller.dart';
import '../../content/music/application/music_genre_list_controller.dart';
import '../../content/music/application/track_list_controller.dart';
import '../../content/music/data/music_genre_repository.dart';
import '../../content/professional_references/application/professional_reference_list_controller.dart';
import '../../content/skills/application/skill_list_controller.dart';
import '../../content/technologies/application/technology_list_controller.dart';
import '../../inbox/application/contact_list_controller.dart';
import '../../inbox/application/engagement_list_controller.dart';
import '../../inbox/application/testimonial_list_controller.dart';
import '../../projects/application/project_list_controller.dart';
import '../application/trash_list_controller.dart';
import '../data/trash_item.dart';
import '../data/trash_repository.dart';

/// Corbeille (§4.5) : liste fusionnée de toutes les ressources supprimées,
/// triée par date de suppression décroissante. Filet de sécurité, pas un
/// écran du quotidien.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  int? _restoringId;
  int? _destroyingId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(trashListProvider.notifier).loadMore();
    }
  }

  /// Le contenu revient visible dans sa liste normale : on invalide le
  /// provider correspondant pour qu'elle se rafraîchisse à la prochaine visite.
  void _invalidateRelatedList(String type) {
    switch (type) {
      case 'domains':
        ref.invalidate(domainListProvider);
        ref.invalidate(domainsRefProvider);
      case 'music-genres':
        ref.invalidate(musicGenreListProvider);
        ref.invalidate(musicGenresAllProvider);
      case 'tracks':
        ref.invalidate(trackListProvider);
      case 'technologies':
        ref.invalidate(technologyListProvider);
        ref.invalidate(technologiesRefProvider);
      case 'job-profiles':
        ref.invalidate(jobProfileListProvider);
        ref.invalidate(jobProfilesRefProvider);
      case 'skills':
        ref.invalidate(skillListProvider);
      case 'educations':
        ref.invalidate(educationListProvider);
      case 'experiences':
        ref.invalidate(experienceListProvider);
      case 'projects':
        ref.invalidate(projectListProvider);
        ref.invalidate(projectsLiteRefProvider);
      case 'professional-references':
        ref.invalidate(professionalReferenceListProvider);
      case 'testimonials':
        ref.invalidate(testimonialListProvider);
      case 'contacts':
        ref.invalidate(contactListProvider);
      case 'engagements':
        ref.invalidate(engagementListProvider);
    }
  }

  Future<void> _restore(TrashItem item) async {
    setState(() => _restoringId = item.id);
    try {
      await ref.read(trashRepositoryProvider).restore(item.type, item.id);
      ref.read(trashListProvider.notifier).removeItem((i) => i.id == item.id && i.type == item.type);
      _invalidateRelatedList(item.type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« ${item.title} » restauré.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _restoringId = null);
      }
    }
  }

  Future<void> _destroy(TrashItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer définitivement « ${item.title} » ?'),
        content: const Text(
          'Cette action est irréversible : cet élément ne pourra plus jamais être restauré.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _destroyingId = item.id);
    try {
      await ref.read(trashRepositoryProvider).destroy(item.type, item.id);
      ref.read(trashListProvider.notifier).removeItem((i) => i.id == item.id && i.type == item.type);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _destroyingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trashListProvider);
    final notifier = ref.read(trashListProvider.notifier);
    final currentType = state.value?.query.filters['type'] as String?;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Corbeille')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: notifier.setSearch,
              decoration: InputDecoration(
                hintText: 'Titre…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearch('');
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
              itemCount: trashTypes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (type, label) = trashTypes[index];
                return ChoiceChip(
                  label: Text(label),
                  selected: currentType == type,
                  onSelected: (_) => notifier.setFilters(currentType == type ? const {} : {'type': type}),
                  showCheckmark: false,
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
                    const Text('Impossible de charger la corbeille.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => ref.invalidate(trashListProvider), child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('La corbeille est vide.'),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: notifier.refresh,
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
                      final item = data.items[index];
                      final isRestoring = _restoringId == item.id;
                      final isDestroying = _destroyingId == item.id;
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          item.deletedAt == null
                              ? item.label
                              : '${item.label} · supprimé ${relativeDate(item.deletedAt!)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restaurer',
                              onPressed: isRestoring || isDestroying ? null : () => _restore(item),
                              icon: isRestoring
                                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.restore_rounded),
                            ),
                            IconButton(
                              tooltip: 'Supprimer définitivement',
                              onPressed: isRestoring || isDestroying ? null : () => _destroy(item),
                              icon: isDestroying
                                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
