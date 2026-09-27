import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// `null` : rien en lecture. Une seule piste à la fois (§4.3 : « Permets
/// d'écouter la piste dans l'app »).
@immutable
class TrackPlayerState {
  const TrackPlayerState({this.playingTrackId, this.isLoading = false});

  final int? playingTrackId;
  final bool isLoading;
}

final trackPlayerProvider = NotifierProvider<TrackPlayerController, TrackPlayerState>(TrackPlayerController.new);

class TrackPlayerController extends Notifier<TrackPlayerState> {
  late final AudioPlayer _player;

  @override
  TrackPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(_player.dispose);
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = const TrackPlayerState();
      }
    });
    return const TrackPlayerState();
  }

  /// Bascule lecture/pause. Change de piste si une autre est déjà chargée.
  Future<void> toggle(int trackId, String url) async {
    if (state.playingTrackId == trackId && !state.isLoading) {
      await _player.pause();
      state = const TrackPlayerState();
      return;
    }

    state = TrackPlayerState(playingTrackId: trackId, isLoading: true);
    try {
      await _player.setUrl(url);
      await _player.play();
      state = TrackPlayerState(playingTrackId: trackId);
    } on Object {
      state = const TrackPlayerState();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = const TrackPlayerState();
  }
}
