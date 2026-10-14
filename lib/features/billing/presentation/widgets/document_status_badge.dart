import 'package:flutter/material.dart';

import '../../../../shared/widgets/status_badge.dart';
import '../../data/commercial_document.dart';

/// Statut d'un document ; « En retard » ou « À relancer » prennent le dessus
/// quand ils s'appliquent.
class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge(this.document, {super.key});

  final CommercialDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (document.isOverdue) {
      return StatusBadge('En retard', color: scheme.error);
    }
    if (document.hasReminder) {
      return StatusBadge('À relancer', color: scheme.tertiary);
    }
    return switch (document.status) {
      DocumentStatus.draft => StatusBadge(document.status.label, prominent: true),
      DocumentStatus.accepted || DocumentStatus.paid => StatusBadge(document.status.label, color: scheme.primary),
      DocumentStatus.declined || DocumentStatus.cancelled => StatusBadge(document.status.label),
      DocumentStatus.issued => StatusBadge(document.sentAt == null ? 'Émis' : 'Envoyé', color: scheme.secondary),
    };
  }
}
