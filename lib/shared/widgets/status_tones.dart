import 'package:flutter/widgets.dart';

import 'status_badge.dart';
import 'status_sheet.dart';

/// Rendu du badge de [status] pour un [type] de l'API `PATCH /v1/status` :
/// la même table pour toutes les listes, pour qu'un statut ait partout la
/// même allure.
StatusTone statusTone(String type, String status) => switch ((type, status)) {
  // Contenus : brouillon, publié, archivé (projets).
  (_, 'draft') when type != 'job_application' && type != 'commercial_document' => StatusTone.secondary,
  (_, 'published') => StatusTone.filled,
  (_, 'archived') when type == 'project' => StatusTone.outline,
  // Boîte de réception.
  ('contact', 'new') || ('engagement', 'new') => StatusTone.filled,
  ('contact', 'read') => StatusTone.secondary,
  ('contact', 'replied') || ('engagement', 'handled') => StatusTone.outline,
  ('comment' || 'testimonial', 'pending') => StatusTone.secondary,
  ('comment' || 'testimonial', 'approved') => StatusTone.filled,
  ('comment' || 'testimonial', 'rejected') => StatusTone.danger,
  ('appointment', 'pending') => StatusTone.filled,
  ('appointment', 'confirmed') => StatusTone.secondary,
  ('appointment', 'declined' || 'cancelled') => StatusTone.outline,
  // Candidatures.
  ('job_application', 'active') => StatusTone.filled,
  ('job_application', _) => StatusTone.secondary,
  // Propositions freelance : entretien et mission obtenue en avant.
  ('proposal', 'interview' || 'hired') => StatusTone.filled,
  ('proposal', 'declined') => StatusTone.outline,
  ('proposal', _) => StatusTone.secondary,
  // Devis et factures.
  ('commercial_document', 'draft' || 'cancelled') => StatusTone.outline,
  ('commercial_document', 'issued') => StatusTone.secondary,
  ('commercial_document', 'accepted' || 'paid') => StatusTone.filled,
  ('commercial_document', 'declined') => StatusTone.danger,
  // Révisions proposées.
  ('revision', 'pending') => StatusTone.filled,
  ('revision', 'applied') => StatusTone.secondary,
  ('revision', 'rejected') => StatusTone.outline,
  // Interrupteurs : estimateur, types de rendez-vous, surprises.
  (_, 'active') => StatusTone.filled,
  (_, 'hidden') => StatusTone.secondary,
  _ => StatusTone.secondary,
};

/// Types qui ne sont qu'un interrupteur `active` / `hidden`, avec leurs libellés.
const toggleStatusOptions = <String, List<StatusOption>>{
  'estimator_item': [(value: 'active', label: 'Proposé'), (value: 'hidden', label: 'Masqué')],
  'appointment_type': [(value: 'active', label: 'Proposé'), (value: 'hidden', label: 'Masqué')],
  'celebration': [(value: 'active', label: 'Active'), (value: 'hidden', label: 'Inactive')],
};

/// Valeur `active` / `hidden` d'un interrupteur.
String toggleStatus(bool isActive) => isActive ? 'active' : 'hidden';

/// Badge de statut d'une ligne de liste, rendu d'après [statusTone].
class TypedStatusBadge extends StatelessWidget {
  const TypedStatusBadge({super.key, required this.type, required this.status, required this.label, this.tone});

  final String type;
  final String status;
  final String label;

  /// Remplace le rendu de la table (ex. article programmé : contour).
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) => StatusBadge.tone(label, tone ?? statusTone(type, status));
}
