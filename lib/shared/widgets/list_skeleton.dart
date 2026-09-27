import 'package:flutter/material.dart';

/// Squelette de chargement pour une liste (§5), à la place d'une simple
/// roue qui tourne : un aperçu discret de la forme du contenu à venir,
/// avec un léger effet de pulsation.
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Semantics(
      label: 'Chargement en cours',
      child: FadeTransition(
        opacity: _controller.drive(Tween(begin: 0.5, end: 1)),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: widget.itemCount,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                _Block(base, width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(base, width: double.infinity, height: 14),
                      const SizedBox(height: 8),
                      _Block(base, width: 140, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.color, {required this.width, required this.height, this.radius = 6});

  final Color color;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    );
  }
}
