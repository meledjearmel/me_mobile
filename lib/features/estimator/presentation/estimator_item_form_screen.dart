import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/multi_select_field.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/translated_field.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';
import 'widgets/hourly_rates_field.dart';

/// Création ou modification d'un type de projet ou d'une option.
/// Renvoie `true` si l'élément a changé (enregistré ou supprimé).
class EstimatorItemFormScreen extends ConsumerStatefulWidget {
  const EstimatorItemFormScreen({super.key, required this.kind, this.item});

  final EstimatorItemKind kind;
  final EstimatorItem? item;

  @override
  ConsumerState<EstimatorItemFormScreen> createState() => _EstimatorItemFormScreenState();
}

class _EstimatorItemFormScreenState extends ConsumerState<EstimatorItemFormScreen> {
  late final EstimatorItem? _item = widget.item;

  late Translated _name = _item?.name ?? const Translated();
  late Translated _description = _item?.description ?? const Translated();
  late final _hoursMin = TextEditingController(text: _item == null ? '' : '${_item.hoursMin}');
  late final _hoursMax = TextEditingController(text: _item == null ? '' : '${_item.hoursMax}');
  late final _percent = TextEditingController(text: _item?.percent?.toString() ?? '');
  late final _sortOrder = TextEditingController(text: '${_item?.sortOrder ?? 0}');
  late EstimatorBilling _billing = _item?.billing ?? EstimatorBilling.fixed;
  late EstimatorPricing _pricing = _item?.pricing ?? EstimatorPricing.hours;
  late List<int> _projectTypeIds = _item?.projectTypeIds ?? const [];
  late int? _rateId = _item?.rateId;
  late HourlyRates _ownRates = _item?.hourlyRates ?? const {};
  late bool _isActive = _item?.isActive ?? true;

  /// Explication de l'IA après « Chiffrer avec l'IA ».
  String? _aiReasoning;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  ValidationException? _validation;

  bool get _isFeature => widget.kind == EstimatorItemKind.feature;
  bool get _isPercent => _isFeature && _pricing == EstimatorPricing.percent;

  @override
  void dispose() {
    for (final controller in [_hoursMin, _hoursMax, _percent, _sortOrder]) {
      controller.dispose();
    }
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

  Future<void> _suggest() async {
    final suggestion = await showModalBottomSheet<EstimatorItemSuggestion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SuggestSheet(kind: widget.kind, initialName: _name.fr),
    );
    if (suggestion == null) {
      return;
    }
    setState(() {
      _name = suggestion.name;
      if (!suggestion.description.isEmpty) {
        _description = suggestion.description;
      }
      if (_isFeature && suggestion.pricing != null) {
        _pricing = suggestion.pricing!;
      }
      if (suggestion.percent != null) {
        _percent.text = '${suggestion.percent}';
      }
      if (!_isPercent) {
        _hoursMin.text = '${suggestion.hoursMin}';
        _hoursMax.text = '${suggestion.hoursMax}';
      }
      _aiReasoning = suggestion.reasoning;
    });
    _markDirty();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(estimatorRepositoryProvider)
          .saveItem(
            id: _item?.id,
            kind: widget.kind,
            name: _name,
            description: _description,
            hoursMin: int.tryParse(_hoursMin.text),
            hoursMax: int.tryParse(_hoursMax.text),
            pricing: _isFeature ? _pricing : null,
            percent: int.tryParse(_percent.text),
            billing: _isFeature ? null : _billing,
            projectTypeIds: _projectTypeIds,
            // Une option en pourcentage suit le taux du type de projet.
            rateId: _isPercent ? null : _rateId,
            hourlyRates: _isPercent ? const {} : _ownRates,
            isActive: _isActive,
            sortOrder: int.tryParse(_sortOrder.text) ?? 0,
          );
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop(true);
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
        title: Text('Supprimer « ${_item!.name.display} » ?'),
        content: Text(
          _isFeature
              ? 'L\'option ne sera plus proposée au visiteur.'
              : 'Le type de projet ne sera plus proposé ; les options qui lui étaient réservées ne le viseront plus.',
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
      await ref.read(estimatorRepositoryProvider).deleteItem(_item!.id);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop(true);
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
    final rates = ref.watch(estimatorRatesProvider).value ?? const [];
    final projectTypes = [
      for (final item in ref.watch(estimatorItemsProvider).value ?? const <EstimatorItem>[])
        if (item.kind == EstimatorItemKind.projectType) item,
    ];

    Widget numberField(TextEditingController controller, String text, String errorKey, {String? suffix}) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _markDirty(),
      decoration: InputDecoration(labelText: text, suffixText: suffix, errorText: v?.errorFor(errorKey)),
    );

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
              tooltip: 'Chiffrer avec l\'IA',
              onPressed: _saving ? null : _suggest,
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            if (_item != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        bottomNavigationBar: SaveBar(onPressed: _save, saving: _saving),
        body: ListView(
          padding: pageInsets(context),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FormHeader(
                title: switch ((_isFeature, _item == null)) {
                  (true, true) => 'Nouvelle option',
                  (true, false) => 'Modifier l\'option',
                  (false, true) => 'Nouveau type de projet',
                  (false, false) => 'Modifier le type de projet',
                },
                subtitle: _item == null ? 'Astuce : ✦ en haut chiffre l\'élément avec l\'IA.' : null,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            if (_aiReasoning != null) ...[
              SurfaceCard(
                radius: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_aiReasoning!, style: muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            FormSection(
              title: 'Description',
              hasError: ['name.fr', 'name.en', 'description.fr', 'description.en'].any((k) => v?.errorFor(k) != null),
              children: [
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
                TranslatedField(
                  label: 'Description',
                  value: _description,
                  maxLines: 3,
                  maxLength: 1000,
                  optional: true,
                  errorFr: v?.errorFor('description.fr'),
                  errorEn: v?.errorFor('description.en'),
                  onChanged: (value) {
                    setState(() => _description = value);
                    _markDirty();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              title: 'Chiffrage',
              hasError: [
                'hours_min',
                'hours_max',
                'percent',
                'pricing',
                'billing',
                'project_type_ids',
              ].any((k) => v?.errorFor(k) != null),
              children: [
                if (_isFeature)
                  SegmentedButton<EstimatorPricing>(
                    showSelectedIcon: false,
                    segments: [for (final p in EstimatorPricing.values) ButtonSegment(value: p, label: Text(p.label))],
                    selected: {_pricing},
                    onSelectionChanged: (selection) {
                      setState(() => _pricing = selection.first);
                      _markDirty();
                    },
                  )
                else ...[
                  SegmentedButton<EstimatorBilling>(
                    showSelectedIcon: false,
                    segments: [for (final b in EstimatorBilling.values) ButtonSegment(value: b, label: Text(b.label))],
                    selected: {_billing},
                    onSelectionChanged: (selection) {
                      setState(() => _billing = selection.first);
                      _markDirty();
                    },
                  ),
                  Text(
                    _billing == EstimatorBilling.fixed
                        ? 'Le visiteur voit un prix de forfait estimé.'
                        : 'Le visiteur voit des heures au taux horaire.',
                    style: muted,
                  ),
                ],
                if (_isPercent) ...[
                  numberField(_percent, 'Pourcentage des heures du projet', 'percent', suffix: '%'),
                  Text('Suit le taux horaire du type de projet choisi.', style: muted),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: numberField(_hoursMin, 'Heures min.', 'hours_min', suffix: 'h')),
                      const SizedBox(width: 10),
                      Expanded(child: numberField(_hoursMax, 'Heures max.', 'hours_max', suffix: 'h')),
                    ],
                  ),
                if (!_isPercent) Text('Hors marge pour imprévus, ajoutée par les réglages.', style: muted),
                if (_isFeature)
                  MultiSelectField(
                    label: 'Réservée aux types de projet',
                    emptyLabel: 'Aucun type de projet pour l\'instant.',
                    options: [for (final type in projectTypes) (id: type.id, label: type.name.display, color: null)],
                    selectedIds: _projectTypeIds,
                    onChanged: (ids) {
                      setState(() => _projectTypeIds = ids);
                      _markDirty();
                    },
                  ),
                if (_isFeature && _projectTypeIds.isEmpty) Text('Aucun : proposée pour tous les types.', style: muted),
              ],
            ),
            if (!_isPercent) ...[
              const SizedBox(height: 12),
              FormSection(
                title: 'Taux horaire',
                initiallyExpanded: _rateId != null || _ownRates.isNotEmpty,
                summary: _ownRates.isNotEmpty
                    ? 'Taux propres'
                    : rates.where((r) => r.id == _rateId).firstOrNull?.name.display ?? 'Taux global',
                hasError: v?.errorFor('estimator_rate_id') != null,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: rates.any((r) => r.id == _rateId) ? _rateId : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Grille tarifaire',
                      errorText: v?.errorFor('estimator_rate_id'),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(child: Text('Aucune (taux global)')),
                      for (final rate in rates) DropdownMenuItem(value: rate.id, child: Text(rate.name.display)),
                    ],
                    onChanged: (value) {
                      setState(() => _rateId = value);
                      _markDirty();
                    },
                  ),
                  HourlyRatesField(
                    label: 'Taux propres (facultatifs)',
                    emptyHint: 'Prioritaires sur la grille puis sur le taux global.',
                    value: _ownRates,
                    errorFor: (currency) => v?.errorFor('hourly_rates.$currency'),
                    onChanged: (value) {
                      _ownRates = value;
                      _markDirty();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FormSection(
              title: 'Affichage',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Proposé au visiteur'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() => _isActive = value);
                    _markDirty();
                  },
                ),
                numberField(_sortOrder, 'Ordre d\'affichage', 'sort_order'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nom et précisions de l'élément à chiffrer ; renvoie la proposition de l'IA.
class _SuggestSheet extends ConsumerStatefulWidget {
  const _SuggestSheet({required this.kind, required this.initialName});

  final EstimatorItemKind kind;
  final String initialName;

  @override
  ConsumerState<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends ConsumerState<_SuggestSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _notes = TextEditingController();
  bool _generating = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final suggestion = await ref
          .read(estimatorRepositoryProvider)
          .suggestItem(kind: widget.kind, name: _name.text, notes: _notes.text);
      if (mounted) {
        Navigator.of(context).pop(suggestion);
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
              Text('Chiffrer avec l\'IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'L\'IA propose le nom dans les deux langues, une description et les heures, '
                'en tenant compte du reste de la grille. Rien n\'est enregistré avant que tu valides.',
                style: muted,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_generating,
                maxLength: 255,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: widget.kind == EstimatorItemKind.feature ? 'Option' : 'Type de projet',
                  hintText: widget.kind == EstimatorItemKind.feature ? 'Paiement en ligne' : 'Site vitrine',
                ),
              ),
              TextField(
                controller: _notes,
                enabled: !_generating,
                minLines: 3,
                maxLines: 8,
                maxLength: 3000,
                decoration: const InputDecoration(labelText: 'Précisions (facultatif)', alignLabelWithHint: true),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              if (_generating) ...[const LinearProgressIndicator(), const SizedBox(height: 16)],
              FilledButton.icon(
                onPressed: _generating || _name.text.trim().isEmpty ? null : _generate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating ? 'Chiffrage…' : 'Chiffrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
