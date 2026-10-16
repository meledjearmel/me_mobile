import 'package:flutter/material.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/surfaces.dart';

typedef RecentItem = ({int id, String title, String subtitle, bool isNew, DateTime? at});

/// Un élément reçu : initiales, nom, extrait, date et point or si non lu.
class RecentTile extends StatelessWidget {
  const RecentTile({super.key, required this.item, required this.onTap});

  final RecentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListCardTile(
      onTap: onTap,
      leading: InitialsTile(item.title),
      title: item.title,
      unread: item.isNew,
      meta: item.at == null ? null : relativeDate(item.at!),
      subtitle: item.subtitle,
    );
  }
}
