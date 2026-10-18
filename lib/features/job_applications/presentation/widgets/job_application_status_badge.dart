import 'package:flutter/material.dart';

import '../../../../shared/widgets/ai_badge.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../data/job_application.dart';

/// Statut d'une candidature, avec le badge IA d'un brouillon préparé par l'IA.
/// Une page en ligne dont la date est passée s'affiche « Expirée ».
class JobApplicationStatusBadge extends StatelessWidget {
  const JobApplicationStatusBadge(this.application, {super.key});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    return StatusWithAiBadge(
      draftedBy: application.draftedBy,
      isDraft: application.status == JobApplicationStatus.draft,
      status: application.isExpired
          ? const StatusBadge.tone('Expirée', StatusTone.danger)
          : TypedStatusBadge(
              type: 'job_application',
              status: application.status.wireValue,
              label: application.status.label,
            ),
    );
  }
}
