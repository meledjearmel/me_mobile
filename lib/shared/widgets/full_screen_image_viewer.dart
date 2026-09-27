import 'package:flutter/material.dart';

/// Aperçu plein écran d'une image (§5 : « Ouvre les PDF et les images en
/// aperçu »), avec zoom (pincer).
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({super.key, required this.url, this.heroTag});

  final String url;
  final Object? heroTag;

  static Future<void> open(BuildContext context, String url, {Object? heroTag}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenImageViewer(url: url, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(url, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: heroTag != null ? Hero(tag: heroTag!, child: image) : image,
        ),
      ),
    );
  }
}
