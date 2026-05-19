import 'native_player_helpers_stub.dart'
    if (dart.library.io) 'native_player_helpers_native.dart'
    as impl;

import 'package:media_kit/media_kit.dart';

void nativeMutePlayer(Player player) =>
    impl.nativeMutePlayer(player);

Future<void> nativeResyncAfterFF(Player player, bool Function() isStillActive) =>
    impl.nativeResyncAfterFF(player, isStillActive);
