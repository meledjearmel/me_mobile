import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/pagination/paginated_list_controller.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../blog/application/post_list_controller.dart';
import '../../../blog/presentation/posts_list_screen.dart';
import '../../../content/certifications/application/certification_list_controller.dart';
import '../../../content/certifications/presentation/certifications_list_screen.dart';
import '../../../content/distinctions/application/distinction_list_controller.dart';
import '../../../content/distinctions/presentation/distinctions_list_screen.dart';
import '../../../content/educations/application/education_list_controller.dart';
import '../../../content/educations/presentation/educations_list_screen.dart';
import '../../../content/experiences/application/experience_list_controller.dart';
import '../../../content/experiences/presentation/experiences_list_screen.dart';
import '../../../content/skills/application/skill_list_controller.dart';
import '../../../content/skills/presentation/skills_list_screen.dart';
import '../../../content/uses/application/uses_item_list_controller.dart';
import '../../../content/uses/presentation/uses_items_list_screen.dart';
import '../../../projects/application/project_list_controller.dart';
import '../../../projects/presentation/projects_list_screen.dart';
import '../../../revisions/presentation/revisions_screen.dart';
import '../../data/dashboard.dart';

/// Cartes « Brouillons à relire » et « Révisions à relire » de l'accueil.
class ReviewCards extends ConsumerWidget {
  const ReviewCards({super.key, required this.todo});

  final DashboardTodo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ReviewCard(
              icon: Icons.edit_note_rounded,
              count: todo.drafts,
              label: 'Brouillons à relire',
              onTap: () => showDraftsSheet(context, ref, todo),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ReviewCard(
              icon: Icons.rate_review_outlined,
              count: todo.revisions,
              label: 'Révisions à relire',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RevisionsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.icon, required this.count, required this.label, required this.onTap});

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon, size: 38),
              const Spacer(),
              Text(
                '$count',
                style: theme.textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(label, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Ouvre une liste filtrée sur les brouillons. Le filtre est posé une fois le
/// premier chargement terminé, pour qu'il ne soit pas écrasé par celui-ci.
void _openDrafts<T>(
  BuildContext context,
  WidgetRef ref,
  AsyncNotifierProvider<PaginatedListController<T>, ListState<T>> provider,
  Widget screen,
) {
  final navigator = Navigator.of(context)..pop();
  navigator.push(MaterialPageRoute(builder: (context) => screen));
  ref
      .read(provider.future)
      .then<void>((_) {}, onError: (_) {})
      .whenComplete(() => ref.read(provider.notifier).setFilters(const {'status': 'draft'}));
}

/// Feuille « Brouillons à relire » : projets, articles, puis les autres
/// contenus (le tableau de bord n'en donne que le total).
void showDraftsSheet(BuildContext context, WidgetRef ref, DashboardTodo todo) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
      Widget row(String label, int? count, VoidCallback onTap) => ListTile(
        title: Text(label),
        trailing: count == null ? const Icon(Icons.chevron_right_rounded) : Text('$count'),
        onTap: onTap,
      );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('Brouillons à relire', style: theme.textTheme.titleMedium),
              ),
              row(
                'Projets',
                todo.projectDrafts,
                () => _openDrafts(sheetContext, ref, projectListProvider, const ProjectsListScreen()),
              ),
              row(
                'Articles',
                todo.postDrafts,
                () => _openDrafts(sheetContext, ref, postListProvider, const PostsListScreen()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text('Autres contenus (${todo.contentDrafts})', style: muted),
              ),
              row(
                'Expériences',
                null,
                () => _openDrafts(sheetContext, ref, experienceListProvider, const ExperiencesListScreen()),
              ),
              row(
                'Formations',
                null,
                () => _openDrafts(sheetContext, ref, educationListProvider, const EducationsListScreen()),
              ),
              row(
                'Certifications',
                null,
                () => _openDrafts(sheetContext, ref, certificationListProvider, const CertificationsListScreen()),
              ),
              row(
                'Distinctions',
                null,
                () => _openDrafts(sheetContext, ref, distinctionListProvider, const DistinctionsListScreen()),
              ),
              row(
                'Uses',
                null,
                () => _openDrafts(sheetContext, ref, usesItemListProvider, const UsesItemsListScreen()),
              ),
              row(
                'Compétences',
                null,
                () => _openDrafts(sheetContext, ref, skillListProvider, const SkillsListScreen()),
              ),
            ],
          ),
        ),
      );
    },
  );
}
