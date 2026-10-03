import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/widgets/surfaces.dart';
import '../../data/testimonial.dart';

/// 95 Mo : Cloudflare refuse les corps de requête de plus de 100 Mo.
const maxTestimonialVideoBytes = 95 * 1024 * 1024;

/// Vidéo d'un avis : lecture, remplacement (envoyé à l'enregistrement) et retrait.
class TestimonialVideoCard extends StatelessWidget {
  const TestimonialVideoCard({
    super.key,
    required this.video,
    required this.pendingFile,
    required this.onPicked,
    required this.onCancelPending,
    required this.onRemove,
    required this.removing,
  });

  /// Vidéo en ligne, `null` pour un avis texte.
  final TestimonialVideo? video;

  /// Vidéo choisie sur l'appareil, pas encore envoyée.
  final XFile? pendingFile;
  final ValueChanged<XFile> onPicked;
  final VoidCallback onCancelPending;
  final VoidCallback onRemove;
  final bool removing;

  Future<void> _pick(BuildContext context) async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    if (await file.length() > maxTestimonialVideoBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo trop lourde (95 Mo maximum).')));
      }
      return;
    }
    onPicked(file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final video = this.video;
    final pending = pendingFile;

    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Vidéo', style: theme.textTheme.labelLarge)),
              if (video?.durationLabel != null) Text(video!.durationLabel!, style: muted),
            ],
          ),
          const SizedBox(height: 12),
          if (pending != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_rounded),
              title: Text(pending.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Envoyée à l\'enregistrement'),
              trailing: IconButton(
                tooltip: 'Annuler',
                icon: const Icon(Icons.close_rounded),
                onPressed: onCancelPending,
              ),
            ),
          ] else if (video != null) ...[
            _VideoPlayerView(video: video),
            if (video.duration == null) ...[
              const SizedBox(height: 8),
              Text('Vidéo en cours de traitement.', style: muted),
            ],
          ] else
            Text('Avis texte, sans vidéo.', style: muted),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: removing ? null : () => _pick(context),
                icon: const Icon(Icons.video_library_outlined),
                label: Text(video == null ? 'Joindre une vidéo' : 'Remplacer'),
              ),
              if (video != null && pending == null)
                TextButton.icon(
                  onPressed: removing ? null : onRemove,
                  icon: removing
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline_rounded),
                  label: const Text('Retirer la vidéo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aperçu (poster) puis lecture au toucher : rien n'est téléchargé avant.
class _VideoPlayerView extends StatefulWidget {
  const _VideoPlayerView({required this.video});

  final TestimonialVideo video;

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.url != widget.video.url) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.url));
    try {
      await controller.initialize();
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggle() {
    final controller = _controller!;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final posterUrl = widget.video.posterUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: controller?.value.aspectRatio ?? widget.video.aspectRatio,
        child: controller != null
            ? GestureDetector(
                onTap: _toggle,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying) const _PlayIcon(icon: Icons.play_arrow_rounded),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: VideoProgressIndicator(controller, allowScrubbing: true),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: _loading ? null : _start,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                    if (posterUrl != null) Image.network(posterUrl, fit: BoxFit.cover),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _PlayIcon(icon: _failed ? Icons.refresh_rounded : Icons.play_arrow_rounded),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
