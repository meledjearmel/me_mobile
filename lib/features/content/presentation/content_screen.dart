import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass.dart';
import '../../blog/presentation/posts_list_screen.dart';
import '../../booking/presentation/appointment_types_list_screen.dart';
import '../../booking/presentation/availability_screen.dart';
import '../../celebrations/presentation/celebrations_list_screen.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../dashboard/data/dashboard.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../projects/presentation/projects_list_screen.dart';
import '../certifications/presentation/certifications_list_screen.dart';
import '../domains/presentation/domains_list_screen.dart';
import '../educations/presentation/educations_list_screen.dart';
import '../experiences/presentation/experiences_list_screen.dart';
import '../job_profiles/presentation/job_profiles_list_screen.dart';
import '../music/presentation/music_screen.dart';
import '../professional_references/presentation/professional_references_list_screen.dart';
import '../skills/presentation/skills_list_screen.dart';
import '../technologies/presentation/technologies_list_screen.dart';
import '../uses/presentation/uses_items_list_screen.dart';

/// Sommaire des sections de contenu (§4.3), groupées comme le menu
/// d'administration du site : Parcours, Réalisations, Référentiels, Rendez-vous,
/// Musique, Site.
/// Les catégories de technologies s'ouvrent depuis l'écran Technologies.
class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key});

  static const _groups = [
    (
      label: 'Parcours',
      sections: [
        (icon: Icons.badge_outlined, label: 'Profil', builder: _profileScreen),
        (icon: Icons.timeline_rounded, label: 'Expériences', builder: _experiencesScreen),
        (icon: Icons.school_outlined, label: 'Formations', builder: _educationsScreen),
        (icon: Icons.workspace_premium_outlined, label: 'Certifications', builder: _certificationsScreen),
        (icon: Icons.psychology_outlined, label: 'Compétences', builder: _skillsScreen),
      ],
    ),
    (
      label: 'Réalisations',
      sections: [
        (icon: Icons.work_outline_rounded, label: 'Projets', builder: _projectsScreen),
        (icon: Icons.handshake_outlined, label: 'Références', builder: _referencesScreen),
      ],
    ),
    (
      label: 'Référentiels',
      sections: [
        (icon: Icons.memory_rounded, label: 'Technologies', builder: _technologiesScreen),
        (icon: Icons.category_outlined, label: 'Domaines', builder: _domainsScreen),
        (icon: Icons.assignment_ind_outlined, label: 'Profils métier', builder: _jobProfilesScreen),
      ],
    ),
    (
      label: 'Rendez-vous',
      sections: [
        (icon: Icons.event_note_outlined, label: 'Types de rendez-vous', builder: _appointmentTypesScreen),
        (icon: Icons.schedule_rounded, label: 'Disponibilités', builder: _availabilityScreen),
      ],
    ),
    (
      label: 'Musique',
      sections: [(icon: Icons.music_note_outlined, label: 'Pistes et registres', builder: _musicScreen)],
    ),
    (
      label: 'Site',
      sections: [
        (icon: Icons.article_outlined, label: 'Blog', builder: _postsScreen),
        (icon: Icons.devices_other_outlined, label: 'Uses', builder: _usesScreen),
        (icon: Icons.celebration_outlined, label: 'Surprises', builder: _celebrationsScreen),
      ],
    ),
  ];

  static Widget _profileScreen(BuildContext context) => const ProfileScreen();
  static Widget _projectsScreen(BuildContext context) => const ProjectsListScreen();
  static Widget _skillsScreen(BuildContext context) => const SkillsListScreen();
  static Widget _experiencesScreen(BuildContext context) => const ExperiencesListScreen();
  static Widget _educationsScreen(BuildContext context) => const EducationsListScreen();
  static Widget _certificationsScreen(BuildContext context) => const CertificationsListScreen();
  static Widget _technologiesScreen(BuildContext context) => const TechnologiesListScreen();
  static Widget _domainsScreen(BuildContext context) => const DomainsListScreen();
  static Widget _jobProfilesScreen(BuildContext context) => const JobProfilesListScreen();
  static Widget _referencesScreen(BuildContext context) => const ProfessionalReferencesListScreen();
  static Widget _musicScreen(BuildContext context) => const MusicScreen();
  static Widget _celebrationsScreen(BuildContext context) => const CelebrationsListScreen();
  static Widget _postsScreen(BuildContext context) => const PostsListScreen();
  static Widget _usesScreen(BuildContext context) => const UsesItemsListScreen();
  static Widget _appointmentTypesScreen(BuildContext context) => const AppointmentTypesListScreen();
  static Widget _availabilityScreen(BuildContext context) => const AvailabilityScreen();

  /// Nombre d'éléments par section, tiré du tableau de bord (absent si non fourni).
  static int? _countFor(String label, DashboardContent? content) => switch (label) {
    'Expériences' => content?.experiences,
    'Formations' => content?.educations,
    'Compétences' => content?.skills,
    'Projets' => content == null ? null : content.projects.published + content.projects.archived,
    'Technologies' => content?.technologies,
    'Domaines' => content?.domains,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = ref.watch(dashboardProvider).value?.content;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar.statusOnly(),
      // Builder : les marges lues sous le Scaffold tiennent compte des barres flottantes.
      body: Builder(
        builder: (context) => ListView(
          padding: pageInsets(context, horizontal: 20, top: 16),
          children: [
            Text('Contenu', style: theme.textTheme.headlineMedium),
            for (final group in _groups) ...[
              const SizedBox(height: 24),
              SectionHeader(group.label),
              const SizedBox(height: 8),
              _SectionGrid(
                children: [
                  for (final section in group.sections)
                    _SectionTile(
                      icon: section.icon,
                      label: section.label,
                      count: _countFor(section.label, content),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: section.builder)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grille à deux colonnes ; une tuile seule sur sa ligne prend toute la largeur.
class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                if (i + 1 < children.length) ...[const SizedBox(width: 10), Expanded(child: children[i + 1])],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int? count;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon, size: 38),
              const Spacer(),
              if (count != null)
                Text(
                  '$count',
                  style: theme.textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
