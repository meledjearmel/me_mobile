import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/date_field.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../application/education_list_controller.dart';
import '../data/education_repository.dart';

/// Création ou modification d'une formation (§4.3). `id == null` : création.
class EducationFormScreen extends ConsumerStatefulWidget {
  const EducationFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<EducationFormScreen> createState() => _EducationFormScreenState();
}

class _EducationFormScreenState extends ConsumerState<EducationFormScreen> {
  late Future<void> _future = _load();

  late final _institution = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _degree = const Translated();
  Translated _field = const Translated();
  Translated _description = const Translated();
  DateTime? _startDate;
  DateTime? _endDate;
  PublicationStatus _status = PublicationStatus.draft;

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
    final education = await ref.read(educationRepositoryProvider).get(widget.id!);
    _institution.text = education.institution;
    _degree = education.degree;
    _field = education.field;
    _description = education.description;
    _startDate = education.startDate;
    _endDate = education.endDate;
    _sortOrder.text = '${education.sortOrder}';
    _status = education.status;
  }

  @override
  void dispose() {
    _institution.dispose();
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
    if (_startDate == null) {
      setState(() => _error = 'Choisissez une date de début.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref.read(educationRepositoryProvider).save(
            id: widget.id,
            institution: _institution.text.trim(),
            degree: _degree,
            field: _field,
            startDate: _startDate!,
            endDate: _endDate,
            description: _description,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            status: _status,
          );
      ref.invalidate(educationListProvider);
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
        title: Text('Supprimer la formation « ${_institution.text} » ?'),
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
      await ref.read(educationRepositoryProvider).delete(widget.id!);
      ref.read(educationListProvider.notifier).removeItem((e) => e.id == widget.id);
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
          title: Text(_isEditing ? 'Modifier la formation' : 'Nouvelle formation'),
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
                  controller: _institution,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Établissement', errorText: v?.errorFor('institution')),
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Diplôme',
                  value: _degree,
                  maxLength: 255,
                  errorFr: v?.errorFor('degree.fr'),
                  errorEn: v?.errorFor('degree.en'),
                  onChanged: (value) {
                    setState(() => _degree = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Domaine d\'études',
                  value: _field,
                  maxLength: 255,
                  errorFr: v?.errorFor('field.fr'),
                  errorEn: v?.errorFor('field.en'),
                  onChanged: (value) {
                    setState(() => _field = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DateField(
                        label: 'Début',
                        value: _startDate,
                        error: v?.errorFor('start_date'),
                        onChanged: (date) {
                          setState(() => _startDate = date);
                          _markDirty();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DateField(
                        label: 'Fin',
                        value: _endDate,
                        error: v?.errorFor('end_date'),
                        allowClear: true,
                        emptyLabel: 'En cours',
                        firstDate: _startDate,
                        onChanged: (date) {
                          setState(() => _endDate = date);
                          _markDirty();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Description',
                  value: _description,
                  maxLines: 4,
                  errorFr: v?.errorFor('description.fr'),
                  errorEn: v?.errorFor('description.en'),
                  onChanged: (value) {
                    setState(() => _description = value);
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
