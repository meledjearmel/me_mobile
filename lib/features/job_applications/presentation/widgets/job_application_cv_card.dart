import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../data/job_application.dart';
import '../../data/job_application_repository.dart';

/// Le CV proposé par la page : standard (celui du profil métier) ou adapté à
/// l'offre par l'IA. Aperçu, génération, retouche, retour au standard et PDF.
class JobApplicationCvCard extends ConsumerStatefulWidget {
  const JobApplicationCvCard({
    super.key,
    required this.application,
    required this.profileLabel,
    required this.onChanged,
  });

  final JobApplication application;
  final String? profileLabel;
  final ValueChanged<JobApplication> onChanged;

  @override
  ConsumerState<JobApplicationCvCard> createState() => _JobApplicationCvCardState();
}

class _JobApplicationCvCardState extends ConsumerState<JobApplicationCvCard> {
  /// Action en cours (`tailor`, `edit`, `reset`, `pdf`), pour l'indicateur.
  String? _busy;

  JobApplicationRepository get _repository => ref.read(jobApplicationRepositoryProvider);

  Future<void> _run(String action, Future<void> Function() task) async {
    setState(() => _busy = action);
    try {
      await task();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(String title, String content, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _tailor() async {
    if (widget.application.isTailored &&
        !await _confirm('Adapter à nouveau ?', 'L\'IA remplace le CV adapté actuel, retouches comprises.', 'Adapter')) {
      return;
    }
    await _run('tailor', () async {
      widget.onChanged(await _repository.tailorCv(widget.application.id));
      _toast('CV adapté à l\'offre.');
    });
  }

  Future<void> _reset() async {
    if (!await _confirm(
      'Revenir au CV standard ?',
      'Le CV adapté est effacé : l\'entreprise téléchargera le CV du profil métier.',
      'Revenir',
    )) {
      return;
    }
    await _run('reset', () async {
      widget.onChanged(await _repository.resetCv(widget.application.id));
      _toast('CV standard rétabli.');
    });
  }

  Future<void> _edit() async {
    final tailoring = widget.application.cvTailoring!;
    final result = await showDialog<({String title, String summary})>(
      context: context,
      builder: (context) => _EditDialog(title: tailoring.title ?? '', summary: tailoring.summary ?? ''),
    );
    if (result == null) {
      return;
    }
    await _run('edit', () async {
      widget.onChanged(
        await _repository.updateCv(
          widget.application.id,
          title: result.title.trim().isEmpty ? null : result.title.trim(),
          summary: result.summary.trim().isEmpty ? null : result.summary.trim(),
        ),
      );
      _toast('CV retouché.');
    });
  }

  /// Le PDF passe par la feuille de partage : l'appareil propose de l'ouvrir
  /// dans un lecteur, de l'enregistrer ou de l'envoyer.
  Future<void> _openPdf() async {
    final box = context.findRenderObject() as RenderBox?;
    await _run('pdf', () async {
      final bytes = await _repository.downloadCv(widget.application.id);
      final name = 'cv-${widget.application.token}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final application = widget.application;
    final tailoring = application.cvTailoring;

    if (application.jobProfileId == null) {
      return FormSection(
        title: 'CV',
        children: [Text('Aucun profil métier choisi : la page ne propose pas de CV.', style: muted)],
      );
    }

    Widget busyIcon(String action, IconData icon) => _busy == action
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 18);

    return FormSection(
      title: 'CV',
      summary: tailoring == null ? 'Standard' : 'Adapté',
      children: [
        Text(
          tailoring == null
              ? 'CV standard du profil « ${widget.profileLabel ?? 'métier'} ».'
              : 'Adapté à l\'offre${application.cvTailoredAt == null ? '' : ' ${relativeDate(application.cvTailoredAt!)}'}, '
                    'à partir du profil « ${widget.profileLabel ?? 'métier'} ».',
          style: muted,
        ),
        if (tailoring != null) ...[
          if (tailoring.title?.isNotEmpty == true) Text(tailoring.title!, style: theme.textTheme.titleMedium),
          if (tailoring.summary?.isNotEmpty == true) Text(tailoring.summary!),
          Text(
            '${tailoring.highlightsCount} réalisation${tailoring.highlightsCount > 1 ? 's' : ''} retenue'
            '${tailoring.highlightsCount > 1 ? 's' : ''} · ${tailoring.skillIds.length} compétence'
            '${tailoring.skillIds.length > 1 ? 's' : ''} en avant',
            style: muted,
          ),
          if (tailoring.reasoning?.isNotEmpty == true)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text(tailoring.reasoning!, style: muted)),
              ],
            ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy == null ? _openPdf : null,
              icon: busyIcon('pdf', Icons.picture_as_pdf_outlined),
              label: const Text('Voir le PDF'),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy == null ? _tailor : null,
              icon: busyIcon('tailor', Icons.auto_awesome_rounded),
              label: Text(tailoring == null ? 'Adapter avec l\'IA' : 'Adapter à nouveau'),
            ),
            if (tailoring != null) ...[
              OutlinedButton.icon(
                onPressed: _busy == null ? _edit : null,
                icon: busyIcon('edit', Icons.edit_outlined),
                label: const Text('Retoucher'),
              ),
              TextButton.icon(
                onPressed: _busy == null ? _reset : null,
                icon: busyIcon('reset', Icons.undo_rounded),
                label: const Text('CV standard'),
              ),
            ],
          ],
        ),
        if (_busy == 'tailor') Text('Adaptation en cours, cela peut prendre jusqu\'à une minute…', style: muted),
      ],
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.title, required this.summary});

  final String title;
  final String summary;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _title = TextEditingController(text: widget.title);
  late final _summary = TextEditingController(text: widget.summary);

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Retoucher le CV'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summary,
              minLines: 4,
              maxLines: 10,
              maxLength: 1500,
              decoration: const InputDecoration(labelText: 'Résumé', alignLabelWithHint: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, (title: _title.text, summary: _summary.text)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
