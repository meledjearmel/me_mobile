import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/date_only.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../content/data/reference_repository.dart';
import '../application/job_application_list_controller.dart';
import '../data/job_application.dart';
import '../data/job_application_repository.dart';
import 'job_application_form_screen.dart';
import 'widgets/job_application_cv_card.dart';
import 'widgets/job_application_status_badge.dart';

/// Fiche d'une page de candidature : lien à partager, suivi, CV et historique.
class JobApplicationDetailScreen extends ConsumerStatefulWidget {
  const JobApplicationDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<JobApplicationDetailScreen> createState() => _JobApplicationDetailScreenState();
}

class _JobApplicationDetailScreenState extends ConsumerState<JobApplicationDetailScreen> {
  late Future<JobApplication> _future = _load();
  late Future<List<JobApplicationEvent>> _events = _loadEvents();

  Future<JobApplication> _load() => ref.read(jobApplicationRepositoryProvider).get(widget.id);

  Future<List<JobApplicationEvent>> _loadEvents() => ref.read(jobApplicationRepositoryProvider).events(widget.id);

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
      _events = _loadEvents();
    });
    await _future;
  }

  /// Après une action sur le CV : la réponse remplace la fiche et la ligne de liste.
  void _replace(JobApplication updated) {
    setState(() => _future = Future.value(updated));
    ref.read(jobApplicationListProvider.notifier).updateItem((a) => a.id == updated.id, (_) => updated);
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context)
        .push<Object?>(MaterialPageRoute(builder: (context) => JobApplicationFormScreen(id: widget.id)));
    if (!mounted) {
      return;
    }
    if (result == JobApplicationFormScreen.deleted) {
      Navigator.of(context).pop();
    } else if (result is JobApplication) {
      _replace(result);
    }
  }

  Future<void> _copyLink(JobApplication application) async {
    await Clipboard.setData(ClipboardData(text: application.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié.')));
    }
  }

  Future<void> _shareLink(JobApplication application) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: application.url,
        subject: '${application.position} · ${application.company}',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        actions: [IconButton(tooltip: 'Modifier', onPressed: _edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: FutureBuilder<JobApplication>(
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
                  FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
                ],
              ),
            );
          }
          return RefreshIndicator(onRefresh: _refresh, child: _buildBody(context, snapshot.data!));
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, JobApplication application) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final projects = ref.watch(projectsLiteRefProvider).value ?? const [];
    final profiles = ref.watch(jobProfilesRefProvider).value ?? const [];
    final profile = profiles.where((p) => p.id == application.jobProfileId).firstOrNull;

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: application.company, subtitle: application.position),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(alignment: Alignment.centerLeft, child: JobApplicationStatusBadge(application)),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: '${application.viewsCount}', label: 'Consultations'),
            (value: '${application.cvDownloadsCount}', label: 'CV téléchargés'),
            (
              value: application.lastViewedAt == null ? '—' : relativeDate(application.lastViewedAt!),
              label: 'Dernière visite',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Lien privé', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(application.url, style: muted),
              const SizedBox(height: 4),
              Text(
                application.isOpen
                    ? application.expiresOn == null
                          ? 'Ouvert, sans date limite.'
                          : 'Ouvert jusqu\'au ${formatDateOnly(application.expiresOn!)} inclus.'
                    : application.isExpired
                    ? 'Fermé : la date limite est passée.'
                    : 'Fermé : le lien ne répond que lorsque la page est en ligne.',
                style: muted?.copyWith(color: application.isOpen ? null : theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyLink(application),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copier'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareLink(application),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Partager'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Mot d\'accompagnement',
          summary: application.locale.toUpperCase(),
          children: [
            if (application.contactName?.isNotEmpty == true) Text('Pour ${application.contactName}', style: muted),
            MentionText(application.intro),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Projets montrés',
          summary: '${application.projectIds.length}',
          children: [
            if (application.projectIds.isEmpty)
              Text('Aucun projet.', style: muted)
            else
              for (final (index, id) in application.projectIds.indexed)
                Text('${index + 1}. ${projects.where((p) => p.id == id).firstOrNull?.title.display ?? 'Projet #$id'}'),
          ],
        ),
        const SizedBox(height: 12),
        JobApplicationCvCard(application: application, profileLabel: profile?.label.display, onChanged: _replace),
        if (application.jobPostingUrl != null || application.jobPostingText != null) ...[
          const SizedBox(height: 12),
          FormSection(
            title: 'Offre',
            initiallyExpanded: false,
            children: [
              if (application.jobPostingUrl != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(application.jobPostingUrl!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ouvrir l\'offre'),
                  ),
                ),
              if (application.jobPostingText != null) SelectableText(application.jobPostingText!),
            ],
          ),
        ],
        if (application.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          FormSection(title: 'Notes privées', children: [Text(application.notes!)]),
        ],
        const SizedBox(height: 12),
        FutureBuilder<List<JobApplicationEvent>>(
          future: _events,
          builder: (context, snapshot) => FormSection(
            title: 'Historique',
            summary: snapshot.hasData ? '${snapshot.data!.length}' : null,
            children: [
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                Text('Historique indisponible.', style: muted)
              else if (snapshot.data!.isEmpty)
                Text('Personne n\'a encore ouvert la page.', style: muted)
              else
                for (final event in snapshot.data!) _EventTile(event),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final JobApplicationEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      event.place ?? 'Lieu inconnu',
      if (event.device?.isNotEmpty == true) event.device!,
      if (event.referrerHost?.isNotEmpty == true) 'via ${event.referrerHost}',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(
          event.type == JobApplicationEventType.cvDownload ? Icons.download_rounded : Icons.visibility_outlined,
          size: 34,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.type.label, style: theme.textTheme.titleSmall),
              Text(details, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (event.createdAt != null)
          Text(
            relativeDate(event.createdAt!),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
