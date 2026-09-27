import 'package:flutter/foundation.dart';

@immutable
class Track {
  const Track({
    required this.id,
    required this.musicGenreId,
    required this.title,
    required this.artist,
    required this.sortOrder,
    required this.audioUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as int,
        musicGenreId: json['music_genre_id'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
        audioUrl: json['audio_url'] as String?,
      );

  final int id;
  final int musicGenreId;
  final String title;
  final String? artist;
  final int sortOrder;
  final String? audioUrl;
}
