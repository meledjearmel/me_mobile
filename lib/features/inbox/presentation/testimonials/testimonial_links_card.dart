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

/// Projet, expérience et formation auxquels l'avis est rattaché, chacun facultatif.
class TestimonialLinksCard extends ConsumerWidget {
  const TestimonialLinksCard({
    super.key,
    this.testimonial,
    required this.projectId,
    required this.experienceId,
    required this.educationId,
    required this.onProjectChanged,
    required this.onExperienceChanged,
    required this.onEducationChanged,
  });

  /// Liens d'origine : toujours proposés, même hors de la première page.
  /// `null` pour une demande d'avis (aucun lien existant).
  final Testimonial? testimonial;
  final int? projectId;
  final int? experienceId;
  final int? educationId;
  final ValueChanged<int?> onProjectChanged;
  final ValueChanged<int?> onExperienceChanged;
  final ValueChanged<int?> onEducationChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final project = testimonial?.project;
    final experience = testimonial?.experience;
    final education = testimonial?.education;

    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rattaché à', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'L\'avis s\'affiche aussi sur ces pages du site.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _LinkDropdown(
            label: 'Projet',
            options: ref.watch(_projectOptionsProvider),
            current: project == null ? null : (id: project.id, label: project.title.display),
            value: projectId,
            onChanged: onProjectChanged,
          ),
          const SizedBox(height: 12),
          _LinkDropdown(
            label: 'Expérience',
            options: ref.watch(_experienceOptionsProvider),
            current: experience == null
                ? null
                : (id: experience.id, label: '${experience.role.display} · ${experience.company}'),
            value: experienceId,
            onChanged: onExperienceChanged,
          ),
          const SizedBox(height: 12),
          _LinkDropdown(
            label: 'Formation',
            options: ref.watch(_educationOptionsProvider),
            current: education == null
                ? null
                : (id: education.id, label: '${education.degree.display} · ${education.institution}'),
            value: educationId,
            onChanged: onEducationChanged,
          ),
        ],
      ),
    );
  }
}

class _LinkDropdown extends StatelessWidget {
  const _LinkDropdown({
    required this.label,
    required this.options,
    required this.current,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<_Option>> options;
  final _Option? current;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final loaded = options.asData?.value ?? const <_Option>[];
    final current = this.current;
    final items = [if (current != null && !loaded.any((o) => o.id == current.id)) current, ...loaded];

    return DropdownButtonFormField<int?>(
      // Reconstruit une fois la liste chargée : `initialValue` n'est lu qu'au départ.
      key: ValueKey('$label-${options.hasValue}'),
      initialValue: items.any((o) => o.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: options.hasError ? 'Liste indisponible.' : null,
        suffixIcon: options.isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : null,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Aucun')),
        for (final option in items)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
