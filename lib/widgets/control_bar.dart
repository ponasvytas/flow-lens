import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/app_settings.dart';
import 'tool_action_grid.dart';
import 'dockable_panel.dart';

class DraggableControlBar extends StatelessWidget {
  const DraggableControlBar({
    required this.player,
    required this.onSpeedChange,
    required this.onJumpForward,
    required this.onJumpBackward,
    required this.onTogglePlayPause,
    this.onResetZoom,
    this.settings = const AppSettings(),
    this.dockEdge = PanelDockEdge.floating,
    super.key,
  });
  final Player player;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<Duration> onJumpForward;
  final ValueChanged<Duration> onJumpBackward;
  final VoidCallback onTogglePlayPause;
  final VoidCallback? onResetZoom;
  final AppSettings settings;
  final PanelDockEdge dockEdge;

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
    stream: player.stream.rate,
    initialData: player.state.rate,
    builder: (context, rate) => StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, playing) => PlaybackControls(
        rate: rate.data!,
        playing: playing.data!,
        settings: settings,
        dockEdge: dockEdge,
        onSpeedChange: onSpeedChange,
        onJumpForward: onJumpForward,
        onJumpBackward: onJumpBackward,
        onTogglePlayPause: onTogglePlayPause,
        onResetZoom: onResetZoom,
        onToggleMute: () => player.setVolume(player.state.volume > 0 ? 0 : 100),
      ),
    ),
  );
}

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.rate,
    required this.playing,
    required this.onSpeedChange,
    required this.onJumpForward,
    required this.onJumpBackward,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    this.onResetZoom,
    this.settings = const AppSettings(),
    this.dockEdge = PanelDockEdge.floating,
  });
  final double rate;
  final bool playing;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<Duration> onJumpForward;
  final ValueChanged<Duration> onJumpBackward;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final VoidCallback? onResetZoom;
  final AppSettings settings;
  final PanelDockEdge dockEdge;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _Control(
        label: playing ? 'Pause' : 'Play',
        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        selected: true,
        onPressed: onTogglePlayPause,
      ),
      _Control(
        label: 'Back 5s',
        icon: Icons.replay_5_rounded,
        onPressed: () => onJumpBackward(const Duration(seconds: 5)),
      ),
      _Control(
        label: 'Slow',
        detail: '${settings.slowPlaybackSpeed}x',
        icon: Icons.slow_motion_video_rounded,
        selected: rate == settings.slowPlaybackSpeed,
        onPressed: () => onSpeedChange(settings.slowPlaybackSpeed),
      ),
      _Control(
        label: 'Normal',
        detail: '${settings.defaultPlaybackSpeed}x',
        icon: Icons.play_circle_outline_rounded,
        selected: rate == settings.defaultPlaybackSpeed,
        onPressed: () => onSpeedChange(settings.defaultPlaybackSpeed),
      ),
      _FastPlaybackControl(
        rate: rate,
        settings: settings,
        onSpeedChange: onSpeedChange,
      ),
      PopupMenuButton<String>(
        tooltip: 'More playback controls',
        onSelected: (value) {
          if (value.startsWith('rate:')) {
            onSpeedChange(double.parse(value.substring(5)));
          }
          if (value.startsWith('back:')) {
            onJumpBackward(Duration(seconds: int.parse(value.substring(5))));
          }
          if (value.startsWith('next:')) {
            onJumpForward(Duration(seconds: int.parse(value.substring(5))));
          }
          if (value == 'zoom') onResetZoom?.call();
          if (value == 'mute') {
            onToggleMute();
          }
        },
        itemBuilder: (_) => [
          for (final seconds in [3, 10, 30])
            PopupMenuItem(
              value: 'back:$seconds',
              child: Text('Back $seconds seconds'),
            ),
          for (final seconds in [3, 10, 30])
            PopupMenuItem(
              value: 'next:$seconds',
              child: Text('Forward $seconds seconds'),
            ),
          const PopupMenuDivider(),
          for (final speed in [0.25, 0.5, 1.0, 2.0, 3.0])
            PopupMenuItem(value: 'rate:$speed', child: Text('Speed $speed x')),
          const PopupMenuItem(value: 'mute', child: Text('Mute / unmute')),
          if (onResetZoom != null)
            const PopupMenuItem(value: 'zoom', child: Text('Reset zoom')),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.more_horiz_rounded),
              Text('More', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ];
    return ToolActionGrid(
      title: 'Playback',
      layout: layoutFor(settings),
      children: controls,
    );
  }

  static ToolsetLayout layoutFor(AppSettings settings) =>
      ToolsetLayout.actions([
        'Pause',
        'Back 5s',
        'Slow\n${settings.slowPlaybackSpeed}x',
        'Normal\n${settings.defaultPlaybackSpeed}x',
        'Fast\n${settings.fastPlaySpeed}x',
        'More',
      ], tileWidth: 64);
}

class _FastPlaybackControl extends StatefulWidget {
  const _FastPlaybackControl({
    required this.rate,
    required this.settings,
    required this.onSpeedChange,
  });

  final double rate;
  final AppSettings settings;
  final ValueChanged<double> onSpeedChange;

  @override
  State<_FastPlaybackControl> createState() => _FastPlaybackControlState();
}

class _FastPlaybackControlState extends State<_FastPlaybackControl>
    with WidgetsBindingObserver {
  int? _heldPointer;
  double? _previousRate;
  bool _suppressTap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _restoreSpeed() {
    final previousRate = _previousRate;
    _heldPointer = null;
    _previousRate = null;
    if (previousRate != null) widget.onSpeedChange(previousRate);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_heldPointer != null) return;
    final isTouch =
        event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus;
    _suppressTap = isTouch && !widget.settings.stickyFastPlayOnTouch;
    if (!_suppressTap) return;
    _heldPointer = event.pointer;
    _previousRate = widget.rate;
    widget.onSpeedChange(widget.settings.fastPlaySpeed);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _heldPointer) return;
    _restoreSpeed();
    // The button's tap callback follows pointer-up in the same event dispatch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _heldPointer == null) _suppressTap = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _restoreSpeed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSpeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerUp: _onPointerEnd,
    onPointerCancel: _onPointerEnd,
    child: _Control(
      label: 'Fast',
      detail: '${widget.settings.fastPlaySpeed}x',
      icon: Icons.fast_forward_rounded,
      selected: widget.rate == widget.settings.fastPlaySpeed,
      onPressed: () {
        if (!_suppressTap) widget.onSpeedChange(widget.settings.fastPlaySpeed);
      },
    ),
  );
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.detail,
  });
  final String label;
  final String? detail;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => ToolActionButton(
    label: detail == null ? label : '$label\n$detail',
    tooltip: detail == null ? label : '$label $detail',
    icon: icon,
    selected: selected,
    onPressed: onPressed,
  );
}
