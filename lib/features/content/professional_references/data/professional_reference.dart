import 'package:flutter/foundation.dart';

import '../../data/refs.dart';

/// Champs affichables sur le CV (§3.6).
enum VisibleField {
  name('name', 'Nom'),
  role('role', 'Rôle'),
  company('company', 'Société'),
  email('email', 'Email'),
  phone('phone', 'Téléphone'),
  relationship('relationship', 'Relation');

  const VisibleField(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

@immutable
class ProfessionalReference {
  const ProfessionalReference({
    required this.id,
    required this.name,
    required this.role,
    required this.company,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.project,
    required this.projectId,
    required this.isPublic,
    required this.visibleFields,
    required this.notes,
  });

  factory ProfessionalReference.fromJson(Map<String, dynamic> json) => ProfessionalReference(
        id: json['id'] as int,
        name: json['name'] as String,
        role: json['role'] as String?,
        company: json['company'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        relationship: json['relationship'] as String?,
        project: json['project'] == null ? null : ProjectLiteRef.fromJson(json['project'] as Map<String, dynamic>),
        projectId: json['project_id'] as int?,
        isPublic: json['is_public'] as bool? ?? false,
        visibleFields: [for (final f in (json['visible_fields'] as List<dynamic>? ?? const [])) f as String],
        notes: json['notes'] as String?,
      );

  final int id;
  final String name;
  final String? role;
  final String? company;
  final String? email;
  final String? phone;
  final String? relationship;
  final ProjectLiteRef? project;
  final int? projectId;

  /// Jointe au CV si `true` (§4.3).
  final bool isPublic;
  final List<String> visibleFields;

  /// Privées : jamais affichées publiquement.
  final String? notes;
}
