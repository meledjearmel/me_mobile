import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_assist_repository.dart';
import '../../core/ai/text_tone.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/translated.dart';

/// Champ de texte bilingue avec bascule FR | EN (§5 : « chaque texte traduit
/// s'édite avec une bascule »). Affiche un point d'avertissement sur l'onglet
/// dont le texte est vide ou en erreur.
///
/// Propose aussi une assistance IA (traduire vers l'autre langue, ou
/// réécrire le texte de la langue affichée) : le résultat est toujours
/// montré en aperçu avant d'être appliqué, jamais substitué en silence.
class TranslatedField extends ConsumerStatefulWidget {
  const TranslatedField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorFr,
    this.errorEn,
    this.maxLines = 1,
    this.maxLength,
    this.generate,
  });

  final String label;
  final Translated value;
  final ValueChanged<Translated> onChanged;
  final String? errorFr;
  final String? errorEn;
  final int maxLines;
  final int? maxLength;

  /// Génère le texte dans les deux langues (ex. description d'une technologie).
  /// Quand il est fourni, « Générer » remplace « Améliorer » dans le menu IA et
  /// reste disponible sur un champ vide.
  final Future<Translated> Function()? generate;

  @override
  ConsumerState<TranslatedField> createState() => _TranslatedFieldState();
}

enum _AiAction { translate, improve, generate }

class _TranslatedFieldState extends ConsumerState<TranslatedField> {
  var _locale = 'fr';
  late final _controllers = {
    'fr': TextEditingController(text: widget.value.fr),
    'en': TextEditingController(text: widget.value.en),
  };
  bool _assisting = false;

  String get _otherLocale => _locale == 'fr' ? 'en' : 'fr';

  @override
  void didUpdateWidget(TranslatedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resynchronise si la valeur change depuis l'extérieur (ex. rechargement du formulaire).
    for (final locale in Translated.locales) {
      final text = widget.value[locale];
      if (_controllers[locale]!.text != text) {
        _controllers[locale]!.text = text;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _hasWarning(String locale) {
    final error = locale == 'en' ? widget.errorEn : widget.errorFr;
    return error != null || widget.value[locale].trim().isEmpty;
  }

  Future<void> _openAiMenu() async {
    final hasText = widget.value[_locale].trim().isNotEmpty;
    final canGenerate = widget.generate != null;
    final action = await showModalBottomSheet<_AiAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              enabled: hasText,
              leading: const Icon(Icons.translate_rounded),
              title: Text('Traduire vers ${_otherLocale.toUpperCase()}'),
              subtitle: Text('Remplit ${_otherLocale.toUpperCase()} depuis ${_locale.toUpperCase()}'),
              onTap: () => Navigator.pop(context, _AiAction.translate),
            ),
            if (canGenerate)
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Générer (FR + EN)'),
                subtitle: const Text('Rédige le texte en français puis le traduit en anglais'),
                onTap: () => Navigator.pop(context, _AiAction.generate),
              )
            else
              ListTile(
                enabled: hasText,
                leading: const Icon(Icons.auto_fix_high_rounded),
                title: Text('Améliorer le texte (${_locale.toUpperCase()})'),
                subtitle: const Text('Réécrit dans la même langue, avec un ton au choix'),
                onTap: () => Navigator.pop(context, _AiAction.improve),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _AiAction.translate:
        await _translate();
      case _AiAction.improve:
        await _improve();
      case _AiAction.generate:
        await _generate();
    }
  }

  Future<void> _generate() async {
    setState(() => _assisting = true);
    try {
      final result = await widget.generate!();
      if (!mounted) {
        return;
      }
      final accepted = await _showPreview('Texte proposé', 'FR : ${result.fr}\n\nEN : ${result.en}');
      if (accepted == true && mounted) {
        setState(() {
          _controllers['fr']!.text = result.fr;
          _controllers['en']!.text = result.en;
        });
        widget.onChanged(result);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _assisting = false);
      }
    }
  }

  Future<void> _translate() async {
    final source = widget.value[_locale];
    final target = _otherLocale;
    setState(() => _assisting = true);
    try {
      final result = await ref.read(aiAssistRepositoryProvider).translate(
            text: source,
            sourceLocale: _locale,
            targetLocale: target,
          );
      if (!mounted) {
        return;
      }
      final accepted = await _showPreview('Traduction proposée (${target.toUpperCase()})', result);
      if (accepted == true && mounted) {
        setState(() {
          _controllers[target]!.text = result;
          _locale = target;
        });
        widget.onChanged(widget.value.withLocale(target, result));
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _assisting = false);
      }
    }
  }

  Future<void> _improve() async {
    final options = await showModalBottomSheet<_ImproveOptions>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ImproveOptionsSheet(),
    );
    if (options == null || !mounted) {
      return;
    }

    final locale = _locale;
    setState(() => _assisting = true);
    try {
      final result = await ref.read(aiAssistRepositoryProvider).improve(
            text: widget.value[locale],
            locale: locale,
            tone: options.tone,
            instructions: options.instructions,
          );
      if (!mounted) {
        return;
      }
      final accepted = await _showPreview('Version améliorée (${locale.toUpperCase()})', result);
      if (accepted == true && mounted) {
        setState(() => _controllers[locale]!.text = result);
        widget.onChanged(widget.value.withLocale(locale, result));
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _assisting = false);
      }
    }
  }

  Future<bool?> _showPreview(String title, String text) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Utiliser')),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _locale == 'en' ? widget.errorEn : widget.errorFr;
    final canAssist = widget.generate != null || widget.value[_locale].trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: theme.textTheme.labelLarge)),
            IconButton(
              tooltip: canAssist ? 'Assistance IA' : 'Écrivez d\'abord un texte à traduire ou améliorer',
              onPressed: _assisting || !canAssist ? null : _openAiMenu,
              icon: _assisting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
            ),
            SegmentedButton<String>(
              segments: [
                for (final locale in Translated.locales)
                  ButtonSegment(
                    value: locale,
                    label: Text(locale.toUpperCase()),
                    icon: _hasWarning(locale)
                        ? Icon(Icons.circle, size: 8, color: theme.colorScheme.error)
                        : null,
                  ),
              ],
              selected: {_locale},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() => _locale = selection.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final locale in Translated.locales)
          Offstage(
            offstage: locale != _locale,
            child: TextField(
              controller: _controllers[locale],
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              onChanged: (text) => widget.onChanged(widget.value.withLocale(locale, text)),
              decoration: InputDecoration(
                errorText: locale == 'en' ? widget.errorEn : widget.errorFr,
                hintText: locale == 'en' ? 'English' : 'Français',
              ),
            ),
          ),
        if (error == null && widget.value[_locale].trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Vide dans cette langue.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

typedef _ImproveOptions = ({TextTone? tone, String? instructions});

class _ImproveOptionsSheet extends StatefulWidget {
  const _ImproveOptionsSheet();

  @override
  State<_ImproveOptionsSheet> createState() => _ImproveOptionsSheetState();
}

class _ImproveOptionsSheetState extends State<_ImproveOptionsSheet> {
  TextTone? _tone;
  final _instructions = TextEditingController();

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Améliorer le texte', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Ton (facultatif)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sans ton précis'),
                selected: _tone == null,
                onSelected: (_) => setState(() => _tone = null),
                showCheckmark: false,
              ),
              for (final tone in TextTone.values)
                ChoiceChip(
                  label: Text(tone.label),
                  selected: _tone == tone,
                  onSelected: (_) => setState(() => _tone = tone),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructions,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Consigne libre (facultatif)',
              hintText: 'Ex. « plus court », « pour un CV »…',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              final _ImproveOptions options = (
                tone: _tone,
                instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
              );
              Navigator.pop(context, options);
            },
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Générer'),
          ),
        ],
      ),
    );
  }
}
