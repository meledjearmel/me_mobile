import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/estimator.dart';

/// Un taux horaire par devise (XOF, EUR, USD, CHF). Un champ vide ou à 0 :
/// pas de taux à ce niveau ([emptyHint] dit ce qui s'applique alors).
class HourlyRatesField extends StatefulWidget {
  const HourlyRatesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Taux horaire',
    this.emptyHint,
    this.errorFor,
    this.suffix = '/h',
  });

  final HourlyRates value;
  final ValueChanged<HourlyRates> onChanged;
  final String label;
  final String? emptyHint;

  /// Erreur de validation d'une devise (clé `….CHF`), s'il y en a une.
  final String? Function(String currency)? errorFor;

  /// Après chaque montant : « /h » pour un taux, vide pour un prix.
  final String suffix;

  @override
  State<HourlyRatesField> createState() => _HourlyRatesFieldState();
}

class _HourlyRatesFieldState extends State<HourlyRatesField> {
  late final _controllers = {
    for (final currency in estimatorCurrencies)
      currency: TextEditingController(text: widget.value[currency]?.toString() ?? ''),
  };

  @override
  void didUpdateWidget(HourlyRatesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resynchronise si la valeur change de l'extérieur (chargement).
    for (final currency in estimatorCurrencies) {
      final text = widget.value[currency]?.toString() ?? '';
      if (int.tryParse(_controllers[currency]!.text) != widget.value[currency]) {
        _controllers[currency]!.text = text;
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

  void _emit() {
    widget.onChanged({
      for (final currency in estimatorCurrencies)
        if ((int.tryParse(_controllers[currency]!.text) ?? 0) > 0) currency: int.parse(_controllers[currency]!.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        if (widget.emptyHint != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.emptyHint!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        // Deux devises par ligne ; Row plutôt que grille pour laisser la place aux erreurs.
        for (var i = 0; i < estimatorCurrencies.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, currency) in estimatorCurrencies.skip(i).take(2).indexed) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controllers[currency],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _emit(),
                    decoration: InputDecoration(
                      labelText: currency,
                      suffixText: widget.suffix.isEmpty ? null : widget.suffix,
                      errorText: widget.errorFor?.call(currency),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
