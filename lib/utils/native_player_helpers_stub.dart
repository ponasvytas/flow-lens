import 'package:media_kit/media_kit.dart';

void nativeMutePlayer(Player player) {
  // No-op on web
}

Future<void> nativeResyncAfterFF(
  Player player,
  bool Function() isStillActive,
) async {
  // No-op on web
}
