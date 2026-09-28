import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/translated.dart';
import '../../data/reference_repository.dart';
import 'technology_category.dart';

final technologyCategoryRepositoryProvider = Provider<TechnologyCategoryRepository>(
  (ref) => TechnologyCategoryRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/technology-categories`. La suppression emporte
/// (en cascade) les technologies rattachées.
class TechnologyCategoryRepository {
  const TechnologyCategoryRepository(this._api);

  final ApiClient _api;

  Future<Paginated<TechnologyCategory>> list({required int page, String search = ''}) async {
    final json = await _api.get(
      '/v1/technology-categories',
      query: {'page': page, 'per_page': 25, 'search': search},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => TechnologyCategory.fromJson(item));
  }

  Future<TechnologyCategory> get(int id) async =>
      TechnologyCategory.fromJson(await _api.get('/v1/technology-categories/$id') as Map<String, dynamic>);

  Future<TechnologyCategory> save({int? id, required String key, required Translated label, required int sortOrder}) async {
    final data = {'key': key, 'label': label.toJson(), 'sort_order': sortOrder};
    final json = id == null
        ? await _api.post('/v1/technology-categories', data: data)
        : await _api.put('/v1/technology-categories/$id', data: data);
    return TechnologyCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/technology-categories/$id');
}

/// Toutes les catégories, triées, pour le sélecteur du formulaire et les filtres de la liste.
final technologyCategoriesAllProvider = FutureProvider<List<TechnologyCategory>>((ref) async {
  final categories = await ref
      .watch(referenceListRepositoryProvider)
      .fetchAll('/v1/technology-categories', TechnologyCategory.fromJson);
  return categories..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});
