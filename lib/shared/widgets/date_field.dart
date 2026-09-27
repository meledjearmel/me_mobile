import 'package:flutter/material.dart';

import '../../core/utils/date_only.dart';

/// Sélecteur de date simple (`YYYY-MM-DD`, §3.6). [allowClear] affiche un
/// bouton pour revenir à « vide », utile pour `end_date` (vide = en cours).
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.firstDate,
    this.allowClear = false,
    this.emptyLabel = 'Choisir une date',
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? error;
  final DateTime? firstDate;
  final bool allowClear;
  final String emptyLabel;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: allowClear && value != null
              ? IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? emptyLabel : formatDateOnly(value!)),
      ),
    );
  }
}
