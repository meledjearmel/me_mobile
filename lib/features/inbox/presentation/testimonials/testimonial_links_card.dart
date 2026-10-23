import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/surfaces.dart';
import '../../../content/educations/data/education_repository.dart';
import '../../../content/experiences/data/experience_repository.dart';
import '../../../projects/data/project_repository.dart';
import '../../data/testimonial.dart';

typedef _Option = ({int id, String label});

// Première page (25) de chaque liste : de quoi couvrir un portfolio.
final _projectOptionsProvider = FutureProvider.autoDispose<List<_Option>>((ref) async {
  final page = await ref.watch(projectRepositoryProvider).list(page: 1);
  return [for (final p in page.items) (id: p.id, label: p.title.display)];
});

final _experienceOptionsProvider = FutureProvider.autoDispose<List<_Option>>((ref) async {
  final page = await ref.watch(experienceRepositoryProvider).list(page: 1);
  return [for (final e in page.items) (id: e.id, label: '${e.role.display} · ${e.company}')];
});

final _educationOptionsProvider = FutureProvider.autoDispose<List<_Option>>((ref) async {
  final page = await ref.watch(educationRepositoryProvider).list(page: 1);
  return [for (final e in page.items) (id: e.id, label: '${e.degree.display} · ${e.institution}')];
});

/// Projets, expériences et formations auxquels l'avis est rattaché :
/// plusieurs par type, aucun pour un avis général.
class TestimonialLinksCard extends ConsumerWidget {
  const TestimonialLinksCard({
    super.key,
    this.testimonial,
    required this.projectIds,
    required this.experienceIds,
    required this.educationIds,
    required this.onProjectsChanged,
    required this.onExperiencesChanged,
    required this.onEducationsChanged,
  });

  /// Liens d'origine : toujours proposés, même hors de la première page.
  /// `null` pour une demande d'avis (aucun lien existant).
  final Testimonial? testimonial;
  final Set<int> projectIds;
  final Set<int> experienceIds;
  final Set<int> educationIds;
  final ValueChanged<Set<int>> onProjectsChanged;
  final ValueChanged<Set<int>> onExperiencesChanged;
  final ValueChanged<Set<int>> onEducationsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final testimonial = this.testimonial;

    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rattaché à', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'L\'avis s\'affiche aussi sur ces pages du site. Aucun : avis général.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _LinkChips(
            label: 'Projets',
            options: ref.watch(_projectOptionsProvider),
            current: [for (final p in testimonial?.projects ?? const <ProjectRef>[]) (id: p.id, label: p.label)],
            selected: projectIds,
            onChanged: onProjectsChanged,
          ),
          const SizedBox(height: 12),
          _LinkChips(
            label: 'Expériences',
            options: ref.watch(_experienceOptionsProvider),
            current: [
              for (final e in testimonial?.experiences ?? const <ExperienceRef>[]) (id: e.id, label: e.label),
            ],
            selected: experienceIds,
            onChanged: onExperiencesChanged,
          ),
          const SizedBox(height: 12),
          _LinkChips(
            label: 'Formations',
            options: ref.watch(_educationOptionsProvider),
            current: [
              for (final e in testimonial?.educations ?? const <EducationRef>[]) (id: e.id, label: e.label),
            ],
            selected: educationIds,
            onChanged: onEducationsChanged,
          ),
        ],
      ),
    );
  }
}

class _LinkChips extends StatelessWidget {
  const _LinkChips({
    required this.label,
    required this.options,
    required this.current,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<_Option>> options;
  final List<_Option> current;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = options.asData?.value ?? const <_Option>[];
    final items = [...current.where((c) => !loaded.any((o) => o.id == c.id)), ...loaded];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (options.isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (options.hasError && items.isEmpty)
          Text('Liste indisponible.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))
        else if (items.isEmpty && !options.isLoading)
          Text('Aucun élément.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in items)
                FilterChip(
                  label: Text(option.label, overflow: TextOverflow.ellipsis),
                  selected: selected.contains(option.id),
                  onSelected: (on) => onChanged(on ? {...selected, option.id} : ({...selected}..remove(option.id))),
                ),
            ],
          ),
      ],
    );
  }
}

typedef SubjectLabel = ({IconData icon, String label});

const subjectIcons = {
  'project': Icons.work_outline_rounded,
  'experience': Icons.business_center_outlined,
  'education': Icons.school_outlined,
};

/// Pastilles d'un avis : projets, expériences, formations.
List<SubjectLabel> testimonialSubjectLabels(Testimonial t) => [
  for (final p in t.projects) (icon: subjectIcons['project']!, label: p.label),
  for (final e in t.experiences) (icon: subjectIcons['experience']!, label: e.label),
  for (final e in t.educations) (icon: subjectIcons['education']!, label: e.label),
];

/// Rattachements en pastilles, en lecture seule ; « Général » s'il n'y en a aucun.
class SubjectChips extends StatelessWidget {
  const SubjectChips({super.key, required this.labels, this.emptyLabel = 'Général'});

  final List<SubjectLabel> labels;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = emptyLabel;
    final items = labels.isEmpty && empty != null ? [(icon: Icons.public_rounded, label: empty)] : labels;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(item.label, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
