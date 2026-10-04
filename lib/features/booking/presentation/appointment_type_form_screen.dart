import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/translated_field.dart';
import '../../inbox/data/appointment.dart';
import '../application/appointment_type_list_controller.dart';
import '../data/appointment_type_repository.dart';

/// Création ou modification d'un type de rendez-vous. `id == null` : création.
class AppointmentTypeFormScreen extends ConsumerStatefulWidget {
  const AppointmentTypeFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<AppointmentTypeFormScreen> createState() => _AppointmentTypeFormScreenState();
}

class _AppointmentTypeFormScreenState extends ConsumerState<AppointmentTypeFormScreen> {
  static const _durations = [15, 20, 30, 45, 60, 90, 120];

  late Future<void> _future = _load();

  Translated _name = const Translated();
  Translated _description = const Translated();
  late final _duration = TextEditingController(text: '30');
  late final _sortOrder = TextEditingController(text: '0');
  Set<AppointmentLocation> _locations = {AppointmentLocation.video};
  bool _isActive = true;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final type = await ref.read(appointmentTypeRepositoryProvider).get(widget.id!);
    _name = type.name;
    _description = type.description;
    _duration.text = '${type.durationMinutes}';
    _sortOrder.text = '${type.sortOrder}';
    _locations = type.locations.toSet();
    _isActive = type.isActive;
  }

  @override
  void dispose() {
    _duration.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _handlePopAttempt() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Vos changements non enregistrés seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer l\'édition')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(appointmentTypeRepositoryProvider)
          .save(
            id: widget.id,
            name: _name,
            description: _description,
            durationMinutes: int.tryParse(_duration.text.trim()) ?? 0,
            // Ordre stable, celui de l'énumération.
            locations: [
              for (final l in AppointmentLocation.values)
                if (_locations.contains(l)) l,
            ],
            isActive: _isActive,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
          );
      ref.invalidate(appointmentTypeListProvider);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le type « ${_name.display} » ?'),
        content: const Text('Il part à la corbeille : vous pourrez le restaurer si besoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(appointmentTypeRepositoryProvider).delete(widget.id!);
      ref.read(appointmentTypeListProvider.notifier).removeItem((t) => t.id == widget.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _validation;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: GlassAppBar(
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(onPressed: _locations.isEmpty ? null : _save, saving: _saving)
              : const SizedBox.shrink(),
        ),
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Réessayer')),
                  ],
                ),
              );
            }

            final locationsError = v?.errorFor('locations') ?? v?.errorFor('locations.0');

            return ListView(
              padding: pageInsets(context),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormHeader(title: _isEditing ? 'Modifier le type' : 'Nouveau type de rendez-vous'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TranslatedField(
                        label: 'Nom',
                        value: _name,
                        maxLength: 255,
                        errorFr: v?.errorFor('name.fr'),
                        errorEn: v?.errorFor('name.en'),
                        onChanged: (value) {
                          setState(() => _name = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TranslatedField(
                        label: 'Description (facultative)',
                        value: _description,
                        maxLines: 3,
                        errorFr: v?.errorFor('description.fr'),
                        errorEn: v?.errorFor('description.en'),
                        onChanged: (value) {
                          setState(() => _description = value);
                          _markDirty();
                        },
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
                      TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Durée',
                          suffixText: 'min',
                          helperText: 'De 10 à 480 minutes.',
                          errorText: v?.errorFor('duration_minutes'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final minutes in _durations)
                            ActionChip(
                              label: Text('$minutes min'),
                              onPressed: () {
                                _duration.text = '$minutes';
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Lieux proposés', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final location in AppointmentLocation.values)
                            FilterChip(
                              avatar: Icon(location.icon, size: 18),
                              label: Text(location.label),
                              selected: _locations.contains(location),
                              onSelected: (selected) {
                                setState(() {
                                  _locations = {..._locations};
                                  selected ? _locations.add(location) : _locations.remove(location);
                                });
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        locationsError ??
                            (_locations.isEmpty
                                ? 'Choisissez au moins un lieu.'
                                : 'Le visiteur choisit parmi ces lieux. Téléphone et WhatsApp lui demandent son numéro.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: locationsError != null || _locations.isEmpty
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Proposé sur le site'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                          _markDirty();
                        },
                      ),
                      TextField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _markDirty(),
                        decoration: InputDecoration(
                          labelText: 'Ordre d\'affichage',
                          errorText: v?.errorFor('sort_order'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
