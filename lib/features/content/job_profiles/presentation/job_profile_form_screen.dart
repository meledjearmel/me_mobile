import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/job_profile_list_controller.dart';
import '../data/job_profile_repository.dart';

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

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
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
        setState(() => _saving = false);
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
                const SizedBox(height: 12),
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
