import 'player_config_stub.dart'
    if (dart.library.io) 'player_config_native.dart'
    as impl;

import 'package:media_kit/media_kit.dart';

void configureNativePlayer(Player player) => impl.configureNativePlayer(player);
