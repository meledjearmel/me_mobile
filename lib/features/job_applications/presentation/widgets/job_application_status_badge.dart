import 'package:flutter/material.dart';

import '../../../../shared/widgets/ai_badge.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/job_application.dart';

/// Statut d'une candidature, avec le badge IA d'un brouillon préparé par l'IA.
/// Une page en ligne dont la date est passée s'affiche « Expirée ».
class JobApplicationStatusBadge extends StatelessWidget {
  const JobApplicationStatusBadge(this.application, {super.key});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = application.isExpired
        ? StatusBadge('Expirée', color: scheme.error)
        : switch (application.status) {
            JobApplicationStatus.draft => StatusBadge(application.status.label, prominent: true),
            JobApplicationStatus.active => StatusBadge(application.status.label, color: scheme.primary),
            JobApplicationStatus.archived => StatusBadge(application.status.label),
          };
    return StatusWithAiBadge(
      draftedBy: application.draftedBy,
      isDraft: application.status == JobApplicationStatus.draft,
      status: status,
    );
  }
}
