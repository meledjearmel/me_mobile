import 'package:flutter/material.dart';

import 'music_genres_list_screen.dart';
import 'tracks_list_screen.dart';

/// Musique du site (§4.3) : registres et pistes, chacun avec sa propre liste.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Musique')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Registres'),
                  subtitle: const Text('Catégories de pistes (ambiance, focus…)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MusicGenresListScreen()),
                  ),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: const Text('Pistes'),
                  subtitle: const Text('Fichiers audio du lecteur du site'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const TracksListScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
