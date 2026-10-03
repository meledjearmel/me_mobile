import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/multipart.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import 'testimonial.dart';

final testimonialRepositoryProvider = Provider<TestimonialRepository>(
  (ref) => TestimonialRepository(ref.watch(apiClientProvider)),
);

/// `GET|PUT|DELETE /v1/testimonials`, `DELETE /v1/testimonials/{id}/video`
/// — pas de création (§4.2).
///
/// Un seul endpoint `PUT` sert à la fois à la modération (statut, à la une,
/// projet lié) et à la correction du texte : tout part dans la même requête.
class TestimonialRepository {
  const TestimonialRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Testimonial>> list({required int page, String search = '', String? status, bool? isFeatured}) async {
    final json = await _api.get(
      '/v1/testimonials',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status, 'is_featured': isFeatured},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Testimonial.fromJson(item));
  }

  Future<Testimonial> get(int id) async =>
      Testimonial.fromJson(await _api.get('/v1/testimonials/$id') as Map<String, dynamic>);

  /// Modération rapide : seul le statut change (glisser pour approuver/rejeter).
  Future<Testimonial> updateStatus(int id, TestimonialStatus status) => _update(id, {'status': status.wireValue});

  /// Bascule « à la une ». 3 au maximum : l'API refuse le 4ᵉ en 422 sur `is_featured`.
  Future<Testimonial> updateFeatured(int id, {required TestimonialStatus status, required bool isFeatured}) =>
      _update(id, {'status': status.wireValue, 'is_featured': isFeatured});

  /// Correction du texte (auteur, rôle, contenu, accroche, transcription) en
  /// même temps que la modération. En multipart (`_method=PUT`, §3.4) pour
  /// pouvoir joindre une [video] de remplacement (95 Mo maximum).
  Future<Testimonial> updateContent(
    int id, {
    required TestimonialStatus status,
    required bool isFeatured,
    required String authorName,
    required String? authorRole,
    required Translated content,
    Translated highlight = const Translated(),
    Translated videoTranscript = const Translated(),
    MultipartFile? video,
    void Function(int sent, int total)? onProgress,
  }) {
    final form = buildFormData({
      'status': status.wireValue,
      'is_featured': isFeatured,
      'author_name': authorName,
      'author_role': authorRole,
      'content': content,
      'highlight': highlight,
      'video_transcript': videoTranscript,
      if (video != null) 'video': video,
    }, method: 'PUT');
    return _guardFeatured(
      () async => Testimonial.fromJson(
        await _api.upload('/v1/testimonials/$id', form, onProgress: onProgress) as Map<String, dynamic>,
      ),
    );
  }

  /// Retire la vidéo et son aperçu : l'avis redevient un avis texte.
  Future<Testimonial> deleteVideo(int id) async =>
      Testimonial.fromJson(await _api.delete('/v1/testimonials/$id/video') as Map<String, dynamic>);

  Future<Testimonial> _update(int id, Map<String, Object?> data) => _guardFeatured(
    () async => Testimonial.fromJson(await _api.put('/v1/testimonials/$id', data: data) as Map<String, dynamic>),
  );

  Future<Testimonial> _guardFeatured(Future<Testimonial> Function() request) async {
    try {
      return await request();
    } on ValidationException catch (e) {
      if (e.errorFor('is_featured') != null) {
        throw ValidationException('Trois avis au maximum peuvent être à la une : retirez-en un d\'abord.', e.errors);
      }
      rethrow;
    }
  }

  Future<void> delete(int id) => _api.delete('/v1/testimonials/$id');
}
