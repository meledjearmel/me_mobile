import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../projects/presentation/projects_list_screen.dart';
import '../domains/presentation/domains_list_screen.dart';
import '../educations/presentation/educations_list_screen.dart';
import '../experiences/presentation/experiences_list_screen.dart';
import '../job_profiles/presentation/job_profiles_list_screen.dart';
import '../professional_references/presentation/professional_references_list_screen.dart';
import '../skills/presentation/skills_list_screen.dart';
import '../technologies/presentation/technologies_list_screen.dart';

/// Sommaire des sections de contenu. La musique arrive à l'étape 7.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  static const _sections = [
    (icon: Icons.badge_outlined, label: 'Profil', step: null, builder: _profileScreen),
    (icon: Icons.work_outline_rounded, label: 'Projets', step: null, builder: _projectsScreen),
    (icon: Icons.psychology_outlined, label: 'Compétences', step: null, builder: _skillsScreen),
    (icon: Icons.timeline_rounded, label: 'Expériences', step: null, builder: _experiencesScreen),
    (icon: Icons.school_outlined, label: 'Formations', step: null, builder: _educationsScreen),
    (icon: Icons.memory_rounded, label: 'Technologies', step: null, builder: _technologiesScreen),
    (icon: Icons.category_outlined, label: 'Domaines', step: null, builder: _domainsScreen),
    (icon: Icons.assignment_ind_outlined, label: 'Profils métier', step: null, builder: _jobProfilesScreen),
    (icon: Icons.handshake_outlined, label: 'Références', step: null, builder: _referencesScreen),
    (icon: Icons.music_note_outlined, label: 'Musique', step: 7, builder: null),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contenu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, section) in _sections.indexed) ...[
                  if (index > 0) const Divider(indent: 20, endIndent: 20),
                  ListTile(
                    enabled: section.builder != null,
                    leading: Icon(section.icon),
                    title: Text(section.label),
                    trailing: section.builder != null
                        ? const Icon(Icons.chevron_right_rounded)
                        : Text(
                            'Étape ${section.step}',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                    onTap: section.builder == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(builder: section.builder!)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
