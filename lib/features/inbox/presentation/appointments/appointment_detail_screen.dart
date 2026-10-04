import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../application/appointment_list_controller.dart';
import '../../data/appointment.dart';
import '../../data/appointment_repository.dart';
import 'appointments_tab.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  late Future<Appointment> _future = ref.read(appointmentRepositoryProvider).get(widget.id);
  bool _updating = false;

  void _apply(Appointment updated) {
    ref.read(appointmentListProvider.notifier).updateItem((a) => a.id == widget.id, (a) => updated);
    ref.invalidate(dashboardProvider);
    setState(() => _future = Future.value(updated));
  }

  Future<void> _run(Future<Appointment> Function() action, String done) async {
    setState(() => _updating = true);
    try {
      _apply(await action());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _confirm(Appointment appointment) async {
    final (hint, help) = switch (appointment.location) {
      AppointmentLocation.video => ('https://…', 'Vide : le lien de visio des réglages (ou un lien Jitsi unique).'),
      AppointmentLocation.phone || AppointmentLocation.whatsapp => (
        'Ex. je vous appelle au numéro indiqué',
        'Facultatif : précisions envoyées au visiteur.',
      ),
      AppointmentLocation.inPerson => ('Adresse du rendez-vous', 'Facultatif : envoyé au visiteur.'),
    };
    final details = await _askText(
      title: 'Confirmer le rendez-vous',
      label: 'Détails de la réunion',
      hint: hint,
      help: help,
      action: 'Confirmer',
    );
    if (details == null) {
      return;
    }
    await _run(
      () =>
          ref.read(appointmentRepositoryProvider).confirm(widget.id, meetingDetails: details.isEmpty ? null : details),
      'Rendez-vous confirmé : le visiteur est prévenu par e-mail.',
    );
  }

  Future<void> _decline() async {
    final reason = await _askText(
      title: 'Refuser le rendez-vous',
      label: 'Motif (facultatif)',
      hint: 'Ex. je ne suis pas disponible ce jour-là',
      help: 'Envoyé au visiteur. Le créneau est libéré.',
      action: 'Refuser',
      destructive: true,
    );
    if (reason == null) {
      return;
    }
    await _run(
      () => ref.read(appointmentRepositoryProvider).decline(widget.id, reason: reason.isEmpty ? null : reason),
      'Rendez-vous refusé.',
    );
  }

  /// `null` si annulé, sinon le texte saisi (éventuellement vide).
  Future<String?> _askText({
    required String title,
    required String label,
    required String hint,
    required String help,
    required String action,
    bool destructive = false,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: label, hintText: hint, helperText: help, helperMaxLines: 3),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _delete(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le rendez-vous de « ${appointment.name} » ?'),
        content: const Text('Il part à la corbeille : vous pourrez le restaurer si le créneau est encore libre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(appointmentRepositoryProvider).delete(appointment.id);
      ref.read(appointmentListProvider.notifier).removeItem((a) => a.id == appointment.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Appointment>(
      future: _future,
      builder: (context, snapshot) {
        final appointment = snapshot.connectionState == ConnectionState.done && !snapshot.hasError
            ? snapshot.data
            : null;
        final pending = appointment?.status == AppointmentStatus.pending;

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GlassAppBar(
            actions: [
              if (appointment != null)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(appointment),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: appointment == null
              ? null
              : BottomFade(
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: pending
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _updating ? null : _decline,
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Refuser'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _updating ? null : () => _confirm(appointment),
                                  icon: _updating
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: const Text('Confirmer'),
                                ),
                              ),
                            ],
                          )
                        : FilledButton.icon(
                            onPressed: () => launchUrl(Uri.parse('mailto:${appointment.email}')),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Contacter par e-mail'),
                          ),
                  ),
                ),
          body: switch (snapshot) {
            _ when snapshot.connectionState != ConnectionState.done => const Center(child: CircularProgressIndicator()),
            _ when snapshot.hasError => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _future = ref.read(appointmentRepositoryProvider).get(widget.id)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            _ => _AppointmentBody(appointment: appointment!),
          },
        );
      },
    );
  }
}

class _AppointmentBody extends StatelessWidget {
  const _AppointmentBody({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final details = appointment.meetingDetails;
    final detailsUri = details == null ? null : Uri.tryParse(details);
    final detailsIsLink = detailsUri != null && detailsUri.hasScheme && detailsUri.scheme.startsWith('http');

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              InitialsTile(appointment.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    SelectableText(appointment.email, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: appointment.status.label, label: 'Statut'),
            (value: appointment.location.label, label: 'Lieu'),
            if (appointment.type != null) (value: '${appointment.type!.durationMinutes} min', label: 'Durée'),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appointmentSlot(appointment), style: theme.textTheme.titleMedium),
              if (appointment.isPast) ...[
                const SizedBox(height: 2),
                Text('Rendez-vous passé', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
              const SizedBox(height: 12),
              _Field(label: 'Type', value: appointment.type?.name.display ?? 'Type supprimé'),
              _Field(label: 'Société', value: appointment.company),
              _Field(label: 'Téléphone', value: appointment.phone),
              _Field(label: 'Fuseau du visiteur', value: appointment.timezone),
              _Field(label: 'Langue', value: appointment.locale == 'en' ? 'Anglais' : 'Français'),
              if (appointment.createdAt != null)
                Text(
                  'Demandé ${relativeDate(appointment.createdAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
        if (appointment.phone?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${appointment.phone}')),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Appeler'),
              ),
              if (appointment.location == AppointmentLocation.whatsapp)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://wa.me/${appointment.phone!.replaceAll(RegExp(r'[^0-9]'), '')}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
            ],
          ),
        ],
        if (details?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Détails de la réunion', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(details!),
                if (detailsIsLink) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => launchUrl(detailsUri, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Rejoindre'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (appointment.declineReason?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Motif du refus', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(appointment.declineReason!),
              ],
            ),
          ),
        ],
        if (appointment.message?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(appointment.message!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
