import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'app_log.dart';

void nativeMutePlayer(Player player) {
  final np = player.platform as NativePlayer;
  np.setProperty('mute', 'yes');
  // Decouple A/V sync during FF so audio buffer state can't drag video on release.
  np.setProperty('video-sync', 'desync');
}

Future<void> nativeResyncAfterFF(
  Player player,
  bool Function() isStillActive,
) async {
  try {
    final np = player.platform as NativePlayer;
    // Restore default A/V sync
    np.setProperty('video-sync', 'audio');
    // Small delay so the tiny audio buffer can drain silently before unmute
    await Future.delayed(const Duration(milliseconds: 80));
    if (!isStillActive()) {
      np.setProperty('mute', 'no');
    }
  } catch (e) {
    AppLog.debug('resyncAfterFF error: $e');
    (player.platform as NativePlayer).setProperty('mute', 'no');
  }
}
