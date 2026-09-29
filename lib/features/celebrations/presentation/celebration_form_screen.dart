import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/translated_field.dart';
import '../application/celebration_list_controller.dart';
import '../data/celebration_repository.dart';

/// Création ou modification d'une surprise. `id == null` : création.
class CelebrationFormScreen extends ConsumerStatefulWidget {
  const CelebrationFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<CelebrationFormScreen> createState() => _CelebrationFormScreenState();
}

class _CelebrationFormScreenState extends ConsumerState<CelebrationFormScreen> {
  late Future<void> _future = _load();

  Translated _message = const Translated();
  Translated _buttonLabel = const Translated(fr: 'Féliciter', en: 'Congratulate');
  late final _congratulatedFor = TextEditingController();
  bool _isActive = true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  late final _chancePercent = TextEditingController(text: '100');
  late final _weight = TextEditingController(text: '1');
  late final _delaySeconds = TextEditingController(text: '5');
  late final _displaySeconds = TextEditingController(text: '15');
  late final _snoozeDays = TextEditingController(text: '7');
  int _congratulationsCount = 0;

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
    final celebration = await ref.read(celebrationRepositoryProvider).get(widget.id!);
    _message = celebration.message;
    _buttonLabel = celebration.buttonLabel;
    _congratulatedFor.text = celebration.congratulatedFor;
    _isActive = celebration.isActive;
    _startsAt = celebration.startsAt;
    _endsAt = celebration.endsAt;
    _chancePercent.text = '${celebration.chancePercent}';
    _weight.text = '${celebration.weight}';
    _delaySeconds.text = '${celebration.delaySeconds}';
    _displaySeconds.text = '${celebration.displaySeconds}';
    _snoozeDays.text = '${celebration.snoozeDays}';
    _congratulationsCount = celebration.congratulationsCount;
  }

  @override
  void dispose() {
    _congratulatedFor.dispose();
    _chancePercent.dispose();
    _weight.dispose();
    _delaySeconds.dispose();
    _displaySeconds.dispose();
    _snoozeDays.dispose();
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

  int _int(TextEditingController controller, int fallback) => int.tryParse(controller.text.trim()) ?? fallback;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(celebrationRepositoryProvider)
          .save(
            id: widget.id,
            message: _message,
            buttonLabel: _buttonLabel,
            congratulatedFor: _congratulatedFor.text.trim(),
            isActive: _isActive,
            startsAt: _startsAt,
            endsAt: _endsAt,
            weight: _int(_weight, 1),
            chancePercent: _int(_chancePercent, 100),
            delaySeconds: _int(_delaySeconds, 0),
            displaySeconds: _int(_displaySeconds, 15),
            snoozeDays: _int(_snoozeDays, 7),
          );
      ref.invalidate(celebrationListProvider);
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
        title: const Text('Supprimer cette surprise ?'),
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
      await ref.read(celebrationRepositoryProvider).delete(widget.id!);
      ref.read(celebrationListProvider.notifier).removeItem((c) => c.id == widget.id);
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

  Widget _numberField(TextEditingController controller, String label, String field, {String? suffix, String? helper}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _markDirty(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        helperMaxLines: 2,
        errorText: _validation?.errorFor(field),
      ),
    );
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
                  child: FormHeader(
                    title: _isEditing ? 'Modifier la surprise' : 'Nouvelle surprise',
                    subtitle: _isEditing
                        ? '$_congratulationsCount félicitation${_congratulationsCount > 1 ? 's' : ''} reçue'
                              '${_congratulationsCount > 1 ? 's' : ''}'
                        : 'Une bonne nouvelle qu\'Armi annonce aux visiteurs.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                FormSection(
                  title: 'Message',
                  hasError:
                      v != null &&
                      [
                        'message.fr',
                        'message.en',
                        'button_label.fr',
                        'button_label.en',
                        'congratulated_for',
                      ].any((field) => v.errorFor(field) != null),
                  children: [
                    TranslatedField(
                      label: 'Message d\'Armi',
                      value: _message,
                      maxLines: 3,
                      maxLength: 280,
                      errorFr: v?.errorFor('message.fr'),
                      errorEn: v?.errorFor('message.en'),
                      onChanged: (value) {
                        setState(() => _message = value);
                        _markDirty();
                      },
                    ),
                    TranslatedField(
                      label: 'Libellé du bouton',
                      value: _buttonLabel,
                      maxLength: 40,
                      errorFr: v?.errorFor('button_label.fr'),
                      errorEn: v?.errorFor('button_label.en'),
                      onChanged: (value) {
                        setState(() => _buttonLabel = value);
                        _markDirty();
                      },
                    ),
                    TextField(
                      controller: _congratulatedFor,
                      maxLength: 150,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Ce qui est célébré',
                        hintText: 'ta certification AWS',
                        helperText: 'Pour la notification : « On te félicite pour … »',
                        helperMaxLines: 2,
                        errorText: v?.errorFor('congratulated_for'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Diffusion',
                  hasError: v != null && ['starts_at', 'ends_at'].any((field) => v.errorFor(field) != null),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                        _markDirty();
                      },
                    ),
                    DateField(
                      label: 'Début',
                      value: _startsAt,
                      allowClear: true,
                      emptyLabel: 'Dès maintenant',
                      error: v?.errorFor('starts_at'),
                      onChanged: (value) {
                        setState(() => _startsAt = value);
                        _markDirty();
                      },
                    ),
                    DateField(
                      label: 'Fin (incluse)',
                      value: _endsAt,
                      allowClear: true,
                      emptyLabel: 'Sans fin',
                      firstDate: _startsAt,
                      error: v?.errorFor('ends_at'),
                      onChanged: (value) {
                        setState(() => _endsAt = value);
                        _markDirty();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Apparition',
                  hasError:
                      v != null &&
                      [
                        'chance_percent',
                        'weight',
                        'delay_seconds',
                        'display_seconds',
                        'snooze_days',
                      ].any((field) => v.errorFor(field) != null),
                  children: [
                    _numberField(
                      _chancePercent,
                      'Chance d\'apparition',
                      'chance_percent',
                      suffix: '%',
                      helper: 'Part des visites qui la voient, une fois par session au plus (1 à 100).',
                    ),
                    _numberField(
                      _weight,
                      'Poids',
                      'weight',
                      helper: 'Priorité face aux autres surprises en ligne (1 à 100).',
                    ),
                    _numberField(
                      _delaySeconds,
                      'Délai avant apparition',
                      'delay_seconds',
                      suffix: 's',
                      helper: '0 à 600 secondes.',
                    ),
                    _numberField(
                      _displaySeconds,
                      'Durée d\'affichage',
                      'display_seconds',
                      suffix: 's',
                      helper: 'Sans interaction, la bulle repart après ce délai (5 à 120 s).',
                    ),
                    _numberField(
                      _snoozeDays,
                      'Pause après fermeture',
                      'snooze_days',
                      suffix: 'j',
                      helper:
                          'Un visiteur qui la ferme ne la revoit pas pendant ces jours (0 = dès la session suivante).',
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
