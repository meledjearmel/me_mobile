import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/document_picker_tile.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/translated_field.dart';
import '../application/profile_providers.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/photo_picker_tile.dart';

const _maxPhotoBytes = 5 * 1024 * 1024;
const _maxMusicBytes = 20 * 1024 * 1024;

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _cvLastName = TextEditingController(text: widget.profile.cvLastName ?? '');
  late final _cvFirstName = TextEditingController(text: widget.profile.cvFirstName ?? '');
  late final _email = TextEditingController(text: widget.profile.email);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _location = TextEditingController(text: widget.profile.location ?? '');
  late final _github = TextEditingController(text: widget.profile.socialLinks.github ?? '');
  late final _linkedin = TextEditingController(text: widget.profile.socialLinks.linkedin ?? '');

  late Translated _headline = widget.profile.headline;
  late Translated _bioShort = widget.profile.bioShort;
  late Translated _bioFull = widget.profile.bioFull;

  XFile? _photo;
  XFile? _cvPhoto;
  PlatformFile? _music;

  bool _dirty = false;
  bool _saving = false;
  bool _removingMusic = false;
  double? _uploadProgress;
  String? _error;
  ValidationException? _validation;

  @override
  void dispose() {
    for (final c in [_name, _cvLastName, _cvFirstName, _email, _phone, _location, _github, _linkedin]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) {
      return true;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Vos changements non enregistrés seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer l\'édition')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _handlePopAttempt() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickPhoto(bool isCvPhoto, XFile file) async {
    final size = await file.length();
    if (size > _maxPhotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image trop lourde (5 Mo maximum). Choisissez-en une autre ou réessayez.')),
        );
      }
      return;
    }
    setState(() {
      if (isCvPhoto) {
        _cvPhoto = file;
      } else {
        _photo = file;
      }
    });
    _markDirty();
  }

  // La vérification de taille se fait déjà dans DocumentPickerTile (elle a
  // besoin d'un appel asynchrone à `PlatformFile.length()`) : ici on ne fait
  // qu'appliquer le fichier déjà validé.
  void _applyDocument(void Function() apply) {
    setState(apply);
    _markDirty();
  }

  Future<void> _removeMusic() async {
    setState(() => _removingMusic = true);
    try {
      await ref.read(profileRepositoryProvider).deleteMusic();
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Musique retirée : la piste par défaut jouera.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _removingMusic = false);
      }
    }
  }

  dio.MultipartFile? _photoMultipart(XFile? file) =>
      file == null ? null : dio.MultipartFile.fromFileSync(file.path, filename: file.name);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
      _uploadProgress = null;
    });
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .update(
            name: _name.text.trim(),
            cvLastName: _cvLastName.text.trim().isEmpty ? null : _cvLastName.text.trim(),
            cvFirstName: _cvFirstName.text.trim().isEmpty ? null : _cvFirstName.text.trim(),
            headline: _headline,
            bioShort: _bioShort,
            bioFull: _bioFull,
            email: _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
            socialLinks: SocialLinks(
              github: _github.text.trim().isEmpty ? null : _github.text.trim(),
              linkedin: _linkedin.text.trim().isEmpty ? null : _linkedin.text.trim(),
            ),
            photo: _photoMultipart(_photo),
            cvPhoto: _photoMultipart(_cvPhoto),
            music: _music == null ? null : dio.MultipartFile.fromFileSync(_music!.path!, filename: _music!.name),
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _validation;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: const GlassAppBar(),
        bottomNavigationBar: SaveBar(onPressed: _save, saving: _saving, progress: _uploadProgress),
        body: PageListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FormHeader(title: 'Modifier le profil'),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            SurfaceCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      PhotoPickerTile(
                        label: 'Photo du profil',
                        currentUrl: widget.profile.photoUrl,
                        pickedFile: _photo,
                        onPicked: (file) => _pickPhoto(false, file),
                      ),
                      PhotoPickerTile(
                        label: 'Photo du CV',
                        currentUrl: widget.profile.cvPhotoUrl,
                        pickedFile: _cvPhoto,
                        onPicked: (file) => _pickPhoto(true, file),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(labelText: 'Nom affiché', errorText: v?.errorFor('name')),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _cvFirstName,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Prénom (CV)', errorText: v?.errorFor('cv_first_name')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvLastName,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Nom (CV)', errorText: v?.errorFor('cv_last_name')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TranslatedField(
                    label: 'Accroche',
                    value: _headline,
                    maxLength: 255,
                    errorFr: v?.errorFor('headline.fr'),
                    errorEn: v?.errorFor('headline.en'),
                    onChanged: (value) {
                      setState(() => _headline = value);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  TranslatedField(
                    label: 'Bio courte',
                    value: _bioShort,
                    maxLines: 3,
                    errorFr: v?.errorFor('bio_short.fr'),
                    errorEn: v?.errorFor('bio_short.en'),
                    onChanged: (value) {
                      setState(() => _bioShort = value);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  TranslatedField(
                    label: 'Bio complète',
                    value: _bioFull,
                    maxLines: 8,
                    errorFr: v?.errorFor('bio_full.fr'),
                    errorEn: v?.errorFor('bio_full.en'),
                    onChanged: (value) {
                      setState(() => _bioFull = value);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(labelText: 'E-mail', errorText: v?.errorFor('email')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(labelText: 'Téléphone', errorText: v?.errorFor('phone')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _location,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(labelText: 'Localisation', errorText: v?.errorFor('location')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _github,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(
                      labelText: 'GitHub',
                      prefixIcon: const Icon(Icons.link_rounded),
                      errorText: v?.errorFor('social_links.github'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _linkedin,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(
                      labelText: 'LinkedIn',
                      prefixIcon: const Icon(Icons.link_rounded),
                      errorText: v?.errorFor('social_links.linkedin'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Musique du site', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Sans musique uploadée, le site joue une piste par défaut. Le CV se gère '
                    'désormais par profil métier (Contenu → Profils métier).',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  DocumentPickerTile(
                    icon: Icons.music_note_outlined,
                    label: 'Musique du site',
                    hint: 'Aucune musique : piste par défaut',
                    extensions: const ['mp3', 'ogg', 'wav', 'm4a', 'aac'],
                    maxBytes: _maxMusicBytes,
                    tooLargeLabel: 'Fichier audio trop lourd (20 Mo maximum).',
                    current: widget.profile.music,
                    pickedFile: _music,
                    onPicked: (file) => _applyDocument(() => _music = file),
                    onRemove: _removeMusic,
                    removing: _removingMusic,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
