import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../data/review_invitation.dart';
import 'review_invitations_screen.dart';
import 'testimonial_links_card.dart';

/// Nouvelle demande d'avis. Une fois créée, l'écran présente le lien à
/// copier ou à envoyer par e-mail.
class ReviewInvitationFormScreen extends ConsumerStatefulWidget {
  const ReviewInvitationFormScreen({super.key});

  @override
  ConsumerState<ReviewInvitationFormScreen> createState() => _ReviewInvitationFormScreenState();
}

class _ReviewInvitationFormScreenState extends ConsumerState<ReviewInvitationFormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  String _locale = 'fr';
  int? _projectId;
  int? _experienceId;
  int? _educationId;
  DateTime? _expiresAt;

  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  /// Demande créée : l'écran affiche alors son lien.
  ReviewInvitation? _created;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (date != null) {
      setState(() => _expiresAt = date);
    }
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      final invitation = await ref
          .read(reviewInvitationRepositoryProvider)
          .create(
            locale: _locale,
            name: _orNull(_name),
            email: _orNull(_email),
            projectId: _projectId,
            experienceId: _experienceId,
            educationId: _educationId,
            note: _orNull(_note),
            expiresAt: _expiresAt,
          );
      setState(() => _created = invitation);
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

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
      bottomNavigationBar: created == null
          ? SaveBar(onPressed: _create, saving: _saving, label: 'Créer le lien')
          : null,
      body: created == null ? _buildForm(context) : _buildCreated(context, created),
    );
  }

  Widget _buildCreated(BuildContext context, ReviewInvitation invitation) {
    final theme = Theme.of(context);
    return ListView(
      padding: pageInsets(context),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: 'Lien créé', subtitle: 'Envoyez-le à la personne : il ne sert qu\'une fois.'),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(invitation.displayName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(invitation.subject ?? 'Avis général', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              SelectableText(invitation.url, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => copyInvitationLink(context, invitation),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copier le lien'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => emailInvitationLink(invitation),
                icon: const Icon(Icons.email_outlined),
                label: Text(invitation.email == null ? 'Envoyer par e-mail' : 'Envoyer à ${invitation.email}'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Terminer')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final v = _validation;

    return ListView(
      padding: pageInsets(context, bottom: 120),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(
            title: 'Nouvelle demande d\'avis',
            subtitle: 'Un lien personnel, à usage unique, vers le formulaire d\'avis prérempli.',
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Personne invitée (facultatif)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Nom', errorText: v?.errorFor('name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'E-mail', errorText: v?.errorFor('email')),
              ),
              const SizedBox(height: 16),
              Text('Langue du lien', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fr', label: Text('Français')),
                  ButtonSegment(value: 'en', label: Text('Anglais')),
                ],
                selected: {_locale},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _locale = selection.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TestimonialLinksCard(
          projectId: _projectId,
          experienceId: _experienceId,
          educationId: _educationId,
          onProjectChanged: (id) => setState(() => _projectId = id),
          onExperienceChanged: (id) => setState(() => _experienceId = id),
          onEducationChanged: (id) => setState(() => _educationId = id),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _note,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Mémo (facultatif)',
                  helperText: 'Visible seulement par vous.',
                  errorText: v?.errorFor('note'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(
                  _expiresAt == null
                      ? 'Sans date d\'expiration'
                      : 'Expire le ${DateFormat('d MMMM y', 'fr_FR').format(_expiresAt!)}',
                ),
                subtitle: v?.errorFor('expires_at') == null
                    ? null
                    : Text(v!.errorFor('expires_at')!, style: TextStyle(color: theme.colorScheme.error)),
                trailing: _expiresAt == null
                    ? null
                    : IconButton(
                        tooltip: 'Retirer la date',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _expiresAt = null),
                      ),
                onTap: _pickExpiry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
