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

/// Ce dont parle l'avis demandé : un projet, une expérience ou une formation.
@immutable
class ReviewInvitationSubject {
  const ReviewInvitationSubject({required this.type, required this.id, required this.label, this.slug});

  factory ReviewInvitationSubject.fromJson(Map<String, dynamic> json) => ReviewInvitationSubject(
    type: json['type'] as String? ?? 'project',
    id: json['id'] as int,
    label: json['label'] as String? ?? '',
    slug: json['slug'] as String?,
  );

  /// `project`, `experience` ou `education`.
  final String type;
  final int id;

  /// En français.
  final String label;
  final String? slug;
}

/// Demande d'avis : lien personnel à usage unique, prérempli, ou lien
/// collectif partageable à toute une équipe.
@immutable
class ReviewInvitation {
  const ReviewInvitation({
    required this.id,
    required this.name,
    required this.email,
    required this.locale,
    required this.url,
    required this.status,
    required this.subject,
    required this.note,
    required this.expiresAt,
    required this.usedAt,
    required this.createdAt,
    this.collective = false,
    this.maxUses,
    this.usesCount = 0,
    this.subjects = const [],
    this.testimonialIds = const [],
  });

  factory ReviewInvitation.fromJson(Map<String, dynamic> json) {
    final testimonialIds = [
      for (final id in json['testimonial_ids'] as List<dynamic>? ?? const []) if (id is int) id,
    ];
    // Ancienne réponse : seul `testimonial_id` (déprécié).
    final legacyTestimonialId = json['testimonial_id'] as int?;
    return ReviewInvitation(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      locale: json['locale'] as String? ?? 'fr',
      url: json['url'] as String,
      status: ReviewInvitationStatus.fromWire(json['status'] as String?),
      subject: json['subject'] as String?,
      note: json['note'] as String?,
      expiresAt: _date(json['expires_at']),
      usedAt: _date(json['used_at']),
      createdAt: _date(json['created_at']),
      collective: json['collective'] as bool? ?? false,
      maxUses: json['max_uses'] as int?,
      usesCount: json['uses_count'] as int? ?? testimonialIds.length,
      subjects: [
        for (final item in json['subjects'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>) ReviewInvitationSubject.fromJson(item),
      ],
      testimonialIds: testimonialIds.isEmpty && legacyTestimonialId != null ? [legacyTestimonialId] : testimonialIds,
    );
  }

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value as String)?.toLocal();

  final int id;

  /// Toujours `null` pour un lien collectif (pas de préremplissage).
  final String? name;
  final String? email;

  /// Langue du lien et du formulaire : `fr` ou `en`.
  final String locale;

  /// Le lien à envoyer.
  final String url;
  final ReviewInvitationStatus status;

  /// Rattachements en une ligne, en français ; `null` pour un avis général.
  final String? subject;

  /// Mémo visible seulement dans l'admin.
  final String? note;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  /// Lien partageable : plusieurs personnes peuvent laisser leur avis.
  final bool collective;

  /// Nombre d'avis au plus (1 pour un lien personnel) ; `null` = sans limite.
  final int? maxUses;
  final int usesCount;
  final List<ReviewInvitationSubject> subjects;

  /// Avis reçus par ce lien.
  final List<int> testimonialIds;

  /// « Lien collectif » ; sinon nom, e-mail, ou « Lien anonyme ».
  String get displayName => collective
      ? 'Lien collectif'
      : name?.isNotEmpty == true
      ? name!
      : email?.isNotEmpty == true
      ? email!
      : 'Lien anonyme';

  /// « 3 / 10 avis », « 3 avis » sans limite.
  String get usesLabel {
    final count = '$usesCount${maxUses == null ? '' : ' / $maxUses'}';
    return '$count avis';
  }
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
  /// sans [expiresAt], le lien n'expire pas. Un lien [collective] ignore
  /// [name] et [email] ; [maxUses] (2 à 1000, `null` = sans limite) ne vaut
  /// que pour lui.
  Future<ReviewInvitation> create({
    required String locale,
    String? name,
    String? email,
    bool collective = false,
    int? maxUses,
    List<int> projectIds = const [],
    List<int> experienceIds = const [],
    List<int> educationIds = const [],
    String? note,
    DateTime? expiresAt,
  }) async => ReviewInvitation.fromJson(
    await _api.post(
      '/v1/review-invitations',
      data: {
        'locale': locale,
        'collective': collective,
        if (collective) 'max_uses': maxUses else ...{'name': name, 'email': email},
        'project_ids': projectIds,
        'experience_ids': experienceIds,
        'education_ids': educationIds,
        'note': note,
        'expires_at': expiresAt == null ? null : DateFormat('yyyy-MM-dd').format(expiresAt),
      },
    ) as Map<String, dynamic>,
  );

  /// Le lien cesse de fonctionner ; un avis déjà reçu reste en place.
  Future<void> delete(int id) => _api.delete('/v1/review-invitations/$id');
}
