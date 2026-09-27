import 'package:intl/intl.dart';

/// Dates en français : relatives dans les listes, complètes dans les détails (§5).
String relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 45) {
    return 'à l\'instant';
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours} h';
  }
  if (diff.inDays < 7) {
    return 'il y a ${diff.inDays} j';
  }
  return DateFormat('d MMM y', 'fr_FR').format(date);
}

String fullDate(DateTime date) => DateFormat('d MMMM y \'à\' HH\'h\'mm', 'fr_FR').format(date);
