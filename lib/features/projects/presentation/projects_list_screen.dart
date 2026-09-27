import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/project_list_controller.dart';
import '../data/project.dart';
import 'project_form_screen.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProjectFormScreen(id: id)));
    ref.invalidate(projectListProvider);
  }

  void _toggleFilter(WidgetRef ref, String key, Object value) {
    final current = Map<String, Object?>.from(ref.read(projectListProvider).value?.query.filters ?? const {});
    if (current[key] == value) {
      current.remove(key);
    } else {
      current[key] = value;
    }
    ref.read(projectListProvider.notifier).setFilters(current);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectListProvider);
    final notifier = ref.read(projectListProvider.notifier);
    final theme = Theme.of(context);
    final filters = state.value?.query.filters ?? const {};

    return ResourceListScaffold<Project>(
      title: 'Projets',
      searchHint: 'Titre, slug…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(projectListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.work_outline_rounded,
      emptyTitle: 'Aucun projet pour l\'instant',
      emptyDescription: 'Créez votre premier projet avec le bouton +.',
      filterChips: [
        ChoiceChip(
          label: const Text('Publié'),
          selected: filters['status'] == 'published',
          onSelected: (_) => _toggleFilter(ref, 'status', 'published'),
          showCheckmark: false,
        ),
        ChoiceChip(
          label: const Text('Archivé'),
          selected: filters['status'] == 'archived',
          onSelected: (_) => _toggleFilter(ref, 'status', 'archived'),
          showCheckmark: false,
        ),
        ChoiceChip(
          label: const Text('À la une'),
          selected: filters['is_featured'] == true,
          onSelected: (_) => _toggleFilter(ref, 'is_featured', true),
          showCheckmark: false,
        ),
        ChoiceChip(
          label: const Text('Open source'),
          selected: filters['is_open_source'] == true,
          onSelected: (_) => _toggleFilter(ref, 'is_open_source', true),
          showCheckmark: false,
        ),
      ],
      itemBuilder: (context, project) => ListTile(
        onTap: () => _openForm(context, ref, id: project.id),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          backgroundImage: project.coverUrl != null ? NetworkImage(project.coverUrl!) : null,
          child: project.coverUrl == null
              ? Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
        title: Text(project.title.display, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(project.slug, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusBadge(project.status.label, prominent: project.status == ProjectStatus.published),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (project.isFeatured)
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber, semanticLabel: 'À la une'),
                if (project.isOpenSource)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.code_rounded, size: 16, semanticLabel: 'Open source'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
