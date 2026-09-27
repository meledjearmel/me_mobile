import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../application/track_list_controller.dart';
import '../data/music_genre_repository.dart';
import '../data/track_repository.dart';

const _maxAudioBytes = 30 * 1024 * 1024;
const _audioExtensions = ['mpeg', 'mp3', 'wav', 'ogg', 'mp4', 'm4a', 'aac'];

/// Création ou modification d'une piste (§4.3). `id == null` : création,
/// où le fichier audio est obligatoire (facultatif en modification, pour
/// simplement remplacer le fichier existant).
class TrackFormScreen extends ConsumerStatefulWidget {
  const TrackFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<TrackFormScreen> createState() => _TrackFormScreenState();
}

class _TrackFormScreenState extends ConsumerState<TrackFormScreen> {
  late Future<void> _future = _load();

  late final _title = TextEditingController();
  late final _artist = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  int? _musicGenreId;
  String? _existingAudioUrl;
  PlatformFile? _audioPending;

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
    final track = await ref.read(trackRepositoryProvider).get(widget.id!);
    _title.text = track.title;
    _artist.text = track.artist ?? '';
    _sortOrder.text = '${track.sortOrder}';
    _musicGenreId = track.musicGenreId;
    _existingAudioUrl = track.audioUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
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

  Future<void> _pickAudio() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _audioExtensions);
    if (files.isEmpty) {
      return;
    }
    final file = files.single;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > _maxAudioBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier audio trop lourd (30 Mo maximum).')),
        );
      }
      return;
    }
    setState(() => _audioPending = file);
    _markDirty();
  }

  Future<void> _save() async {
    if (_musicGenreId == null) {
      setState(() => _error = 'Choisissez un registre.');
      return;
    }
    if (!_isEditing && _audioPending == null) {
      setState(() => _error = 'Un fichier audio est requis pour créer une piste.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
      _uploadProgress = null;
    });
    try {
      await ref.read(trackRepositoryProvider).save(
            id: widget.id,
            musicGenreId: _musicGenreId!,
            title: _title.text.trim(),
            artist: _artist.text.trim().isEmpty ? null : _artist.text.trim(),
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            audio: _audioPending == null
                ? null
                : dio.MultipartFile.fromFileSync(_audioPending!.path!, filename: _audioPending!.name),
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      ref.invalidate(trackListProvider);
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
        title: Text('Supprimer la piste « ${_title.text} » ?'),
        content: const Text('Elle part à la corbeille : vous pourrez la restaurer si besoin.'),
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
      await ref.read(trackRepositoryProvider).delete(widget.id!);
      ref.read(trackListProvider.notifier).removeItem((t) => t.id == widget.id);
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
    final genres = ref.watch(musicGenresAllProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier la piste' : 'Nouvelle piste'),
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
                genres.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const Text('Registres indisponibles.'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _musicGenreId,
                    decoration: InputDecoration(labelText: 'Registre', errorText: v?.errorFor('music_genre_id')),
                    items: [for (final g in list) DropdownMenuItem(value: g.id, child: Text(g.label.display))],
                    onChanged: (value) {
                      setState(() => _musicGenreId = value);
                      _markDirty();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Titre', errorText: v?.errorFor('title')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _artist,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Artiste (facultatif)', errorText: v?.errorFor('artist')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Ordre d\'affichage', errorText: v?.errorFor('sort_order')),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.audiotrack_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fichier audio', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 2),
                              Text(
                                _audioPending != null
                                    ? '${_audioPending!.name} · sera envoyé à l\'enregistrement'
                                    : _existingAudioUrl != null
                                        ? 'Fichier actuel conservé sauf remplacement'
                                        : 'Aucun fichier (obligatoire à la création)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _pickAudio,
                          child: Text(_existingAudioUrl != null || _audioPending != null ? 'Changer' : 'Choisir'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (v?.errorFor('audio') != null) ...[
                  const SizedBox(height: 4),
                  Text(v!.errorFor('audio')!, style: TextStyle(color: theme.colorScheme.error)),
                ],
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
