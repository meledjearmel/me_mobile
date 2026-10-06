import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/date_field.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../application/experience_list_controller.dart';
import '../data/experience.dart';
import '../data/experience_repository.dart';
import '../../../../shared/widgets/mention_button.dart';

/// Création ou modification d'une expérience (§4.3). `id == null` : création.
class ExperienceFormScreen extends ConsumerStatefulWidget {
  const ExperienceFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<ExperienceFormScreen> createState() => _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends ConsumerState<ExperienceFormScreen> {
  late Future<void> _future = _load();

  late final _company = TextEditingController();
  late final _location = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _role = const Translated();
  Translated _description = const Translated();
  DateTime? _startDate;
  DateTime? _endDate;
  PublicationStatus _status = PublicationStatus.draft;
  List<Highlight> _highlights = [];

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
    final experience = await ref.read(experienceRepositoryProvider).get(widget.id!);
    _company.text = experience.company;
    _location.text = experience.location ?? '';
    _role = experience.role;
    _description = experience.description;
    _startDate = experience.startDate;
    _endDate = experience.endDate;
    _sortOrder.text = '${experience.sortOrder}';
    _status = experience.status;
    _highlights = List.of(experience.highlights);
  }

  @override
  void dispose() {
    _company.dispose();
    _location.dispose();
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

  Future<void> _editHighlight(int index) async {
    final isNew = index == _highlights.length;
    var text = isNew ? const Translated() : _highlights[index].text;

    final saved = await showDialog<Translated>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Nouveau point marquant' : 'Modifier le point marquant'),
          content: SizedBox(
            width: 400,
            child: TranslatedField(
              label: 'Texte',
              value: text,
              maxLines: 3,
              onChanged: (value) => setDialogState(() => text = value),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, text), child: const Text('Valider')),
          ],
        ),
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      if (isNew) {
        _highlights = [..._highlights, Highlight(text: saved, sortOrder: _highlights.length)];
      } else {
        _highlights[index] = _highlights[index].copyWith(text: saved);
      }
    });
    _markDirty();
  }

  void _removeHighlight(int index) {
    setState(() => _highlights = List.of(_highlights)..removeAt(index));
    _markDirty();
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
      // sort_order suit l'ordre d'écran, y compris pour les points sans id (§4.3).
      final orderedHighlights = [
        for (final (index, highlight) in _highlights.indexed)
          Highlight(id: highlight.id, text: highlight.text, sortOrder: index),
      ];
      await ref
          .read(experienceRepositoryProvider)
          .save(
            id: widget.id,
            company: _company.text.trim(),
            role: _role,
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
            startDate: _startDate!,
            endDate: _endDate,
            description: _description,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            status: _status,
            highlights: orderedHighlights,
          );
      ref.invalidate(experienceListProvider);
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
        title: Text('Supprimer l\'expérience « ${_company.text} » ?'),
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
      await ref.read(experienceRepositoryProvider).delete(widget.id!);
      ref.read(experienceListProvider.notifier).removeItem((e) => e.id == widget.id);
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
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: GlassAppBar(
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
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          // Pas d'enregistrement tant que le formulaire n'est pas chargé.
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(onPressed: _save, saving: _saving)
              : const SizedBox.shrink(),
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
              padding: pageInsets(context),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormHeader(title: _isEditing ? 'Modifier l\'expérience' : 'Nouvelle expérience'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _company,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Société', errorText: v?.errorFor('company')),
                      ),
                      const SizedBox(height: 12),
                      TranslatedField(
                        label: 'Rôle',
                        value: _role,
                        maxLength: 255,
                        errorFr: v?.errorFor('role.fr'),
                        errorEn: v?.errorFor('role.en'),
                        onChanged: (value) {
                          setState(() => _role = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _location,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Lieu (facultatif)', errorText: v?.errorFor('location')),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DateField(
                            label: 'Début',
                            value: _startDate,
                            error: v?.errorFor('start_date'),
                            onChanged: (date) {
                              setState(() => _startDate = date);
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 12),
                          DateField(
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
                      MentionButton(
                        value: _description,
                        onChanged: (value) {
                          setState(() => _description = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Points marquants', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (_highlights.isEmpty)
                        Text(
                          'Aucun point marquant pour l\'instant.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _highlights.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = _highlights.removeAt(oldIndex);
                              _highlights.insert(newIndex, item);
                            });
                            _markDirty();
                          },
                          itemBuilder: (context, index) {
                            final highlight = _highlights[index];
                            return ListTile(
                              key: ValueKey(highlight.id ?? 'new-$index-${highlight.hashCode}'),
                              dense: true,
                              leading: const Icon(Icons.drag_indicator_rounded),
                              title: Text(
                                highlight.text.display.isEmpty ? '(vide)' : highlight.text.display,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _editHighlight(index),
                              trailing: IconButton(
                                tooltip: 'Retirer ce point marquant',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _removeHighlight(index),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _editHighlight(_highlights.length),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter un point marquant'),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Ordre d\'affichage',
                          errorText: v?.errorFor('sort_order'),
                        ),
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
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
