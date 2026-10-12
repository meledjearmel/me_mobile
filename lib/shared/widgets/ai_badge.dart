import 'package:flutter/material.dart';

import 'status_badge.dart';

/// Badge « IA · Claude Code » d'un brouillon rédigé par un client IA. Rien
/// tant que le contenu n'est pas un brouillon ou n'a pas été rédigé par l'IA.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key, required this.draftedBy, required this.isDraft});

  final String? draftedBy;
  final bool isDraft;

  /// Le badge s'affiche-t-il ?
  static bool shows(String? draftedBy, bool isDraft) => isDraft && (draftedBy?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!shows(draftedBy, isDraft)) {
      return const SizedBox.shrink();
    }
    return StatusBadge('IA · ${draftedBy!.trim()}', color: Theme.of(context).colorScheme.tertiary);
  }
}

/// Statut d'une ligne de liste : badge IA éventuel suivi du badge de statut.
class StatusWithAiBadge extends StatelessWidget {
  const StatusWithAiBadge({super.key, required this.draftedBy, required this.isDraft, this.status});

  final String? draftedBy;
  final bool isDraft;

  /// Badge de statut ; `null` : aucun (le badge IA seul, s'il s'affiche).
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final ai = AiBadge.shows(draftedBy, isDraft);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ai) AiBadge(draftedBy: draftedBy, isDraft: isDraft),
        if (ai && status != null) const SizedBox(width: 6),
        ?status,
      ],
    );
  }
}
