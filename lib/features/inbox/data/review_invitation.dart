import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';

enum ReviewInvitationStatus {
  pending('pending', 'Valable'),
  used('used', 'Avis reçu'),
  expired('expired', 'Expiré');

  const ReviewInvitationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ReviewInvitationStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => ReviewInvitationStatus.pending);
}

/// Demande d'avis : lien personnel à usage unique qui ouvre le formulaire
/// d'avis du site, prérempli.
@immutable
class ReviewInvitation {
  const ReviewInvitation({
    required this.id,
    required this.name,
    required this.email,
    required this.locale,
    required this.url,
    required this.status,
    required this.projectId,
    required this.experienceId,
    required this.educationId,
    required this.subject,
    required this.note,
    required this.testimonialId,
    required this.expiresAt,
    required this.usedAt,
    required this.createdAt,
  });

  factory ReviewInvitation.fromJson(Map<String, dynamic> json) => ReviewInvitation(
    id: json['id'] as int,
    name: json['name'] as String?,
    email: json['email'] as String?,
    locale: json['locale'] as String? ?? 'fr',
    url: json['url'] as String,
    status: ReviewInvitationStatus.fromWire(json['status'] as String?),
    projectId: json['project_id'] as int?,
    experienceId: json['experience_id'] as int?,
    educationId: json['education_id'] as int?,
    subject: json['subject'] as String?,
    note: json['note'] as String?,
    testimonialId: json['testimonial_id'] as int?,
    expiresAt: _date(json['expires_at']),
    usedAt: _date(json['used_at']),
    createdAt: _date(json['created_at']),
  );

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value as String)?.toLocal();

  final int id;
  final String? name;
  final String? email;

  /// Langue du lien et du formulaire : `fr` ou `en`.
  final String locale;

  /// Le lien personnel à envoyer.
  final String url;
  final ReviewInvitationStatus status;
  final int? projectId;
  final int? experienceId;
  final int? educationId;

  /// Ce dont parle l'avis, en français ; `null` pour un avis général.
  final String? subject;

  /// Mémo visible seulement dans l'admin.
  final String? note;

  /// Avis reçu par ce lien.
  final int? testimonialId;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  /// Nom, sinon e-mail, sinon « Lien anonyme ».
  String get displayName => name?.isNotEmpty == true
      ? name!
      : email?.isNotEmpty == true
      ? email!
      : 'Lien anonyme';
}

final reviewInvitationRepositoryProvider = Provider<ReviewInvitationRepository>(
  (ref) => ReviewInvitationRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST /v1/review-invitations`, `DELETE /v1/review-invitations/{id}`.
class ReviewInvitationRepository {
  const ReviewInvitationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<ReviewInvitation>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/review-invitations',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => ReviewInvitation.fromJson(item));
  }

  /// Seule la langue est obligatoire ; sans rattachement, l'avis est général,
  /// sans [expiresAt], le lien n'expire pas.
  Future<ReviewInvitation> create({
    required String locale,
    String? name,
    String? email,
    int? projectId,
    int? experienceId,
    int? educationId,
    String? note,
    DateTime? expiresAt,
  }) async => ReviewInvitation.fromJson(
    await _api.post(
      '/v1/review-invitations',
      data: {
        'locale': locale,
        'name': name,
        'email': email,
        'project_id': projectId,
        'experience_id': experienceId,
        'education_id': educationId,
        'note': note,
        'expires_at': expiresAt == null ? null : DateFormat('yyyy-MM-dd').format(expiresAt),
      },
    ) as Map<String, dynamic>,
  );

  /// Le lien cesse de fonctionner ; un avis déjà reçu reste en place.
  Future<void> delete(int id) => _api.delete('/v1/review-invitations/$id');
}
