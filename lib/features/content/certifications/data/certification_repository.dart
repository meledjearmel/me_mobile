import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/multipart.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'certification.dart';

final certificationRepositoryProvider = Provider<CertificationRepository>(
  (ref) => CertificationRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/certifications`, `DELETE …/{id}/badge`.
class CertificationRepository {
  const CertificationRepository(this._api);

  final ApiClient _api;

  static final _date = DateFormat('yyyy-MM-dd');

  Future<Paginated<Certification>> list({required int page, String search = '', String? kind, String? status}) async {
    final json = await _api.get(
      '/v1/certifications',
      query: {'page': page, 'per_page': 50, 'search': search, 'kind': kind, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Certification.fromJson(item));
  }

  Future<Certification> get(int id) async =>
      Certification.fromJson(await _api.get('/v1/certifications/$id') as Map<String, dynamic>);

  /// `id == null` : création (`POST`), sinon `_method=PUT`. Toujours en
  /// multipart, pour pouvoir joindre un [badge] (image de 2 Mo au plus).
  Future<Certification> save({
    int? id,
    required CertificationKind kind,
    required Translated name,
    required String issuer,
    required DateTime issuedOn,
    required DateTime? expiresOn,
    required String? credentialId,
    required String? credentialUrl,
    required PublicationStatus status,
    required int sortOrder,
    MultipartFile? badge,
  }) async {
    final form = buildFormData({
      'kind': kind.wireValue,
      'name': name,
      'issuer': issuer,
      'issued_on': _date.format(issuedOn),
      'expires_on': expiresOn == null ? null : _date.format(expiresOn),
      'credential_id': credentialId,
      'credential_url': credentialUrl,
      'status': status.wireValue,
      'sort_order': sortOrder,
      if (badge != null) 'badge': badge,
    }, method: id == null ? null : 'PUT');
    final json = await _api.upload(id == null ? '/v1/certifications' : '/v1/certifications/$id', form);
    return Certification.fromJson(json as Map<String, dynamic>);
  }

  Future<Certification> deleteBadge(int id) async =>
      Certification.fromJson(await _api.delete('/v1/certifications/$id/badge') as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/v1/certifications/$id');
}
