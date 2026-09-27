import 'package:flutter/material.dart';

import '../../core/models/translated.dart';

/// Champ de texte bilingue avec bascule FR | EN (§5 : « chaque texte traduit
/// s'édite avec une bascule »). Affiche un point d'avertissement sur l'onglet
/// dont le texte est vide ou en erreur.
class TranslatedField extends StatefulWidget {
  const TranslatedField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorFr,
    this.errorEn,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final Translated value;
  final ValueChanged<Translated> onChanged;
  final String? errorFr;
  final String? errorEn;
  final int maxLines;
  final int? maxLength;

  @override
  State<TranslatedField> createState() => _TranslatedFieldState();
}

class _TranslatedFieldState extends State<TranslatedField> {
  var _locale = 'fr';
  late final _controllers = {
    'fr': TextEditingController(text: widget.value.fr),
    'en': TextEditingController(text: widget.value.en),
  };

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _locale == 'en' ? widget.errorEn : widget.errorFr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: theme.textTheme.labelLarge),
            const Spacer(),
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
