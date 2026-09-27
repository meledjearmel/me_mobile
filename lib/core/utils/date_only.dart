/// Dates simples `YYYY-MM-DD` (§3.6), sans horodatage.
String formatDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? parseDateOnly(String? value) => value == null || value.isEmpty ? null : DateTime.tryParse(value);
