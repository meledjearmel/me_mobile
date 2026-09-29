import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_assist_repository.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/technology_list_controller.dart';
import '../data/technology_category_repository.dart';
import '../data/technology_icon.dart';
import '../data/technology_repository.dart';
import 'technology_icon_picker_screen.dart';
import 'technology_logo.dart';

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
  String? _icon;
  String? _iconLightUrl;
  String? _iconDarkUrl;
  int? _categoryId;
  Translated _description = const Translated();

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
    _icon = technology.icon;
    _iconLightUrl = technology.iconLightUrl;
    _iconDarkUrl = technology.iconDarkUrl;
    _categoryId = technology.categoryId;
    _description = technology.description;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  /// Description générée par l'IA à partir du nom et du libellé de la catégorie.
  Future<Translated> _generateDescription() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      throw const ValidationException('Saisissez d\'abord le nom de la technologie.', {});
    }
    final categories = ref.read(technologyCategoriesAllProvider).value ?? const [];
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    return ref.read(aiAssistRepositoryProvider).describeTechnology(name: name, category: category?.label.fr);
  }

  Future<void> _pickIcon() async {
    final picked = await Navigator.of(context)
        .push<TechnologyIcon>(MaterialPageRoute(builder: (context) => TechnologyIconPickerScreen(selectedSlug: _icon)));
    if (picked == null) {
      return;
    }
    setState(() {
      _icon = picked.slug;
      _iconLightUrl = picked.lightUrl;
      _iconDarkUrl = picked.darkUrl;
      _dirty = true;
    });
  }

  void _clearIcon() => setState(() {
    _icon = null;
    _iconLightUrl = null;
    _iconDarkUrl = null;
    _dirty = true;
  });

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
    if (_categoryId == null) {
      setState(
        () => _validation = const ValidationException('Choisissez une catégorie.', {
          'category_id': ['Choisissez une catégorie.'],
        }),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(technologyRepositoryProvider)
          .save(
            id: widget.id,
            name: _name.text.trim(),
            categoryId: _categoryId!,
            description: _description,
            icon: _icon,
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
                  child: FormHeader(title: _isEditing ? 'Modifier la technologie' : 'Nouvelle technologie'),
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
                      _CategoryField(
                        value: _categoryId,
                        error: v?.errorFor('category_id'),
                        onChanged: (value) {
                          setState(() => _categoryId = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TranslatedField(
                        label: 'Description (infobulle, facultatif)',
                        value: _description,
                        maxLength: 150,
                        maxLines: 2,
                        errorFr: v?.errorFor('description.fr'),
                        errorEn: v?.errorFor('description.en'),
                        generate: _generateDescription,
                        onChanged: (value) {
                          setState(() => _description = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      _IconTile(
                        slug: _icon,
                        lightUrl: _iconLightUrl,
                        darkUrl: _iconDarkUrl,
                        error: v?.errorFor('icon'),
                        onPick: _pickIcon,
                        onClear: _clearIcon,
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

/// Ligne « Logo » du formulaire : aperçu, nom dans la bibliothèque, changement et retrait.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.slug,
    required this.lightUrl,
    required this.darkUrl,
    required this.error,
    required this.onPick,
    required this.onClear,
  });

  final String? slug;
  final String? lightUrl;
  final String? darkUrl;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            TechnologyLogo(lightUrl: lightUrl, darkUrl: darkUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logo (facultatif)', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    error ?? slug ?? 'Aucun logo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error != null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (slug != null)
              IconButton(tooltip: 'Retirer le logo', onPressed: onClear, icon: const Icon(Icons.close_rounded)),
            TextButton(onPressed: onPick, child: Text(slug == null ? 'Choisir' : 'Changer')),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur de catégorie, alimenté par `/v1/technology-categories`.
class _CategoryField extends ConsumerWidget {
  const _CategoryField({required this.value, required this.error, required this.onChanged});

  final int? value;
  final String? error;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(technologyCategoriesAllProvider);

    return categories.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Catégorie'),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Catégorie',
          errorText: error is ApiException ? error.message : 'Catégories indisponibles.',
          suffixIcon: IconButton(
            tooltip: 'Réessayer',
            onPressed: () => ref.invalidate(technologyCategoriesAllProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        child: const SizedBox.shrink(),
      ),
      data: (all) => DropdownButtonFormField<int>(
        // Une catégorie supprimée entre-temps ne doit pas faire planter le menu.
        initialValue: all.any((c) => c.id == value) ? value : null,
        decoration: InputDecoration(
          labelText: 'Catégorie',
          errorText: error,
          helperText: all.isEmpty
              ? 'Aucune catégorie : créez-en une depuis Contenu › Catégories de technologies.'
              : null,
          helperMaxLines: 2,
        ),
        items: [for (final category in all) DropdownMenuItem(value: category.id, child: Text(category.label.display))],
        onChanged: onChanged,
      ),
    );
  }
}
