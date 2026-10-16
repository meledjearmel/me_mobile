import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_sheet.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../application/appointment_list_controller.dart';
import '../../data/appointment.dart';
import 'appointment_detail_screen.dart';

/// « mar. 7 oct., 14:30 », heure locale de l'appareil.
String appointmentSlot(Appointment appointment) =>
    '${DateFormat('EEE d MMM, HH:mm', 'fr_FR').format(appointment.startsAt)} – '
    '${DateFormat('HH:mm', 'fr_FR').format(appointment.endsAt)}';

class AppointmentsTab extends ConsumerStatefulWidget {
  const AppointmentsTab({super.key, this.autoOpenId});

  final int? autoOpenId;

  @override
  ConsumerState<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<AppointmentsTab> {
  static const _statuses = [null, 'pending', 'confirmed', 'declined', 'cancelled'];

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(widget.autoOpenId!));
    }
  }

  void _openDetail(int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => AppointmentDetailScreen(id: id)));
  }

  String _statusLabel(String? status) => status == null ? 'Tous' : AppointmentStatus.fromWire(status).label;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentListProvider);
    final notifier = ref.read(appointmentListProvider.notifier);
    final filters = state.value?.query.filters ?? const {};
    final current = filters['status'] as String?;
    final currentLocation = filters['location'] as String?;

    // Statut et lieu se combinent : changer l'un garde l'autre.
    void setFilter(String key, String? value) => notifier.setFilters({...filters, key: value});

    return ResourceListView<Appointment>(
      searchHint: 'Nom, e-mail, société…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(appointmentListProvider),
      emptyIcon: Icons.event_outlined,
      emptyTitle: 'Aucun rendez-vous pour l\'instant',
      emptyDescription: 'Les demandes de rendez-vous déposées sur le site apparaîtront ici.',
      wrapInCard: false,
      filterChips: [
        for (final status in _statuses)
          PillFilterChip(
            label: _statusLabel(status),
            selected: current == status,
            onTap: () => setFilter('status', status),
          ),
        for (final location in AppointmentLocation.values)
          PillFilterChip(
            label: location.label,
            selected: currentLocation == location.wireValue,
            onTap: () => setFilter('location', currentLocation == location.wireValue ? null : location.wireValue),
          ),
      ],
      itemBuilder: (context, item) => GestureDetector(
        // Appui long : changer le statut sans ouvrir la fiche.
        onLongPress: () => showStatusSheet(
          context,
          ref,
          type: 'appointment',
          id: item.id,
          title: item.name,
          current: item.status.wireValue,
          options: [for (final s in AppointmentStatus.values) (value: s.wireValue, label: s.label)],
          onChanged: () => ref.invalidate(appointmentListProvider),
        ),
        child: _AppointmentTile(appointment: item, onTap: () => _openDetail(item.id)),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPending = appointment.status == AppointmentStatus.pending;

    return ListCardTile(
      onTap: onTap,
      leading: IconTile(appointment.location.icon),
      title: appointment.name,
      unread: isPending,
      meta: appointmentSlot(appointment),
      subtitle: [
        appointment.type?.name.display,
        appointment.location.label,
        if (appointment.company?.isNotEmpty == true) appointment.company,
      ].whereType<String>().join(' · '),
      badge: TypedStatusBadge(
        type: 'appointment',
        status: appointment.status.wireValue,
        label: appointment.status.label,
      ),
    );
  }
}
