import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';

/// Sommaire des sections de contenu. Les écrans restants arrivent aux
/// étapes 5 à 7.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  static const _sections = [
    (Icons.badge_outlined, 'Profil', 4),
    (Icons.work_outline_rounded, 'Projets', 5),
    (Icons.psychology_outlined, 'Compétences', 6),
    (Icons.timeline_rounded, 'Expériences', 6),
    (Icons.school_outlined, 'Formations', 6),
    (Icons.memory_rounded, 'Technologies', 6),
    (Icons.category_outlined, 'Domaines', 6),
    (Icons.assignment_ind_outlined, 'Profils métier', 6),
    (Icons.handshake_outlined, 'Références', 6),
    (Icons.music_note_outlined, 'Musique', 7),
  ];

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
                for (final (index, (icon, label, step)) in _sections.indexed) ...[
                  if (index > 0) const Divider(indent: 20, endIndent: 20),
                  if (label == 'Profil')
                    ListTile(
                      leading: Icon(icon),
                      title: const Text('Profil'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      ),
                    )
                  else
                    ListTile(
                      enabled: false,
                      leading: Icon(icon),
                      title: Text(label),
                      trailing: Text(
                        'Étape $step',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
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
