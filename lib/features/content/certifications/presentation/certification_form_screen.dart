import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../../profile/presentation/widgets/photo_picker_tile.dart';
import '../application/certification_list_controller.dart';
import '../data/certification.dart';
import '../data/certification_repository.dart';

/// Création ou modification d'une certification. `id == null` : création.
class CertificationFormScreen extends ConsumerStatefulWidget {
  const CertificationFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<CertificationFormScreen> createState() => _CertificationFormScreenState();
}

class _CertificationFormScreenState extends ConsumerState<CertificationFormScreen> {
  late Future<void> _future = _load();

  CertificationKind _kind = CertificationKind.certification;
  Translated _name = const Translated();
  late final _issuer = TextEditingController();
  late final _credentialId = TextEditingController();
  late final _credentialUrl = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  DateTime? _issuedOn;
  DateTime? _expiresOn;
  PublicationStatus _status = PublicationStatus.published;
  String? _badgeUrl;
  XFile? _badgePending;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  bool _removingBadge = false;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  static final _dateLabel = DateFormat('d MMMM y', 'fr_FR');

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final c = await ref.read(certificationRepositoryProvider).get(widget.id!);
    _kind = c.kind;
    _name = c.name;
    _issuer.text = c.issuer;
    _credentialId.text = c.credentialId ?? '';
    _credentialUrl.text = c.credentialUrl ?? '';
    _sortOrder.text = '${c.sortOrder}';
    _issuedOn = c.issuedOn;
    _expiresOn = c.expiresOn;
    _status = c.status;
    _badgeUrl = c.badgeUrl;
  }

  @override
  void dispose() {
    _issuer.dispose();
    _credentialId.dispose();
    _credentialUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  String? _orNull(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

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

  Future<void> _pickDate({required bool expiry}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: (expiry ? _expiresOn : _issuedOn) ?? today,
      firstDate: DateTime(1990),
      lastDate: expiry ? today.add(const Duration(days: 3650)) : today,
    );
    if (date != null) {
      setState(() => expiry ? _expiresOn = date : _issuedOn = date);
      _markDirty();
    }
  }

  Future<void> _save() async {
    final issuedOn = _issuedOn;
    if (issuedOn == null) {
      setState(() => _error = 'Indiquez la date d\'obtention.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    final badge = _badgePending;
    try {
      await ref
          .read(certificationRepositoryProvider)
          .save(
            id: widget.id,
            kind: _kind,
            name: _name,
            issuer: _issuer.text.trim(),
            issuedOn: issuedOn,
            expiresOn: _expiresOn,
            credentialId: _orNull(_credentialId),
            credentialUrl: _orNull(_credentialUrl),
            status: _status,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            badge: badge == null ? null : await dio.MultipartFile.fromFile(badge.path, filename: badge.name),
          );
      ref.invalidate(certificationListProvider);
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

  Future<void> _removeBadge() async {
    setState(() => _removingBadge = true);
    try {
      final updated = await ref.read(certificationRepositoryProvider).deleteBadge(widget.id!);
      setState(() => _badgeUrl = updated.badgeUrl);
      ref.invalidate(certificationListProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _removingBadge = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${_name.display} » ?'),
        content: const Text('Elle part à la corbeille : vous pourrez la restaurer si besoin.'),
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
      await ref.read(certificationRepositoryProvider).delete(widget.id!);
      ref.read(certificationListProvider.notifier).removeItem((c) => c.id == widget.id);
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
              ? SaveBar(onPressed: _save, saving: _saving)
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
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final v = _validation;
    final errorStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: _isEditing ? 'Modifier' : 'Nouvelle certification ou formation'),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CertificationKind>(
                segments: [
                  for (final kind in CertificationKind.values) ButtonSegment(value: kind, label: Text(kind.label)),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _kind = selection.first);
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              TranslatedField(
                label: 'Nom',
                value: _name,
                maxLength: 160,
                errorFr: v?.errorFor('name.fr'),
                errorEn: v?.errorFor('name.en'),
                onChanged: (value) {
                  setState(() => _name = value);
                  _markDirty();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issuer,
                maxLength: 120,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(
                  labelText: 'Organisme',
                  hintText: 'AWS, Google, Udemy…',
                  errorText: v?.errorFor('issuer'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text(_issuedOn == null ? 'Date d\'obtention' : 'Obtenue le ${_dateLabel.format(_issuedOn!)}'),
                subtitle: v?.errorFor('issued_on') == null ? null : Text(v!.errorFor('issued_on')!, style: errorStyle),
                onTap: () => _pickDate(expiry: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(_expiresOn == null ? 'Sans expiration' : 'Expire le ${_dateLabel.format(_expiresOn!)}'),
                subtitle: v?.errorFor('expires_on') == null
                    ? const Text('Facultatif')
                    : Text(v!.errorFor('expires_on')!, style: errorStyle),
                trailing: _expiresOn == null
                    ? null
                    : IconButton(
                        tooltip: 'Retirer la date',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _expiresOn = null);
                          _markDirty();
                        },
                      ),
                onTap: () => _pickDate(expiry: true),
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
              Text('Vérification (facultative)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _credentialId,
                maxLength: 120,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(labelText: 'Identifiant', errorText: v?.errorFor('credential_id')),
              ),
              TextField(
                controller: _credentialUrl,
                keyboardType: TextInputType.url,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(
                  labelText: 'Lien de vérification',
                  hintText: 'https://…',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: v?.errorFor('credential_url'),
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
              PhotoPickerTile(
                label: 'Badge (2 Mo au plus)',
                currentUrl: _badgeUrl,
                pickedFile: _badgePending,
                onPicked: (file) {
                  setState(() => _badgePending = file);
                  _markDirty();
                },
              ),
              if (v?.errorFor('badge') != null) Text(v!.errorFor('badge')!, style: errorStyle),
              if (_badgeUrl != null && _badgePending == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _removingBadge ? null : _removeBadge,
                    icon: _removingBadge
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text('Retirer le badge'),
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
              TextField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(labelText: 'Ordre d\'affichage', errorText: v?.errorFor('sort_order')),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PublicationStatus>(
                segments: [
                  for (final status in PublicationStatus.values)
                    ButtonSegment(value: status, label: Text(status.label)),
                ],
                selected: {_status},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _status = selection.first);
                  _markDirty();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
