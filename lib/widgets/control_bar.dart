import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/app_settings.dart';
import '../theme/flow_theme.dart';
import 'dockable_panel.dart';

class DraggableControlBar extends StatelessWidget {
  const DraggableControlBar({
    required this.player,
    required this.onSpeedChange,
    required this.onJumpForward,
    required this.onJumpBackward,
    required this.onTogglePlayPause,
    this.settings = const AppSettings(),
    this.dockEdge = PanelDockEdge.floating,
    super.key,
  });
  final Player player;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<Duration> onJumpForward;
  final ValueChanged<Duration> onJumpBackward;
  final VoidCallback onTogglePlayPause;
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
  final AppSettings settings;
  final PanelDockEdge dockEdge;

  @override
  Widget build(BuildContext context) {
    final vertical =
        dockEdge == PanelDockEdge.left || dockEdge == PanelDockEdge.right;
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
      _Control(
        label: 'Fast',
        detail: '${settings.fastPlaySpeed}x',
        icon: Icons.fast_forward_rounded,
        selected: rate == settings.fastPlaySpeed,
        onPressed: () => onSpeedChange(settings.fastPlaySpeed),
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
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
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
    return Padding(
      padding: const EdgeInsets.all(6),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final control in controls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: control,
                  ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final control in controls)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width:
                            64 *
                            MediaQuery.textScalerOf(context).scale(12) /
                            12,
                        child: control,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Tooltip(
      message: detail == null ? label : '$label $detail',
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(72, 64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          backgroundColor: selected ? FlowTheme.accent : FlowTheme.raised,
          foregroundColor: selected ? const Color(0xFF27123F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
            if (detail != null)
              Text(detail!, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
