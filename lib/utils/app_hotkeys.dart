/// Bare keys reserved across workflows. Labels match LogicalKeyboardKey.
const playbackHotkeyActions = <String, String>{
  ' ': 'Play / pause',
  'space': 'Play / pause',
  'arrow left': 'Jump backward',
  'arrow right': 'Jump forward',
  'a': 'Jump back 5 seconds',
  's': 'Slow playback',
  'd': 'Normal playback',
  'f': 'Fast forward',
  'm': 'Mute / unmute',
};

String? trackingHotkeyError(String key) {
  final normalized = key.toLowerCase();
  final playback = playbackHotkeyActions[normalized];
  if (playback != null) return 'Reserved for playback: $playback.';
  if (normalized == 'p') return 'Reserved for performance diagnostics.';
  if (!RegExp(r'^[a-z0-9]$').hasMatch(normalized)) {
    return 'Choose a single letter or number.';
  }
  return null;
}
