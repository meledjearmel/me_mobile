import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../application/uses_item_list_controller.dart';
import '../data/uses_item.dart';
import '../data/uses_item_repository.dart';

/// Création ou modification d'un élément « Uses ». `id == null` : création.
class UsesItemFormScreen extends ConsumerStatefulWidget {
  const UsesItemFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<UsesItemFormScreen> createState() => _UsesItemFormScreenState();
}

class _UsesItemFormScreenState extends ConsumerState<UsesItemFormScreen> {
  late Future<void> _future = _load();

  UsesCategory _category = UsesCategory.development;
  late final _name = TextEditingController();
  late final _url = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _description = const Translated();
  PublicationStatus _status = PublicationStatus.published;

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
    final item = await ref.read(usesItemRepositoryProvider).get(widget.id!);
    _category = item.category;
    _name.text = item.name;
    _url.text = item.url ?? '';
    _sortOrder.text = '${item.sortOrder}';
    _description = item.description;
    _status = item.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _handlePopAttempt() async {
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
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    final url = _url.text.trim();
    try {
      await ref
          .read(usesItemRepositoryProvider)
          .save(
            id: widget.id,
            category: _category,
            name: _name.text.trim(),
            description: _description,
            url: url.isEmpty ? null : url,
            status: _status,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          );
      ref.invalidate(usesItemListProvider);
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
        title: Text('Supprimer « ${_name.text} » ?'),
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
      await ref.read(usesItemRepositoryProvider).delete(widget.id!);
      ref.read(usesItemListProvider.notifier).removeItem((i) => i.id == widget.id);
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
                  child: FormHeader(title: _isEditing ? 'Modifier l\'élément' : 'Nouvel élément « Uses »'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Rubrique', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in UsesCategory.values)
                            ChoiceChip(
                              avatar: Icon(category.icon, size: 18),
                              label: Text(category.label),
                              selected: _category == category,
                              onSelected: (_) {
                                setState(() => _category = category);
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                      if (v?.errorFor('category') != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            v!.errorFor('category')!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        maxLength: 120,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          hintText: 'MacBook Pro, PhpStorm, Figma…',
                          errorText: v?.errorFor('name'),
                        ),
                      ),
                      TranslatedField(
                        label: 'Description (facultative)',
                        value: _description,
                        maxLines: 3,
                        maxLength: 300,
                        errorFr: v?.errorFor('description.fr'),
                        errorEn: v?.errorFor('description.en'),
                        onChanged: (value) {
                          setState(() => _description = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Lien officiel (facultatif)',
                          hintText: 'https://…',
                          prefixIcon: const Icon(Icons.link_rounded),
                          errorText: v?.errorFor('url'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Ordre dans la rubrique',
                          errorText: v?.errorFor('sort_order'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PublicationStatus>(
                        segments: [
                          for (final status in PublicationStatus.values)
                            ButtonSegment(value: status, label: Text(status.label)),
                        ],
                        selected: {_status},
                        showSelectedIcon: false,
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
