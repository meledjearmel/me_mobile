import 'package:flutter/foundation.dart';

import '../../../../core/models/translated.dart';

@immutable
class MusicGenre {
  const MusicGenre({required this.id, required this.key, required this.label, required this.sortOrder});

  factory MusicGenre.fromJson(Map<String, dynamic> json) => MusicGenre(
        id: json['id'] as int,
        key: json['key'] as String,
        label: Translated.fromJson(json['label']),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final int id;
  final String key;
  final Translated label;
  final int sortOrder;
}
