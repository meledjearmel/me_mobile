import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../projects/presentation/projects_list_screen.dart';
import '../domains/presentation/domains_list_screen.dart';
import '../educations/presentation/educations_list_screen.dart';
import '../experiences/presentation/experiences_list_screen.dart';
import '../job_profiles/presentation/job_profiles_list_screen.dart';
import '../music/presentation/music_screen.dart';
import '../professional_references/presentation/professional_references_list_screen.dart';
import '../skills/presentation/skills_list_screen.dart';
import '../technologies/presentation/technologies_list_screen.dart';

/// Sommaire des sections de contenu (§4.3), groupées comme le menu
/// d'administration du site : Parcours, Réalisations, Référentiels, Musique.
/// Les catégories de technologies s'ouvrent depuis l'écran Technologies.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  static const _groups = [
    (
      label: 'Parcours',
      sections: [
        (icon: Icons.badge_outlined, label: 'Profil', builder: _profileScreen),
        (icon: Icons.timeline_rounded, label: 'Expériences', builder: _experiencesScreen),
        (icon: Icons.school_outlined, label: 'Formations', builder: _educationsScreen),
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
      label: 'Musique',
      sections: [
        (icon: Icons.music_note_outlined, label: 'Pistes et registres', builder: _musicScreen),
      ],
    ),
  ];

  static Widget _profileScreen(BuildContext context) => const ProfileScreen();
  static Widget _projectsScreen(BuildContext context) => const ProjectsListScreen();
  static Widget _skillsScreen(BuildContext context) => const SkillsListScreen();
  static Widget _experiencesScreen(BuildContext context) => const ExperiencesListScreen();
  static Widget _educationsScreen(BuildContext context) => const EducationsListScreen();
  static Widget _technologiesScreen(BuildContext context) => const TechnologiesListScreen();
  static Widget _domainsScreen(BuildContext context) => const DomainsListScreen();
  static Widget _jobProfilesScreen(BuildContext context) => const JobProfilesListScreen();
  static Widget _referencesScreen(BuildContext context) => const ProfessionalReferencesListScreen();
  static Widget _musicScreen(BuildContext context) => const MusicScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contenu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final (groupIndex, group) in _groups.indexed) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(4, groupIndex == 0 ? 8 : 24, 4, 8),
              child: Text(
                group.label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (index, section) in group.sections.indexed) ...[
                    if (index > 0) const Divider(indent: 20, endIndent: 20),
                    ListTile(
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: section.builder)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
