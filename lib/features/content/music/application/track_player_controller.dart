import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/track.dart';

/// `track == null` : rien en lecture ni en pause. [playlist] est la liste
/// depuis laquelle la piste a été lancée (celle affichée à l'écran, déjà
/// filtrée/recherchée) : elle sert à avancer automatiquement à la piste
/// suivante en fin de lecture (§4.3 : « Permets d'écouter la piste dans
/// l'app »), et reste utile même après avoir quitté l'écran Pistes puisque
/// la barre de lecture est persistante (voir [MiniPlayerBar]).
@immutable
class TrackPlayerState {
  const TrackPlayerState({this.track, this.playlist = const [], this.isLoading = false, this.isPlaying = false});

  final Track? track;
  final List<Track> playlist;
  final bool isLoading;
  final bool isPlaying;
}

final trackPlayerProvider = NotifierProvider<TrackPlayerController, TrackPlayerState>(TrackPlayerController.new);

class TrackPlayerController extends Notifier<TrackPlayerState> {
  late final AudioPlayer _player;

  /// Position de lecture en continu, pour la barre de progression. Exposée en
  /// flux brut plutôt que recopiée dans [state] : elle change bien trop
  /// souvent pour déclencher une reconstruction de tout ce qui observe l'état
  /// du lecteur (liste des pistes, coque de navigation…).
  Stream<Duration> get positionStream => _player.positionStream;

  Duration? get duration => _player.duration;

  @override
  TrackPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(_player.dispose);
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });
    return const TrackPlayerState();
  }

  /// Lance [track] (ignoré si déjà en cours : bascule play/pause à la place)
  /// et mémorise [playlist] pour la lecture continue.
  Future<void> playFromList(List<Track> playlist, Track track) async {
    if (track.audioUrl == null) {
      return;
    }
    if (state.track?.id == track.id) {
      await togglePlayPause();
      return;
    }

    state = TrackPlayerState(track: track, playlist: playlist, isLoading: true);
    try {
      await _player.setUrl(track.audioUrl!);
      await _player.play();
      state = TrackPlayerState(track: track, playlist: playlist, isPlaying: true);
    } on Object {
      state = const TrackPlayerState();
    }
  }

  /// Bascule lecture/pause de la piste déjà chargée, sans la recharger (donc
  /// sans perdre la position, contrairement à un nouvel appel à [playFromList]).
  Future<void> togglePlayPause() async {
    final track = state.track;
    if (track == null || state.isLoading) {
      return;
    }
    if (state.isPlaying) {
      await _player.pause();
      state = TrackPlayerState(track: track, playlist: state.playlist);
    } else {
      await _player.play();
      state = TrackPlayerState(track: track, playlist: state.playlist, isPlaying: true);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = const TrackPlayerState();
  }

  Future<void> _onTrackCompleted() async {
    final current = state.track;
    if (current == null) {
      return;
    }
    final currentIndex = state.playlist.indexWhere((t) => t.id == current.id);
    final next = _nextPlayable(state.playlist, currentIndex);
    if (next == null) {
      state = const TrackPlayerState();
      return;
    }
    await playFromList(state.playlist, next);
  }

  Track? _nextPlayable(List<Track> playlist, int currentIndex) {
    for (var i = currentIndex + 1; i < playlist.length; i++) {
      if (playlist[i].audioUrl != null) {
        return playlist[i];
      }
    }
    return null;
  }
}
