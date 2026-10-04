import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import 'widgets/cv_settings_card.dart';
import '../data/site_settings.dart';
import '../data/site_settings_repository.dart';

/// Délais proposés entre deux notifications de félicitations d'un même motif.
const congratulationNotifyDelays = [0, 5, 10, 30, 60, 180, 1440];

String congratulationNotifyDelayLabel(int minutes) => switch (minutes) {
  0 => 'À chaque envoi',
  1440 => 'Au plus une par jour',
  _ when minutes >= 60 && minutes % 60 == 0 => 'Au plus une toutes les ${minutes ~/ 60} h',
  _ => 'Au plus une toutes les $minutes min',
};

/// Réglages de gestion du site : affichage, avis, CV, notifications et rendez-vous.
class SiteSettingsScreen extends ConsumerWidget {
  const SiteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(siteSettingsProvider);
    return settings.when(
      data: (data) => _SiteSettingsForm(settings: data),
      loading: () => const Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error is ApiException ? error.message : 'Erreur.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(siteSettingsProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteSettingsForm extends ConsumerStatefulWidget {
  const _SiteSettingsForm({required this.settings});

  final SiteSettings settings;

  @override
  ConsumerState<_SiteSettingsForm> createState() => _SiteSettingsFormState();
}

class _SiteSettingsFormState extends ConsumerState<_SiteSettingsForm> {
  late bool _contactOpensDrawer = widget.settings.contactOpensDrawer;
  late bool _blogEnabled = widget.settings.blogEnabled;
  late bool _testimonialVideoEnabled = widget.settings.testimonialVideoEnabled;
  late int? _cvJobProfileId = widget.settings.cvJobProfileId;
  late CvSource _cvSource = widget.settings.cvSource;
  late int _notifyMinutes = widget.settings.congratulationNotifyMinutes;
  late bool _bookingEnabled = widget.settings.bookingEnabled;
  late final _minNotice = TextEditingController(text: '${widget.settings.bookingMinNoticeHours}');
  late final _horizon = TextEditingController(text: '${widget.settings.bookingHorizonDays}');
  late final _buffer = TextEditingController(text: '${widget.settings.bookingBufferMinutes}');
  late BookingVideoProvider _videoProvider = widget.settings.bookingVideoProvider;
  late final _videoLink = TextEditingController(text: widget.settings.bookingVideoLink ?? '');

  bool _dirty = false;
  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  @override
  void dispose() {
    _minNotice.dispose();
    _horizon.dispose();
    _buffer.dispose();
    _videoLink.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  /// Un champ vide ou illisible garde la valeur actuelle.
  int _intOf(TextEditingController controller, int fallback) => int.tryParse(controller.text.trim()) ?? fallback;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    final current = widget.settings;
    final link = _videoLink.text.trim();
    try {
      await ref
          .read(siteSettingsRepositoryProvider)
          .update(
            SiteSettings(
              contactOpensDrawer: _contactOpensDrawer,
              testimonialVideoEnabled: _testimonialVideoEnabled,
              blogEnabled: _blogEnabled,
              cvJobProfileId: _cvJobProfileId,
              cvSource: _cvSource,
              congratulationNotifyMinutes: _notifyMinutes,
              bookingEnabled: _bookingEnabled,
              bookingMinNoticeHours: _intOf(_minNotice, current.bookingMinNoticeHours),
              bookingHorizonDays: _intOf(_horizon, current.bookingHorizonDays),
              bookingBufferMinutes: _intOf(_buffer, current.bookingBufferMinutes),
              bookingVideoProvider: _videoProvider,
              bookingVideoLink: link.isEmpty ? null : link,
            ),
          );
      _dirty = false;
      ref.invalidate(siteSettingsProvider);
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
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;

    Widget numberField(TextEditingController controller, String label, String suffix, String field) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _set(() {}),
      decoration: InputDecoration(labelText: label, suffixText: suffix, errorText: v?.errorFor(field)),
    );

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
        appBar: const GlassAppBar(),
        bottomNavigationBar: SaveBar(onPressed: _save, saving: _saving),
        body: ListView(
          padding: pageInsets(context, bottom: 120),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: FormHeader(title: 'Réglages du site', subtitle: 'Valables pour tout le site public.'),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            if (v != null) ...[ErrorBanner(v.message), const SizedBox(height: 16)],
            SurfaceCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Site', style: theme.textTheme.labelLarge),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bouton Contact en tiroir'),
                    subtitle: Text(
                      _contactOpensDrawer ? 'Ouvre le tiroir latéral sans quitter la page.' : 'Mène à la page Contact.',
                    ),
                    value: _contactOpensDrawer,
                    onChanged: (value) => _set(() => _contactOpensDrawer = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Blog'),
                    subtitle: const Text('Affiché sur le site : pages, navigation et plan du site.'),
                    value: _blogEnabled,
                    onChanged: (value) => _set(() => _blogEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avis vidéo des visiteurs'),
                    subtitle: const Text('Les visiteurs peuvent joindre ou filmer une vidéo avec leur avis.'),
                    value: _testimonialVideoEnabled,
                    onChanged: (value) => _set(() => _testimonialVideoEnabled = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CvSettingsCard(
              jobProfileId: _cvJobProfileId,
              source: _cvSource,
              jobProfileError: v?.errorFor('cv_job_profile_id'),
              sourceError: v?.errorFor('cv_source'),
              onJobProfileChanged: (id) => _set(() => _cvJobProfileId = id),
              onSourceChanged: (source) => _set(() => _cvSource = source),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Notifications', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: congratulationNotifyDelays.contains(_notifyMinutes) ? _notifyMinutes : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Félicitations, par motif',
                      errorText: v?.errorFor('congratulation_notify_minutes'),
                    ),
                    items: [
                      for (final delay in congratulationNotifyDelays)
                        DropdownMenuItem(value: delay, child: Text(congratulationNotifyDelayLabel(delay))),
                    ],
                    onChanged: (value) => _set(() => _notifyMinutes = value ?? _notifyMinutes),
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
                  Text('Rendez-vous', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text('Heures d\'Abidjan (UTC).', style: muted),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prise de rendez-vous'),
                    subtitle: const Text('Les visiteurs peuvent réserver un créneau sur le site.'),
                    value: _bookingEnabled,
                    onChanged: (value) => _set(() => _bookingEnabled = value),
                  ),
                  const SizedBox(height: 8),
                  numberField(_minNotice, 'Délai minimum avant un rendez-vous', 'h', 'booking_min_notice_hours'),
                  const SizedBox(height: 12),
                  numberField(_horizon, 'Réservable jusqu\'à', 'jours', 'booking_horizon_days'),
                  const SizedBox(height: 12),
                  numberField(_buffer, 'Pause entre deux rendez-vous', 'min', 'booking_buffer_minutes'),
                  const SizedBox(height: 16),
                  Text('Visio', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<BookingVideoProvider>(
                    segments: [
                      for (final value in BookingVideoProvider.values)
                        ButtonSegment(value: value, label: Text(value.label)),
                    ],
                    selected: {_videoProvider},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => _set(() => _videoProvider = selection.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v?.errorFor('booking_video_provider') ??
                        (_videoProvider == BookingVideoProvider.jitsi
                            ? 'Un lien Jitsi unique est créé à la confirmation de chaque rendez-vous.'
                            : 'Le même lien est envoyé pour chaque rendez-vous en visio.'),
                    style: muted,
                  ),
                  if (_videoProvider == BookingVideoProvider.link) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _videoLink,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => _set(() {}),
                      decoration: InputDecoration(
                        labelText: 'Lien de visio',
                        hintText: 'https://meet.google.com/…',
                        prefixIcon: const Icon(Icons.link_rounded),
                        errorText: v?.errorFor('booking_video_link'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
