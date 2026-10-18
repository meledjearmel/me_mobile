import 'package:flutter/foundation.dart';

enum RevisionStatus {
  pending('pending', 'En attente'),
  applied('applied', 'Appliquées'),
  rejected('rejected', 'Rejetées');

  const RevisionStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static RevisionStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => RevisionStatus.pending);
}

/// Champ modifié par une révision, dans une langue.
@immutable
class RevisionField {
  const RevisionField({
    required this.field,
    required this.locale,
    required this.before,
    required this.after,
    required this.current,
  });

  factory RevisionField.fromJson(Map<String, dynamic> json) => RevisionField(
    field: json['field'] as String,
    locale: json['locale'] as String? ?? 'fr',
    before: json['before'],
    after: json['after'],
    current: json['current'],
  );

  final String field;

  /// `fr` ou `en`.
  final String locale;

  /// Valeurs texte ou listes, telles que renvoyées par l'API.
  final Object? before;
  final Object? after;
  final Object? current;

  /// Le contenu a changé depuis la proposition : appliquer écraserait ce changement.
  bool get changedSince => !_jsonEquals(current, before);
}

/// Image proposée par une révision : couverture (remplace l'actuelle) ou
/// image de galerie (ajoutée).
@immutable
class RevisionImage {
  const RevisionImage({required this.role, required this.url, required this.currentUrl});

  factory RevisionImage.fromJson(Map<String, dynamic> json) => RevisionImage(
    role: json['role'] as String? ?? 'gallery',
    url: json['url'] as String? ?? '',
    currentUrl: json['current_url'] as String?,
  );

  /// `cover` ou `gallery`.
  final String role;
  final String url;

  /// Image actuelle (couverture), sinon `null`.
  final String? currentUrl;

  bool get isCover => role == 'cover';
}

/// Égalité de valeurs JSON (textes, listes, objets) ; `null`, texte vide et liste vide se valent.
bool _jsonEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length && [for (var i = 0; i < a.length; i++) i].every((i) => _jsonEquals(a[i], b[i]));
  }
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _jsonEquals(a[k], b[k]));
  }
  bool blank(Object? x) => x == null || x == '' || (x is List && x.isEmpty);
  if (blank(a) && blank(b)) {
    return true;
  }
  return a == b;
}

/// Modification d'un contenu publié proposée par l'IA (`/v1/revisions`) :
/// rien ne change sur le site avant « Appliquer ».
@immutable
class Revision {
  const Revision({
    required this.id,
    required this.contentType,
    required this.contentTypeLabel,
    required this.contentId,
    required this.title,
    required this.summary,
    required this.draftedBy,
    required this.status,
    required this.createdAt,
    required this.decidedAt,
    required this.editUrl,
    this.fields = const [],
    this.image,
  });

  factory Revision.fromJson(Map<String, dynamic> json) => Revision(
    id: json['id'] as int,
    contentType: json['content_type'] as String? ?? '',
    contentTypeLabel: json['content_type_label'] as String? ?? '',
    contentId: json['content_id'] as int?,
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    draftedBy: json['drafted_by'] as String?,
    status: RevisionStatus.fromWire(json['status'] as String?),
    createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'] as String)?.toLocal(),
    decidedAt: json['decided_at'] == null ? null : DateTime.tryParse(json['decided_at'] as String)?.toLocal(),
    editUrl: json['edit_url'] as String?,
    fields: [
      for (final item in json['fields'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) RevisionField.fromJson(item),
    ],
    image: json['image'] is Map<String, dynamic> ? RevisionImage.fromJson(json['image'] as Map<String, dynamic>) : null,
  );

  final int id;
  final String contentType;

  /// Type lisible (« Projet », « Page Now »…).
  final String contentTypeLabel;
  final int? contentId;
  final String title;
  final String summary;
  final String? draftedBy;
  final RevisionStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  /// Page d'édition du back-office web.
  final String? editUrl;

  /// Vide dans la liste : seulement au détail.
  final List<RevisionField> fields;

  /// Image proposée, au détail seulement ; les champs peuvent alors être vides.
  final RevisionImage? image;
}
