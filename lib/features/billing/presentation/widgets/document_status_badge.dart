import 'package:flutter/material.dart';

import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../data/commercial_document.dart';

/// Statut d'un document, toujours affiché, suivi d'un badge rouge « En retard »
/// ou « À relancer » quand il s'applique.
class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge(this.document, {super.key});

  final CommercialDocument document;

  @override
  Widget build(BuildContext context) {
    final alert = document.isOverdue
        ? 'En retard'
        : document.hasReminder
        ? 'À relancer'
        : null;
    final label = document.status == DocumentStatus.issued && document.sentAt != null
        ? 'Envoyé'
        : document.status.label;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        TypedStatusBadge(type: 'commercial_document', status: document.status.wireValue, label: label),
        if (alert != null) StatusBadge.tone(alert, StatusTone.danger),
      ],
    );
  }
}
