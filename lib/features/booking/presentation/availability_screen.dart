import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/availability.dart';
import '../data/availability_repository.dart';

String _hhmm(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _periodLabel(BlockedPeriod period) {
  final format = DateFormat('d MMM y', 'fr_FR');
  return period.from == period.to
      ? format.format(period.from)
      : '${format.format(period.from)} → ${format.format(period.to)}';
}

/// Plages hebdomadaires où les visiteurs peuvent réserver, et périodes
/// bloquées (congés…). Heures d'Abidjan (UTC). Chaque ajout ou retrait part
/// tout de suite : pas de bouton Enregistrer.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(availabilityProvider);
    } on ValidationException catch (e) {
      _snack(e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _addRule() async {
    final result = await showModalBottomSheet<({List<Weekday> days, String start, String end})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _RuleSheet(),
    );
    if (result == null) {
      return;
    }
    await _run(
      () => ref.read(availabilityRepositoryProvider).addRule(days: result.days, start: result.start, end: result.end),
    );
  }

  Future<void> _addBlockedPeriod() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Période bloquée',
      saveText: 'Suivant',
    );
    if (range == null || !mounted) {
      return;
    }
    final labelController = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif (facultatif)'),
        content: TextField(
          controller: labelController,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(hintText: 'Ex. congés'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, labelController.text.trim()),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    ).whenComplete(labelController.dispose);
    if (label == null) {
      return;
    }
    await _run(
      () => ref
          .read(availabilityRepositoryProvider)
          .addBlockedPeriod(from: range.start, to: range.end, label: label.isEmpty ? null : label),
    );
  }

  Future<void> _remove(int id, String what) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer $what ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref.read(availabilityRepositoryProvider).delete(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final availability = ref.watch(availabilityProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: availability.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error is ApiException ? error.message : 'Erreur.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(availabilityProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(availabilityProvider.future),
          child: ListView(
            padding: pageInsets(context),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FormHeader(title: 'Disponibilités', subtitle: 'Heures d\'Abidjan (UTC).'),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Plages hebdomadaires', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text('Les créneaux proposés aux visiteurs, chaque semaine.', style: muted),
                    if (data.rules.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Aucune plage : personne ne peut réserver.', style: muted),
                    ],
                    for (final rule in data.rules)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text('${rule.start} – ${rule.end}'),
                        subtitle: Text(rule.daysLabel),
                        trailing: IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _busy ? null : () => _remove(rule.id, 'la plage ${rule.start} – ${rule.end}'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _addRule,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter une plage'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Périodes bloquées', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text('Aucun rendez-vous ces jours-là (dates incluses).', style: muted),
                    for (final period in data.blockedPeriods)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_busy_outlined),
                        title: Text(_periodLabel(period)),
                        subtitle: period.label?.isNotEmpty == true ? Text(period.label!) : null,
                        trailing: IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _busy ? null : () => _remove(period.id, 'la période bloquée'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _addBlockedPeriod,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Bloquer une période'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jours et heures d'une nouvelle plage.
class _RuleSheet extends StatefulWidget {
  const _RuleSheet();

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  final _days = <Weekday>{Weekday.monday, Weekday.tuesday, Weekday.wednesday, Weekday.thursday, Weekday.friday};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);

  bool get _valid => _days.isNotEmpty && _end.hour * 60 + _end.minute > _start.hour * 60 + _start.minute;

  Future<void> _pick({required bool start}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time != null) {
      setState(() => start ? _start = time : _end = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvelle plage', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in Weekday.values)
                  FilterChip(
                    label: Text(day.short),
                    tooltip: day.label,
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(() => selected ? _days.add(day) : _days.remove(day)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _pick(start: true), child: Text('De ${_hhmm(_start)}')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: () => _pick(start: false), child: Text('À ${_hhmm(_end)}')),
                ),
              ],
            ),
            if (!_valid) ...[
              const SizedBox(height: 8),
              Text(
                _days.isEmpty ? 'Choisissez au moins un jour.' : 'L\'heure de fin doit suivre l\'heure de début.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(context, (
                      days: [
                        for (final day in Weekday.values)
                          if (_days.contains(day)) day,
                      ],
                      start: _hhmm(_start),
                      end: _hhmm(_end),
                    ))
                  : null,
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
