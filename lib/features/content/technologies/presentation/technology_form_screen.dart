import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/reference_repository.dart';
import '../application/technology_list_controller.dart';
import '../data/technology.dart';
import '../data/technology_repository.dart';

/// Création ou modification d'une technologie (§4.3). `id == null` : création.
class TechnologyFormScreen extends ConsumerStatefulWidget {
  const TechnologyFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<TechnologyFormScreen> createState() => _TechnologyFormScreenState();
}

class _TechnologyFormScreenState extends ConsumerState<TechnologyFormScreen> {
  late Future<void> _future = _load();

  late final _name = TextEditingController();
  late final _icon = TextEditingController();
  TechnologyCategory _category = TechnologyCategory.langages;

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
    final technology = await ref.read(technologyRepositoryProvider).get(widget.id!);
    _name.text = technology.name;
    _icon.text = technology.icon ?? '';
    _category = technology.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
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
      await ref.read(technologyRepositoryProvider).save(
            id: widget.id,
            name: _name.text.trim(),
            category: _category,
            icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
          );
      ref.invalidate(technologyListProvider);
      ref.invalidate(technologiesRefProvider);
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
        title: Text('Supprimer la technologie « ${_name.text} » ?'),
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
      await ref.read(technologyRepositoryProvider).delete(widget.id!);
      ref.read(technologyListProvider.notifier).removeItem((t) => t.id == widget.id);
      ref.invalidate(technologiesRefProvider);
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
          title: Text(_isEditing ? 'Modifier la technologie' : 'Nouvelle technologie'),
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
                  controller: _name,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Nom', errorText: v?.errorFor('name')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TechnologyCategory>(
                  initialValue: _category,
                  decoration: InputDecoration(labelText: 'Catégorie', errorText: v?.errorFor('category')),
                  items: [
                    for (final category in TechnologyCategory.values)
                      DropdownMenuItem(value: category, child: Text(category.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _category = value);
                      _markDirty();
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _icon,
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(labelText: 'Icône (facultatif)', errorText: v?.errorFor('icon')),
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
