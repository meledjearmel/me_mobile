import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_sheet.dart';
import '../../../shared/widgets/status_tones.dart';
import '../application/appointment_type_list_controller.dart';
import '../data/appointment_type.dart';
import 'appointment_type_form_screen.dart';

class AppointmentTypesListScreen extends ConsumerWidget {
  const AppointmentTypesListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => AppointmentTypeFormScreen(id: id)));
    ref.invalidate(appointmentTypeListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appointmentTypeListProvider);
    final notifier = ref.read(appointmentTypeListProvider.notifier);

    return ResourceListScaffold<AppointmentType>(
      title: 'Types de rendez-vous',
      searchHint: 'Nom…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(appointmentTypeListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.event_note_outlined,
      emptyTitle: 'Aucun type de rendez-vous',
      emptyDescription: 'Créez un type (ex. « Appel découverte, 30 min ») pour ouvrir la réservation.',
      itemBuilder: (context, type) => ListTile(
        onTap: () => _openForm(context, ref, id: type.id),
        // Appui long : proposer ou masquer sans ouvrir le formulaire.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'appointment_type',
          id: type.id,
          title: type.name.display,
          current: toggleStatus(type.isActive),
          options: toggleStatusOptions['appointment_type']!,
          onChanged: () => ref.invalidate(appointmentTypeListProvider),
        ),
        leading: Icon(type.locations.length == 1 ? type.locations.single.icon : Icons.event_note_outlined),
        title: Text(type.name.display),
        subtitle: Text(['${type.durationMinutes} min', type.locations.map((l) => l.label).join(', ')].join(' · ')),
        trailing: TypedStatusBadge(
          type: 'appointment_type',
          status: toggleStatus(type.isActive),
          label: type.isActive ? 'Proposé' : 'Masqué',
        ),
      ),
    );
  }
}
