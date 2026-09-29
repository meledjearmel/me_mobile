import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/color_picker_field.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/reference_repository.dart';
import '../application/domain_list_controller.dart';
import '../data/domain_repository.dart';

/// Création ou modification d'un domaine (§4.3). `id == null` : création.
class DomainFormScreen extends ConsumerStatefulWidget {
  const DomainFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<DomainFormScreen> createState() => _DomainFormScreenState();
}

class _DomainFormScreenState extends ConsumerState<DomainFormScreen> {
  late Future<void> _future = _load();

  late final _key = TextEditingController();
  late final _icon = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  Translated _label = const Translated();
  String? _color;
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
    final domain = await ref.read(domainRepositoryProvider).get(widget.id!);
    _key.text = domain.key;
    _label = domain.label;
    _color = domain.color;
    _icon.text = domain.icon;
    _sortOrder.text = '${domain.sortOrder}';
    _status = domain.status;
  }

  @override
  void dispose() {
    _key.dispose();
    _icon.dispose();
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
          .read(domainRepositoryProvider)
          .save(
            id: widget.id,
            key: _key.text.trim(),
            label: _label,
            color: _color ?? '#999999',
            icon: _icon.text.trim(),
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            status: _status,
          );
      ref.invalidate(domainListProvider);
      ref.invalidate(domainsRefProvider); // §4.4 : sélecteur de domaines (formulaire Projets, Compétences).
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
        title: Text('Supprimer le domaine « ${_label.display} » ?'),
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
      await ref.read(domainRepositoryProvider).delete(widget.id!);
      ref.read(domainListProvider.notifier).removeItem((d) => d.id == widget.id);
      ref.invalidate(domainsRefProvider);
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
                  child: FormHeader(title: _isEditing ? 'Modifier le domaine' : 'Nouveau domaine'),
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
                      const SizedBox(height: 20),
                      ColorPickerField(
                        value: _color,
                        error: v?.errorFor('color'),
                        onChanged: (value) {
                          setState(() => _color = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _icon,
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(labelText: 'Icône', errorText: v?.errorFor('icon')),
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
