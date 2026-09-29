import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../data/reference_repository.dart';
import '../application/professional_reference_list_controller.dart';
import '../data/professional_reference.dart';
import '../data/professional_reference_repository.dart';

/// Création ou modification d'une référence professionnelle (§4.3).
/// `id == null` : création.
class ProfessionalReferenceFormScreen extends ConsumerStatefulWidget {
  const ProfessionalReferenceFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<ProfessionalReferenceFormScreen> createState() => _ProfessionalReferenceFormScreenState();
}

class _ProfessionalReferenceFormScreenState extends ConsumerState<ProfessionalReferenceFormScreen> {
  late Future<void> _future = _load();

  late final _name = TextEditingController();
  late final _role = TextEditingController();
  late final _company = TextEditingController();
  late final _email = TextEditingController();
  late final _phone = TextEditingController();
  late final _relationship = TextEditingController();
  late final _notes = TextEditingController();
  int? _projectId;
  bool _isPublic = false;
  final Set<String> _visibleFields = {};

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
    final reference = await ref.read(professionalReferenceRepositoryProvider).get(widget.id!);
    _name.text = reference.name;
    _role.text = reference.role ?? '';
    _company.text = reference.company ?? '';
    _email.text = reference.email ?? '';
    _phone.text = reference.phone ?? '';
    _relationship.text = reference.relationship ?? '';
    _notes.text = reference.notes ?? '';
    _projectId = reference.projectId;
    _isPublic = reference.isPublic;
    _visibleFields
      ..clear()
      ..addAll(reference.visibleFields);
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _relationship.dispose();
    _notes.dispose();
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
      await ref
          .read(professionalReferenceRepositoryProvider)
          .save(
            id: widget.id,
            name: _name.text.trim(),
            role: _role.text.trim().isEmpty ? null : _role.text.trim(),
            company: _company.text.trim().isEmpty ? null : _company.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            relationship: _relationship.text.trim().isEmpty ? null : _relationship.text.trim(),
            projectId: _projectId,
            isPublic: _isPublic,
            visibleFields: _visibleFields.toList(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(professionalReferenceListProvider);
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
        title: Text('Supprimer la référence « ${_name.text} » ?'),
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
      await ref.read(professionalReferenceRepositoryProvider).delete(widget.id!);
      ref.read(professionalReferenceListProvider.notifier).removeItem((r) => r.id == widget.id);
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
    final projects = ref.watch(projectsLiteRefProvider);

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
                  child: FormHeader(title: _isEditing ? 'Modifier la référence' : 'Nouvelle référence'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Nom', errorText: v?.errorFor('name')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _role,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Rôle', errorText: v?.errorFor('role')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _company,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Société', errorText: v?.errorFor('company')),
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
                        controller: _relationship,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Relation', errorText: v?.errorFor('relationship')),
                      ),
                      const SizedBox(height: 12),
                      projects.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => const Text('Projets indisponibles.'),
                        data: (list) => DropdownButtonFormField<int?>(
                          initialValue: _projectId,
                          decoration: InputDecoration(
                            labelText: 'Projet lié (facultatif)',
                            errorText: v?.errorFor('project_id'),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Aucun')),
                            for (final p in list) DropdownMenuItem(value: p.id, child: Text(p.title.display)),
                          ],
                          onChanged: (value) {
                            setState(() => _projectId = value);
                            _markDirty();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Jointe au CV'),
                        value: _isPublic,
                        onChanged: (value) {
                          setState(() => _isPublic = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Champs affichés sur le CV', style: theme.textTheme.labelLarge),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final field in VisibleField.values)
                            FilterChip(
                              label: Text(field.label),
                              selected: _visibleFields.contains(field.wireValue),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _visibleFields.add(field.wireValue);
                                  } else {
                                    _visibleFields.remove(field.wireValue);
                                  }
                                });
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _notes,
                        maxLines: 4,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Notes privées', errorText: v?.errorFor('notes')),
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
