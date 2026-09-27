import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/multi_select_field.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/skill_list_controller.dart';
import '../data/skill_repository.dart';

/// Création ou modification d'une compétence (§4.3). `id == null` : création.
class SkillFormScreen extends ConsumerStatefulWidget {
  const SkillFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<SkillFormScreen> createState() => _SkillFormScreenState();
}

class _SkillFormScreenState extends ConsumerState<SkillFormScreen> {
  late Future<void> _future = _load();

  late final _sortOrder = TextEditingController(text: '0');
  int? _domainId;
  Translated _name = const Translated();
  Translated _description = const Translated();
  Translated _details = const Translated();
  List<int> _technologyIds = [];
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
    final skill = await ref.read(skillRepositoryProvider).get(widget.id!);
    _domainId = skill.domainId;
    _name = skill.name;
    _description = skill.description;
    _details = skill.details;
    _technologyIds = skill.technologies.map((t) => t.id).toList();
    _sortOrder.text = '${skill.sortOrder}';
    _status = skill.status;
  }

  @override
  void dispose() {
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

  /// Garde l'ordre déjà choisi pour les éléments conservés, ajoute les
  /// nouveaux à la fin (§4.3 : l'ordre est ensuite ajustable à la main).
  void _onTechnologiesChanged(List<int> newIds) {
    final kept = _technologyIds.where(newIds.contains).toList();
    final added = newIds.where((id) => !kept.contains(id)).toList();
    setState(() => _technologyIds = [...kept, ...added]);
    _markDirty();
  }

  Future<void> _save() async {
    if (_domainId == null) {
      setState(() => _error = 'Choisissez un domaine.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref.read(skillRepositoryProvider).save(
            id: widget.id,
            domainId: _domainId!,
            name: _name,
            description: _description,
            details: _details,
            technologies: _technologyIds,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            status: _status,
          );
      ref.invalidate(skillListProvider);
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
        title: Text('Supprimer la compétence « ${_name.display} » ?'),
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
      await ref.read(skillRepositoryProvider).delete(widget.id!);
      ref.read(skillListProvider.notifier).removeItem((s) => s.id == widget.id);
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
    final domains = ref.watch(domainsRefProvider);
    final technologies = ref.watch(technologiesRefProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier la compétence' : 'Nouvelle compétence'),
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
                domains.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const Text('Domaines indisponibles.'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _domainId,
                    decoration: InputDecoration(labelText: 'Domaine', errorText: v?.errorFor('domain_id')),
                    items: [for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.label.display))],
                    onChanged: (value) {
                      setState(() => _domainId = value);
                      _markDirty();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TranslatedField(
                  label: 'Nom',
                  value: _name,
                  maxLength: 255,
                  errorFr: v?.errorFor('name.fr'),
                  errorEn: v?.errorFor('name.en'),
                  onChanged: (value) {
                    setState(() => _name = value);
                    _markDirty();
                  },
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
                TranslatedField(
                  label: 'Détails',
                  value: _details,
                  maxLines: 4,
                  errorFr: v?.errorFor('details.fr'),
                  errorEn: v?.errorFor('details.en'),
                  onChanged: (value) {
                    setState(() => _details = value);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 20),
                technologies.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const SizedBox.shrink(),
                  data: (list) => MultiSelectField(
                    label: 'Technologies',
                    options: [for (final t in list) (id: t.id, label: t.name, color: null)],
                    selectedIds: _technologyIds,
                    onChanged: _onTechnologiesChanged,
                  ),
                ),
                if (_technologyIds.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Glissez pour ordonner (l\'ordre est conservé) :',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  technologies.maybeWhen(
                    data: (list) {
                      final byId = {for (final t in list) t.id: t.name};
                      return ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _technologyIds.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final id = _technologyIds.removeAt(oldIndex);
                            _technologyIds.insert(newIndex, id);
                          });
                          _markDirty();
                        },
                        itemBuilder: (context, index) {
                          final id = _technologyIds[index];
                          return ListTile(
                            key: ValueKey(id),
                            dense: true,
                            leading: const Icon(Icons.drag_indicator_rounded),
                            title: Text(byId[id] ?? '#$id'),
                          );
                        },
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
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
