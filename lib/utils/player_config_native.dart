import 'package:media_kit/media_kit.dart';

void configureNativePlayer(Player player) {
  final nativePlayer = player.platform as NativePlayer;
  nativePlayer.setProperty('hwdec', 'auto-safe');
  nativePlayer.setProperty('demuxer-max-bytes', '150MiB');
  nativePlayer.setProperty('demuxer-max-back-bytes', '50MiB');
  nativePlayer.setProperty('cache', 'yes');
  nativePlayer.setProperty('hr-seek', 'no');
}
