import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../projects/presentation/projects_list_screen.dart';

/// Sommaire des sections de contenu. Les écrans restants arrivent à l'étape 6
/// (et 7 pour la musique).
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  static const _sections = [
    (icon: Icons.badge_outlined, label: 'Profil', step: 4, builder: _profileScreen),
    (icon: Icons.work_outline_rounded, label: 'Projets', step: 5, builder: _projectsScreen),
    (icon: Icons.psychology_outlined, label: 'Compétences', step: 6, builder: null),
    (icon: Icons.timeline_rounded, label: 'Expériences', step: 6, builder: null),
    (icon: Icons.school_outlined, label: 'Formations', step: 6, builder: null),
    (icon: Icons.memory_rounded, label: 'Technologies', step: 6, builder: null),
    (icon: Icons.category_outlined, label: 'Domaines', step: 6, builder: null),
    (icon: Icons.assignment_ind_outlined, label: 'Profils métier', step: 6, builder: null),
    (icon: Icons.handshake_outlined, label: 'Références', step: 6, builder: null),
    (icon: Icons.music_note_outlined, label: 'Musique', step: 7, builder: null),
  ];

  static Widget _profileScreen(BuildContext context) => const ProfileScreen();
  static Widget _projectsScreen(BuildContext context) => const ProjectsListScreen();

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
