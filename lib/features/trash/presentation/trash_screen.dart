import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
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
import '../../content/technologies/application/technology_category_list_controller.dart';
import '../../content/technologies/application/technology_list_controller.dart';
import '../../content/technologies/data/technology_category_repository.dart';
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
  int? _restoringId;
  int? _destroyingId;

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
      case 'technology-categories':
        // Restaurer une catégorie ramène aussi ses technologies.
        ref.invalidate(technologyCategoryListProvider);
        ref.invalidate(technologyCategoriesAllProvider);
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
        content: const Text('Cette action est irréversible : cet élément ne pourra plus jamais être restauré.'),
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
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      body: ResourceListView<TrashItem>(
        title: 'Corbeille',
        searchHint: 'Titre…',
        state: state,
        onSearch: notifier.setSearch,
        onLoadMore: notifier.loadMore,
        onRefresh: notifier.refresh,
        onRetry: () => ref.invalidate(trashListProvider),
        emptyIcon: Icons.delete_outline_rounded,
        emptyTitle: 'La corbeille est vide',
        emptyDescription: 'Les éléments supprimés arrivent ici : vous pourrez les restaurer ou les purger.',
        filterChips: [
          for (final (type, label) in trashTypes)
            ChoiceChip(
              label: Text(label),
              selected: currentType == type,
              onSelected: (_) => notifier.setFilters(currentType == type ? const {} : {'type': type}),
            ),
        ],
        itemBuilder: (context, item) {
          final isRestoring = _restoringId == item.id;
          final isDestroying = _destroyingId == item.id;
          return ListTile(
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              item.deletedAt == null ? item.label : '${item.label} · supprimé ${relativeDate(item.deletedAt!)}',
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
  }
}
