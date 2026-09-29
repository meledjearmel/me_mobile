import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/utils/hex_color.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
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
      itemBuilder: (context, project) => _ProjectCard(
        project: project,
        onTap: () => _openForm(context, ref, id: project.id),
      ),
    );
  }
}

/// Carte projet : titre et technologies, visuel de couverture, statut et badges.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final technologies = project.technologies.take(3).map((t) => t.name).join(' · ');
    final accent = project.accentColor == null ? null : parseHexColor(project.accentColor!);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (technologies.isNotEmpty)
                        Text(
                          technologies,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ArrowBadge(),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: project.coverUrl != null
                    ? Image.network(
                        project.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => _CoverPlaceholder(accent: accent),
                      )
                    : _CoverPlaceholder(accent: accent),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatusBadge(
                  project.status.label,
                  color: project.status == ProjectStatus.published ? context.appColors.success : null,
                ),
                if (project.isFeatured) ...[const SizedBox(width: 6), const StatusBadge('À la une')],
                if (project.isOpenSource) ...[const SizedBox(width: 6), const StatusBadge('Open source')],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Couverture absente : fond de la couleur du projet (ou neutre) et icône discrète.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.accent});

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: accent?.withValues(alpha: 0.25) ?? theme.colorScheme.surfaceContainer,
      child: Icon(Icons.image_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
