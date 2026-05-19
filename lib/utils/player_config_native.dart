import 'package:media_kit/media_kit.dart';

void configureNativePlayer(Player player) {
  final nativePlayer = player.platform as NativePlayer;
  nativePlayer.setProperty('hwdec', 'nvdec-copy');
  nativePlayer.setProperty('demuxer-max-bytes', '150MiB');
  nativePlayer.setProperty('demuxer-max-back-bytes', '50MiB');
  nativePlayer.setProperty('cache', 'yes');
  nativePlayer.setProperty('hr-seek', 'no');
  // Minimize audio output buffer so audio doesn't run ahead during fast playback.
  // At 7x speed, a normal ~200ms buffer represents ~1.4s of playback time,
  // which causes a visible jump on speed-change. Tiny buffer = tiny jump.
  nativePlayer.setProperty('audio-buffer', '0');
}
