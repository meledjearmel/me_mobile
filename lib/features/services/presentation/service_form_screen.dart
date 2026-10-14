import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';
import '../../../core/utils/slugify.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/multi_select_field.dart';
import '../../../shared/widgets/translated_field.dart';
import '../../content/data/reference_repository.dart';
import '../../estimator/data/estimator.dart';
import '../../estimator/data/estimator_repository.dart';
import '../../estimator/presentation/widgets/hourly_rates_field.dart';
import '../data/service.dart';
import '../data/service_repository.dart';

/// Création ou modification d'une offre de la page « Services ». `id == null` : création.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  late Future<void> _future = _load();

  final _slug = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');
  bool _slugEdited = false;
  Translated _title = const Translated();
  Translated _tagline = const Translated();
  Translated _description = const Translated();
  Translated _includes = const Translated();
  ServicePriceMode _priceMode = ServicePriceMode.quote;
  int? _estimatorItemId;
  Map<String, int> _manualPrices = const {};
  List<int> _projectIds = const [];
  PublicationStatus _status = PublicationStatus.draft;

  /// Statut enregistré, pour ne demander confirmation qu'au passage en ligne.
  PublicationStatus _savedStatus = PublicationStatus.draft;

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
    final service = await ref.read(serviceRepositoryProvider).get(widget.id!);
    _slug.text = service.slug;
    _slugEdited = true;
    _sortOrder.text = '${service.sortOrder}';
    _title = service.title;
    _tagline = service.tagline;
    _description = service.description;
    _includes = service.includes;
    _priceMode = service.priceMode;
    _estimatorItemId = service.estimatorItemId;
    _manualPrices = service.manualPrices;
    _projectIds = service.projectIds;
    _status = service.status;
    _savedStatus = service.status;
  }

  @override
  void dispose() {
    _slug.dispose();
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

  Future<void> _draftWithAi() async {
    final draft = await showModalBottomSheet<ServiceDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _DraftSheet(),
    );
    if (draft == null) {
      return;
    }
    setState(() {
      _title = _title.copyWith(fr: draft.title);
      _tagline = _tagline.copyWith(fr: draft.tagline ?? _tagline.fr);
      _description = _description.copyWith(fr: draft.description ?? _description.fr);
      _includes = _includes.copyWith(fr: draft.includes ?? _includes.fr);
      if (!_slugEdited || _slug.text.isEmpty) {
        _slug.text = draft.slug.isEmpty ? slugify(draft.title) : draft.slug;
      }
    });
    _markDirty();
  }

  Future<void> _save() async {
    if (_status == PublicationStatus.published && _savedStatus != PublicationStatus.published) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publier l\'offre ?'),
          content: const Text('Elle apparaîtra sur la page « Services » du site dès l\'enregistrement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publier')),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(serviceRepositoryProvider)
          .save(
            id: widget.id,
            slug: _slug.text.trim(),
            title: _title,
            tagline: _tagline,
            description: _description,
            includes: _includes,
            priceMode: _priceMode,
            estimatorItemId: _estimatorItemId,
            manualPrices: _manualPrices,
            projectIds: _projectIds,
            status: _status,
            sortOrder: int.tryParse(_sortOrder.text) ?? 0,
          );
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
        title: Text('Supprimer l\'offre « ${_title.display} » ?'),
        content: const Text('Elle disparaît de la page « Services ».'),
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
      await ref.read(serviceRepositoryProvider).delete(widget.id!);
      _dirty = false;
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
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;
    final projects = ref.watch(projectsLiteRefProvider).value ?? const [];
    final projectTypes = [
      for (final item in ref.watch(estimatorItemsProvider).value ?? const <EstimatorItem>[])
        if (item.kind == EstimatorItemKind.projectType) item,
    ];

    void update(void Function() change) {
      setState(change);
      _markDirty();
    }

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
            IconButton(
              tooltip: 'Rédiger avec l\'IA',
              onPressed: _saving ? null : _draftWithAi,
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            if (_isEditing)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
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
                  child: FormHeader(
                    title: _isEditing ? 'Modifier l\'offre' : 'Nouvelle offre',
                    subtitle: _isEditing ? null : 'Astuce : ✦ en haut rédige le texte à partir de tes notes.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                FormSection(
                  title: 'Texte',
                  hasError: [
                    'slug',
                    'title.fr',
                    'title.en',
                    'tagline.fr',
                    'tagline.en',
                    'description.fr',
                    'description.en',
                    'includes.fr',
                    'includes.en',
                  ].any((k) => v?.errorFor(k) != null),
                  children: [
                    TranslatedField(
                      label: 'Titre (anglais requis pour publier)',
                      value: _title,
                      maxLength: 120,
                      errorFr: v?.errorFor('title.fr'),
                      errorEn: v?.errorFor('title.en'),
                      onChanged: (value) => update(() {
                        _title = value;
                        if (!_slugEdited) {
                          _slug.text = slugify(value.fr);
                        }
                      }),
                    ),
                    TextField(
                      controller: _slug,
                      onChanged: (_) {
                        _slugEdited = true;
                        _markDirty();
                      },
                      decoration: InputDecoration(
                        labelText: 'Ancre',
                        prefixText: '/services#',
                        errorText: v?.errorFor('slug'),
                      ),
                    ),
                    TranslatedField(
                      label: 'Accroche',
                      value: _tagline,
                      maxLength: 200,
                      optional: true,
                      errorFr: v?.errorFor('tagline.fr'),
                      errorEn: v?.errorFor('tagline.en'),
                      onChanged: (value) => update(() => _tagline = value),
                    ),
                    TranslatedField(
                      label: 'Description',
                      value: _description,
                      maxLines: 6,
                      maxLength: 3000,
                      optional: true,
                      errorFr: v?.errorFor('description.fr'),
                      errorEn: v?.errorFor('description.en'),
                      onChanged: (value) => update(() => _description = value),
                    ),
                    TranslatedField(
                      label: 'Prestations incluses (une par ligne)',
                      value: _includes,
                      maxLines: 6,
                      maxLength: 2000,
                      optional: true,
                      errorFr: v?.errorFor('includes.fr'),
                      errorEn: v?.errorFor('includes.en'),
                      onChanged: (value) => update(() => _includes = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Prix',
                  summary: _priceMode.label,
                  hasError: ['price_mode', 'estimator_item_id', 'manual_prices'].any((k) => v?.errorFor(k) != null),
                  children: [
                    SegmentedButton<ServicePriceMode>(
                      showSelectedIcon: false,
                      segments: [
                        for (final m in ServicePriceMode.values) ButtonSegment(value: m, label: Text(m.label)),
                      ],
                      selected: {_priceMode},
                      onSelectionChanged: (selection) => update(() => _priceMode = selection.first),
                    ),
                    Text(_priceMode.hint, style: muted),
                    if (_priceMode == ServicePriceMode.estimator)
                      DropdownButtonFormField<int?>(
                        initialValue: projectTypes.any((t) => t.id == _estimatorItemId) ? _estimatorItemId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Type de projet de l\'estimateur',
                          helperText: 'Donne le prix et le lien « Estimer mon projet ».',
                          helperMaxLines: 2,
                          errorText: v?.errorFor('estimator_item_id'),
                        ),
                        items: [
                          for (final type in projectTypes)
                            DropdownMenuItem(
                              value: type.id,
                              child: Text(
                                '${type.name.display} · ${type.effortLabel}${type.isActive ? '' : ' (masqué)'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => update(() => _estimatorItemId = value),
                      ),
                    if (_priceMode == ServicePriceMode.manual) ...[
                      HourlyRatesField(
                        label: 'Prix « à partir de »',
                        suffix: '',
                        emptyHint: 'Une devise vide n\'affiche pas de prix.',
                        value: _manualPrices,
                        errorFor: (currency) => v?.errorFor('manual_prices.$currency'),
                        onChanged: (prices) {
                          _manualPrices = prices;
                          _markDirty();
                        },
                      ),
                      if (v?.errorFor('manual_prices') != null)
                        Text(
                          v!.errorFor('manual_prices')!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Projets liés',
                  summary: '${_projectIds.length}',
                  children: [
                    MultiSelectField(
                      label: 'Projets qui illustrent l\'offre',
                      options: [for (final p in projects) (id: p.id, label: p.title.display, color: null)],
                      selectedIds: _projectIds,
                      onChanged: (ids) => update(() => _projectIds = ids),
                    ),
                    Text('Leurs avis publiés s\'affichent avec l\'offre.', style: muted),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Publication',
                  hasError: v?.errorFor('status') != null || v?.errorFor('sort_order') != null,
                  children: [
                    SegmentedButton<PublicationStatus>(
                      showSelectedIcon: false,
                      segments: [
                        for (final s in PublicationStatus.values) ButtonSegment(value: s, label: Text(s.label)),
                      ],
                      selected: {_status},
                      onSelectionChanged: (selection) => update(() => _status = selection.first),
                    ),
                    TextField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Ordre sur la page', errorText: v?.errorFor('sort_order')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Notes sur l'offre ; renvoie le texte rédigé par l'IA.
class _DraftSheet extends ConsumerStatefulWidget {
  const _DraftSheet();

  @override
  ConsumerState<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends ConsumerState<_DraftSheet> {
  final _notes = TextEditingController();
  bool _generating = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final draft = await ref.read(serviceRepositoryProvider).draftWithAi(_notes.text);
      if (mounted) {
        Navigator.of(context).pop(draft);
      }
    } on ValidationException catch (e) {
      setState(() => _error = e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return PopScope(
      canPop: !_generating,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rédiger avec l\'IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'L\'IA propose en français le titre, l\'ancre, l\'accroche, la description et les prestations '
                'incluses. Le prix et les projets restent à choisir. Rien n\'est enregistré avant que tu valides.',
                style: muted,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                enabled: !_generating,
                minLines: 5,
                maxLines: 12,
                maxLength: 5000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Tes notes sur l\'offre',
                  hintText: 'Pour qui, ce qui est livré, délais, ce qui la distingue…',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              if (_generating) ...[const LinearProgressIndicator(), const SizedBox(height: 16)],
              FilledButton.icon(
                onPressed: _generating || _notes.text.trim().length < 10 ? null : _generate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating ? 'Rédaction…' : 'Rédiger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
