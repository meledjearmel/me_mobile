import 'package:flutter/foundation.dart';

/// Recherche texte + filtres par égalité communs à tous les `index` (§3.3).
@immutable
class ListQuery {
  const ListQuery({this.search = '', this.filters = const {}});

  final String search;

  /// Une valeur vide est ignorée côté [ApiClient] : pas besoin de la retirer ici.
  final Map<String, Object?> filters;

  ListQuery copyWith({String? search, Map<String, Object?>? filters}) =>
      ListQuery(search: search ?? this.search, filters: filters ?? this.filters);

  @override
  bool operator ==(Object other) =>
      other is ListQuery && other.search == search && mapEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(search, Object.hashAllUnordered(filters.entries));
}
