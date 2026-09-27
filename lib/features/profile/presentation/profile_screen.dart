import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../application/profile_providers.dart';
import '../data/profile.dart';
import 'profile_edit_screen.dart';

/// Aperçu du profil, avant modification (§4.3).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger le profil.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(profileProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
        data: (data) => _ProfileBody(profile: data),
      ),
      floatingActionButton: profile.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () async {
            final updated = await Navigator.of(context).push<Profile>(
              MaterialPageRoute(builder: (context) => ProfileEditScreen(profile: data)),
            );
            if (updated != null) {
              ref.invalidate(profileProvider);
            }
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier'),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        Center(
          child: GestureDetector(
            onTap: profile.photoUrl == null
                ? null
                : () => FullScreenImageViewer.open(context, profile.photoUrl!, heroTag: 'profile-photo'),
            child: Semantics(
              button: profile.photoUrl != null,
              label: profile.photoUrl != null ? 'Photo du profil, voir en plein écran' : 'Aucune photo de profil',
              child: Hero(
                tag: 'profile-photo',
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                  child: profile.photoUrl == null
                      ? Icon(Icons.person_outline_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(profile.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center)),
        if (profile.headline.display.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile.headline.display,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.alternate_email_rounded), title: Text(profile.email)),
              if (profile.phone?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.phone_outlined), title: Text(profile.phone!)),
              ],
              if (profile.location?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.place_outlined), title: Text(profile.location!)),
              ],
              if (profile.socialLinks.github?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.code_rounded), title: Text(profile.socialLinks.github!)),
              ],
              if (profile.socialLinks.linkedin?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.business_center_outlined), title: Text(profile.socialLinks.linkedin!)),
              ],
            ],
          ),
        ),
        if (profile.bioShort.display.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Bio courte', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(profile.bioShort.display),
        ],
        if (profile.bioFull.display.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Bio complète', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(profile.bioFull.display),
        ],
        const SizedBox(height: 20),
        Text('CV et musique', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _CvTile(label: 'CV — Français', file: profile.cvFiles.fr),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _CvTile(label: 'CV — Anglais', file: profile.cvFiles.en),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: const Text('Musique du site'),
                subtitle: Text(profile.music?.fileName ?? 'Piste par défaut'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CvTile extends StatelessWidget {
  const _CvTile({required this.label, required this.file});

  final String label;
  final UploadedFile? file;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(label),
      subtitle: Text(file?.fileName ?? 'Secours ou généré automatiquement'),
      trailing: file == null ? null : const Icon(Icons.open_in_new_rounded),
      onTap: file == null ? null : () => launchUrl(Uri.parse(file!.url), mode: LaunchMode.externalApplication),
    );
  }
}
