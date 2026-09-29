import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../application/testimonial_list_controller.dart';
import '../../data/testimonial.dart';
import '../../data/testimonial_repository.dart';

/// Modération et correction de texte d'un avis, dans la même requête `PUT` (§4.2).
class TestimonialEditScreen extends ConsumerStatefulWidget {
  const TestimonialEditScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<TestimonialEditScreen> createState() => _TestimonialEditScreenState();
}

class _TestimonialEditScreenState extends ConsumerState<TestimonialEditScreen> {
  Testimonial? _testimonial;
  late Future<Testimonial> _future = _load();

  TestimonialStatus? _status;
  bool _isFeatured = false;
  late final _nameController = TextEditingController();
  late final _roleController = TextEditingController();
  Translated _content = const Translated();

  bool _saving = false;
  bool _dirty = false;
  String? _error;

  Future<Testimonial> _load() async {
    final testimonial = await ref.read(testimonialRepositoryProvider).get(widget.id);
    _testimonial = testimonial;
    _status = testimonial.status;
    _isFeatured = testimonial.isFeatured;
    _nameController.text = testimonial.authorName;
    _roleController.text = testimonial.authorRole ?? '';
    _content = testimonial.content;
    return testimonial;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) {
      return true;
    }
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
    return leave ?? false;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(testimonialRepositoryProvider)
          .updateContent(
            widget.id,
            status: _status!,
            isFeatured: _isFeatured,
            authorName: _nameController.text.trim(),
            authorRole: _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
            content: _content,
          );
      ref.read(testimonialListProvider.notifier).updateItem((t) => t.id == widget.id, (t) => updated);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final testimonial = _testimonial;
    if (testimonial == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer l\'avis de « ${testimonial.authorName} » ?'),
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
    try {
      await ref.read(testimonialRepositoryProvider).delete(testimonial.id);
      ref.read(testimonialListProvider.notifier).removeItem((t) => t.id == testimonial.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _handlePopAttempt() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          ],
        ),
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          // Pas d'enregistrement tant que le formulaire n'est pas chargé.
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(onPressed: _save, saving: _saving)
              : const SizedBox.shrink(),
        ),
        body: FutureBuilder<Testimonial>(
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

            final testimonial = snapshot.data!;
            return ListView(
              padding: pageInsets(context),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormHeader(title: 'Avis'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                SurfaceCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(testimonial.authorEmail, style: theme.textTheme.bodyMedium)),
                          if (testimonial.submittedAt != null)
                            Text(
                              relativeDate(testimonial.submittedAt!),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      if (testimonial.project != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'À propos de : ${testimonial.project!.title.display}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('Modération', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      SegmentedButton<TestimonialStatus>(
                        segments: const [
                          ButtonSegment(value: TestimonialStatus.pending, label: Text('En attente')),
                          ButtonSegment(value: TestimonialStatus.approved, label: Text('Approuvé')),
                          ButtonSegment(value: TestimonialStatus.rejected, label: Text('Rejeté')),
                        ],
                        selected: {_status!},
                        onSelectionChanged: (selection) {
                          setState(() => _status = selection.first);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('À la une'),
                        subtitle: const Text('Trois avis au maximum peuvent être mis en avant.'),
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() => _isFeatured = value);
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
                      Text('Corriger le texte', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(labelText: 'Nom de l\'auteur'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roleController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(labelText: 'Rôle (facultatif)'),
                      ),
                      const SizedBox(height: 12),
                      TranslatedField(
                        label: 'Contenu',
                        value: _content,
                        maxLines: 5,
                        maxLength: 2000,
                        onChanged: (value) {
                          setState(() => _content = value);
                          _markDirty();
                        },
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
