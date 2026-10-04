import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Mois au format `AAAA-MM` (la fiche projet n'affiche pas le jour), choisi
/// dans le calendrier, effaçable.
class MonthField extends StatelessWidget {
  const MonthField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emptyText = 'Non renseigné',
    this.errorText,
  });

  final String label;

  /// `AAAA-MM` ou `null`.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String emptyText;
  final String? errorText;

  static DateTime? _parse(String? value) => value == null ? null : DateTime.tryParse('$value-01');

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parse(value) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: label,
    );
    if (picked != null) {
      onChanged(DateFormat('yyyy-MM').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _parse(value);
    final text = date == null ? emptyText : toBeginningOfSentenceCase(DateFormat('MMMM y', 'fr_FR').format(date));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: date == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(tooltip: 'Effacer', icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null)),
        ),
        child: Text(text),
      ),
    );
  }
}
