import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../application/distinction_context_options.dart';
import '../application/distinction_list_controller.dart';
import '../data/distinction.dart';
import '../data/distinction_repository.dart';

/// Création ou modification d'une distinction. `id == null` : création.
class DistinctionFormScreen extends ConsumerStatefulWidget {
  const DistinctionFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<DistinctionFormScreen> createState() => _DistinctionFormScreenState();
}

class _DistinctionFormScreenState extends ConsumerState<DistinctionFormScreen> {
  late Future<void> _future = _load();

  Translated _title = const Translated();
  Translated _description = const Translated();
  late final _issuer = TextEditingController();
  late final _url = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  DateTime? _awardedOn;
  DistinctionContextType? _contextType;
  int? _contextId;

  /// Libellé renvoyé par le serveur, affiché si la liste ne se charge pas.
  String? _contextLabel;
  PublicationStatus _status = PublicationStatus.published;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  static final _dateLabel = DateFormat('d MMMM y', 'fr_FR');

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final d = await ref.read(distinctionRepositoryProvider).get(widget.id!);
    _title = d.title;
    _description = d.description;
    _issuer.text = d.issuer;
    _url.text = d.url ?? '';
    _sortOrder.text = '${d.sortOrder}';
    _awardedOn = d.awardedOn;
    _contextType = d.contextType;
    _contextId = d.contextId;
    _contextLabel = d.contextLabel;
    _status = d.status;
  }

  @override
  void dispose() {
    _issuer.dispose();
    _url.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  String? _orNull(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

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

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _awardedOn ?? today,
      firstDate: DateTime(1990),
      lastDate: today,
    );
    if (date != null) {
      setState(() => _awardedOn = date);
      _markDirty();
    }
  }

  Future<void> _save() async {
    final awardedOn = _awardedOn;
    if (awardedOn == null) {
      setState(() => _error = 'Indiquez la date de remise.');
      return;
    }
    if (_contextType != null && _contextId == null) {
      setState(() => _error = 'Choisissez l\'élément de rattachement, ou « Aucun ».');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(distinctionRepositoryProvider)
          .save(
            id: widget.id,
            title: _title,
            issuer: _issuer.text.trim(),
            description: _description,
            awardedOn: awardedOn,
            url: _orNull(_url),
            contextType: _contextType,
            contextId: _contextId,
            status: _status,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          );
      ref.invalidate(distinctionListProvider);
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
        title: Text('Supprimer « ${_title.display} » ?'),
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
      await ref.read(distinctionRepositoryProvider).delete(widget.id!);
      ref.read(distinctionListProvider.notifier).removeItem((d) => d.id == widget.id);
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
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  /// Type de rattachement, puis l'élément dans la liste correspondante.
  /// Changer de type vide le choix précédent.
  Widget _buildContextPicker(ValidationException? v, TextStyle? errorStyle) {
    final type = _contextType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DistinctionContextType?>(
          segments: [
            const ButtonSegment(value: null, label: Text('Aucun')),
            for (final t in DistinctionContextType.values) ButtonSegment(value: t, label: Text(t.label)),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() {
              _contextType = selection.first;
              _contextId = null;
              _contextLabel = null;
            });
            _markDirty();
          },
        ),
        if (v?.errorFor('context_type') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(v!.errorFor('context_type')!, style: errorStyle),
          ),
        if (type != null) ...[
          const SizedBox(height: 12),
          ref
              .watch(distinctionContextOptionsProvider(type))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  _contextLabel == null ? 'Liste indisponible.' : 'Rattachée à « $_contextLabel » (liste indisponible).',
                ),
                data: (options) => DropdownButtonFormField<int>(
                  key: ValueKey(type),
                  initialValue: options.any((o) => o.id == _contextId) ? _contextId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: type.label, errorText: v?.errorFor('context_id')),
                  items: [
                    for (final o in options)
                      DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) {
                    setState(() => _contextId = value);
                    _markDirty();
                  },
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final v = _validation;
    final errorStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: _isEditing ? 'Modifier' : 'Nouvelle distinction'),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatedField(
                label: 'Intitulé',
                value: _title,
                errorFr: v?.errorFor('title.fr'),
                errorEn: v?.errorFor('title.en'),
                onChanged: (value) {
                  setState(() => _title = value);
                  _markDirty();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issuer,
                maxLength: 120,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(
                  labelText: 'Organisme',
                  hintText: 'CIAPOL, jury d\'un concours…',
                  errorText: v?.errorFor('issuer'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text(_awardedOn == null ? 'Date de remise' : 'Reçue le ${_dateLabel.format(_awardedOn!)}'),
                subtitle: v?.errorFor('awarded_on') == null
                    ? null
                    : Text(v!.errorFor('awarded_on')!, style: errorStyle),
                onTap: _pickDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatedField(
                label: 'Contexte (facultatif)',
                value: _description,
                maxLines: 4,
                maxLength: 500,
                optional: true,
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
                  labelText: 'Lien (facultatif)',
                  hintText: 'https://…',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: v?.errorFor('url'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rattachée à', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _buildContextPicker(v, errorStyle),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(labelText: 'Ordre d\'affichage', errorText: v?.errorFor('sort_order')),
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
  }
}
