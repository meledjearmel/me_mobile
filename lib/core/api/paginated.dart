/// Liste paginée Laravel : `{ data: [...], links: {...}, meta: {...} }`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory Paginated.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromItem) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return Paginated(
      items: [for (final item in json['data'] as List<dynamic>) fromItem(item as Map<String, dynamic>)],
      currentPage: meta['current_page'] as int? ?? 1,
      lastPage: meta['last_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? 25,
      total: meta['total'] as int? ?? 0,
    );
  }

  /// Seules valeurs acceptées par l'API ; toute autre retombe à 10.
  static const perPageOptions = [10, 25, 50];

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
