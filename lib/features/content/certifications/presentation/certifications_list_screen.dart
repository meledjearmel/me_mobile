import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_sheet.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../../../shared/widgets/ai_badge.dart';
import '../application/certification_list_controller.dart';
import '../data/certification.dart';
import 'certification_form_screen.dart';

class CertificationsListScreen extends ConsumerWidget {
  const CertificationsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => CertificationFormScreen(id: id)));
    ref.invalidate(certificationListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(certificationListProvider);
    final notifier = ref.read(certificationListProvider.notifier);
    final currentKind = state.value?.query.filters['kind'] as String?;
    final isDraftFilter = state.value?.query.filters['status'] == 'draft';

    return ResourceListScaffold<Certification>(
      title: 'Certifications',
      searchHint: 'Nom, organisme…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(certificationListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.workspace_premium_outlined,
      emptyTitle: 'Aucune certification pour l\'instant',
      emptyDescription: 'Ajoutez une certification ou une formation courte avec le bouton +.',
      filterChips: [
        for (final kind in CertificationKind.values)
          ChoiceChip(
            label: Text(kind == CertificationKind.course ? 'Formations' : 'Certifications'),
            selected: currentKind == kind.wireValue,
            onSelected: (_) => notifier.setFilters(currentKind == kind.wireValue ? const {} : {'kind': kind.wireValue}),
            showCheckmark: false,
          ),
        ChoiceChip(
          label: const Text('Brouillon'),
          selected: isDraftFilter,
          onSelected: (_) => notifier.setFilters(isDraftFilter ? const {} : const {'status': 'draft'}),
          showCheckmark: false,
        ),
      ],
      itemBuilder: (context, certification) => ListTile(
        onTap: () => _openForm(context, ref, id: certification.id),
        // Appui long : publier ou repasser en brouillon sans ouvrir le formulaire.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'certification',
          id: certification.id,
          title: certification.name.display,
          current: certification.status.wireValue,
          options: [for (final s in PublicationStatus.values) (value: s.wireValue, label: s.label)],
          onChanged: () => ref.invalidate(certificationListProvider),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 40,
            child: certification.badgeUrl != null
                ? Image.network(certification.badgeUrl!, fit: BoxFit.contain)
                : Icon(
                    certification.kind == CertificationKind.course
                        ? Icons.school_outlined
                        : Icons.workspace_premium_outlined,
                  ),
          ),
        ),
        title: Text(certification.name.display),
        subtitle: Text(
          '${certification.issuer} · ${DateFormat('MMM y', 'fr_FR').format(certification.issuedOn)}'
          '${certification.isExpired ? ' · expirée' : ''}',
        ),
        trailing: StatusWithAiBadge(
          draftedBy: certification.draftedBy,
          isDraft: certification.status == PublicationStatus.draft,
          status: TypedStatusBadge(
            type: 'certification',
            status: certification.status.wireValue,
            label: certification.status.label,
          ),
        ),
      ),
    );
  }
}
