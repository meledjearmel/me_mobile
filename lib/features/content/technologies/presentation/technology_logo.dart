import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo de technologie : choisit la variante claire ou sombre selon le thème et
/// retombe sur [fallback] sans URL ou en cas d'échec de chargement.
class TechnologyLogo extends StatelessWidget {
  const TechnologyLogo({
    super.key,
    required this.lightUrl,
    required this.darkUrl,
    this.size = 40,
    this.fallback = Icons.memory_rounded,
  });

  final String? lightUrl;
  final String? darkUrl;
  final double size;
  final IconData fallback;

  static bool _isSvg(String url) => Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = (dark ? darkUrl ?? lightUrl : lightUrl ?? darkUrl);
    final placeholder = Icon(fallback, size: size * 0.7);

    Widget child;
    if (url == null || url.isEmpty) {
      child = placeholder;
    } else if (_isSvg(url)) {
      child = SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      child = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return SizedBox.square(dimension: size, child: Center(child: child));
  }
}
