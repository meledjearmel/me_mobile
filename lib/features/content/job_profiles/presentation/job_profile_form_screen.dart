import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/models/uploaded_file.dart';
import '../../../../shared/widgets/document_picker_tile.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/job_profile_list_controller.dart';
import '../data/job_profile_repository.dart';

const _maxCvBytes = 10 * 1024 * 1024;

/// Création ou modification d'un profil métier (§4.3). `id == null` : création.
class JobProfileFormScreen extends ConsumerStatefulWidget {
  const JobProfileFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<JobProfileFormScreen> createState() => _JobProfileFormScreenState();
}

class _JobProfileFormScreenState extends ConsumerState<JobProfileFormScreen> {
  late Future<void> _future = _load();

  late final _key = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _label = const Translated();
  Translated _description = const Translated();
  Translated _heroTitle = const Translated();
  Translated _heroWords = const Translated();
  Translated _cvDescription = const Translated();
  PublicationStatus _status = PublicationStatus.draft;
  String _keyForTitle = '';

  CvFiles _cvFiles = const CvFiles();
  PlatformFile? _cvFileFr;
  PlatformFile? _cvFileEn;
  String? _removingCv; // 'fr' | 'en', pour l'indicateur de chargement.

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  double? _uploadProgress;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final jobProfile = await ref.read(jobProfileRepositoryProvider).get(widget.id!);
    _key.text = jobProfile.key;
    _label = jobProfile.label;
    _description = jobProfile.description;
    _heroTitle = jobProfile.heroTitle;
    _heroWords = jobProfile.heroWords;
    _cvDescription = jobProfile.cvDescription;
    _sortOrder.text = '${jobProfile.sortOrder}';
    _status = jobProfile.status;
    _keyForTitle = jobProfile.label.display;
    _cvFiles = jobProfile.cvFiles;
  }

  @override
  void dispose() {
    _key.dispose();
    _sortOrder.dispose();
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

  void _applyCvFile(void Function() apply) {
    setState(apply);
    _markDirty();
  }

  Future<void> _removeCv(String locale) async {
    setState(() => _removingCv = locale);
    try {
      final updated = await ref.read(jobProfileRepositoryProvider).deleteCv(widget.id!, locale);
      setState(() => _cvFiles = updated.cvFiles);
      ref.read(jobProfileListProvider.notifier).updateItem((j) => j.id == widget.id, (j) => updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CV ${locale.toUpperCase()} retiré.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _removingCv = null);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
      _uploadProgress = null;
    });
    try {
      await ref.read(jobProfileRepositoryProvider).save(
            id: widget.id,
            key: _key.text.trim(),
            label: _label,
            description: _description,
            heroTitle: _heroTitle,
            heroWords: _heroWords,
            cvDescription: _cvDescription,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            status: _status,
            cvFileFr: _cvFileFr == null ? null : dio.MultipartFile.fromFileSync(_cvFileFr!.path!, filename: _cvFileFr!.name),
            cvFileEn: _cvFileEn == null ? null : dio.MultipartFile.fromFileSync(_cvFileEn!.path!, filename: _cvFileEn!.name),
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      ref.invalidate(jobProfileListProvider);
      ref.invalidate(jobProfilesRefProvider); // §4.4 : sélecteur (formulaire Projets).
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop();
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le profil métier « $_keyForTitle » ?'),
        content: const Text('Il part à la corbeille : vous pourrez le restaurer si besoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(jobProfileRepositoryProvider).delete(widget.id!);
      ref.read(jobProfileListProvider.notifier).removeItem((j) => j.id == widget.id);
      ref.invalidate(jobProfilesRefProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
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
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier le profil métier' : 'Nouveau profil métier'),
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Réessayer')),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                TextField(
                  controller: _key,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Clé (unique)', errorText: v?.errorFor('key')),
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Libellé',
                  value: _label,
                  maxLength: 255,
                  errorFr: v?.errorFor('label.fr'),
                  errorEn: v?.errorFor('label.en'),
                  onChanged: (value) {
                    setState(() => _label = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Description',
                  value: _description,
                  maxLines: 5,
                  errorFr: v?.errorFor('description.fr'),
                  errorEn: v?.errorFor('description.en'),
                  onChanged: (value) {
                    setState(() => _description = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Titre du hero (15 caractères max.)',
                  value: _heroTitle,
                  maxLength: 15,
                  errorFr: v?.errorFor('hero_title.fr'),
                  errorEn: v?.errorFor('hero_title.en'),
                  onChanged: (value) {
                    setState(() => _heroTitle = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Mots du hero',
                  value: _heroWords,
                  maxLength: 255,
                  errorFr: v?.errorFor('hero_words.fr'),
                  errorEn: v?.errorFor('hero_words.en'),
                  onChanged: (value) {
                    setState(() => _heroWords = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Description pour le CV',
                  value: _cvDescription,
                  maxLines: 5,
                  errorFr: v?.errorFor('cv_description.fr'),
                  errorEn: v?.errorFor('cv_description.en'),
                  onChanged: (value) {
                    setState(() => _cvDescription = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 20),
                Text('CV ciblé pour ce profil', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'Sans CV uploadé pour une langue, celui de l\'autre langue sert de secours, '
                  'sinon il est généré automatiquement.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                DocumentPickerTile(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'CV — Français',
                  hint: 'Aucun CV FR : secours ou généré automatiquement',
                  extensions: const ['pdf'],
                  maxBytes: _maxCvBytes,
                  tooLargeLabel: 'PDF trop lourd (10 Mo maximum).',
                  current: _cvFiles.fr,
                  pickedFile: _cvFileFr,
                  onPicked: (file) => _applyCvFile(() => _cvFileFr = file),
                  onRemove: _isEditing ? () => _removeCv('fr') : null,
                  removing: _removingCv == 'fr',
                ),
                const SizedBox(height: 10),
                DocumentPickerTile(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'CV — Anglais',
                  hint: 'Aucun CV EN : secours ou généré automatiquement',
                  extensions: const ['pdf'],
                  maxBytes: _maxCvBytes,
                  tooLargeLabel: 'PDF trop lourd (10 Mo maximum).',
                  current: _cvFiles.en,
                  pickedFile: _cvFileEn,
                  onPicked: (file) => _applyCvFile(() => _cvFileEn = file),
                  onRemove: _isEditing ? () => _removeCv('en') : null,
                  removing: _removingCv == 'en',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Ordre d\'affichage', errorText: v?.errorFor('sort_order')),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PublicationStatus>(
                  segments: const [
                    ButtonSegment(value: PublicationStatus.draft, label: Text('Brouillon')),
                    ButtonSegment(value: PublicationStatus.published, label: Text('Publié')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) {
                    setState(() => _status = selection.first);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 28),
                if (_uploadProgress != null) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
