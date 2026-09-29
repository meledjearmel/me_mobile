import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/technology_category_list_controller.dart';
import '../application/technology_list_controller.dart';
import '../data/technology_category_repository.dart';

/// Création ou modification d'une catégorie de technologie. `id == null` : création.
class TechnologyCategoryFormScreen extends ConsumerStatefulWidget {
  const TechnologyCategoryFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<TechnologyCategoryFormScreen> createState() => _TechnologyCategoryFormScreenState();
}

class _TechnologyCategoryFormScreenState extends ConsumerState<TechnologyCategoryFormScreen> {
  late Future<void> _future = _load();

  late final _key = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _label = const Translated();

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
    final category = await ref.read(technologyCategoryRepositoryProvider).get(widget.id!);
    _key.text = category.key;
    _label = category.label;
    _sortOrder.text = '${category.sortOrder}';
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
      await ref
          .read(technologyCategoryRepositoryProvider)
          .save(
            id: widget.id,
            key: _key.text.trim(),
            label: _label,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          );
      ref.invalidate(technologyCategoryListProvider);
      ref.invalidate(technologyCategoriesAllProvider);
      ref.invalidate(technologyListProvider);
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
        title: Text('Supprimer la catégorie « ${_label.display} » ?'),
        content: const Text(
          'Elle part à la corbeille avec toutes les technologies qui lui sont rattachées. Vous pourrez la restaurer si besoin.',
        ),
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
      await ref.read(technologyCategoryRepositoryProvider).delete(widget.id!);
      ref.read(technologyCategoryListProvider.notifier).removeItem((c) => c.id == widget.id);
      ref.invalidate(technologyCategoriesAllProvider);
      // Suppression en cascade : les technologies de la catégorie partent aussi.
      ref.invalidate(technologyListProvider);
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
                  child: FormHeader(title: _isEditing ? 'Modifier la catégorie' : 'Nouvelle catégorie'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
