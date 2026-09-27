import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import 'testimonial.dart';

final testimonialRepositoryProvider = Provider<TestimonialRepository>(
  (ref) => TestimonialRepository(ref.watch(apiClientProvider)),
);

/// `GET|PUT|DELETE /v1/testimonials` — pas de création (§4.2).
///
/// Un seul endpoint `PUT` sert à la fois à la modération (statut, à la une,
/// projet lié) et à la correction du texte : tout part dans la même requête.
class TestimonialRepository {
  const TestimonialRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Testimonial>> list({
    required int page,
    String search = '',
    String? status,
    bool? isFeatured,
  }) async {
    final json = await _api.get(
      '/v1/testimonials',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status, 'is_featured': isFeatured},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Testimonial.fromJson(item));
  }

  Future<Testimonial> get(int id) async =>
      Testimonial.fromJson(await _api.get('/v1/testimonials/$id') as Map<String, dynamic>);

  /// Modération rapide : seul le statut change (glisser pour approuver/rejeter).
  Future<Testimonial> updateStatus(int id, TestimonialStatus status) =>
      _update(id, {'status': status.wireValue});

  /// Bascule « à la une ». 3 au maximum : l'API refuse le 4ᵉ en 422 sur `is_featured`.
  Future<Testimonial> updateFeatured(int id, {required TestimonialStatus status, required bool isFeatured}) =>
      _update(id, {'status': status.wireValue, 'is_featured': isFeatured});

  /// Correction du texte (auteur, rôle, contenu) en même temps que la modération.
  Future<Testimonial> updateContent(
    int id, {
    required TestimonialStatus status,
    required bool isFeatured,
    required String authorName,
    required String? authorRole,
    required Translated content,
  }) =>
      _update(id, {
        'status': status.wireValue,
        'is_featured': isFeatured,
        'author_name': authorName,
        'author_role': authorRole,
        'content': content.toJson(),
      });

  Future<Testimonial> _update(int id, Map<String, Object?> data) async {
    try {
      return Testimonial.fromJson(await _api.put('/v1/testimonials/$id', data: data) as Map<String, dynamic>);
    } on ValidationException catch (e) {
      if (e.errorFor('is_featured') != null) {
        throw ValidationException(
          'Trois avis au maximum peuvent être à la une : retirez-en un d\'abord.',
          e.errors,
        );
      }
      rethrow;
    }
  }

  Future<void> delete(int id) => _api.delete('/v1/testimonials/$id');
}
