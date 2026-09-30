import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/game_event.dart';
import '../controllers/scrub_seek_coordinator.dart';
import '../utils/perf.dart';
import '../utils/responsive_layout.dart';
import '../theme/flow_theme.dart';
import 'event_timeline.dart';
import 'tool_action_grid.dart';

class VideoProgressBar extends StatefulWidget {
  final Player player;
  final List<GameEvent> events;
  final ValueChanged<GameEvent> onEventTap;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSpeedChange;
  final VoidCallback? onScrubStart;
  final VoidCallback? onJumpBackward;

  const VideoProgressBar({
    super.key,
    required this.player,
    required this.events,
    required this.onEventTap,
    required this.onPlayPause,
    required this.onSpeedChange,
    this.onScrubStart,
    this.onJumpBackward,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double _audibleVolume = 100;

  @override
  void didUpdateWidget(VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) _audibleVolume = 100;
  }

  @override
  Widget build(BuildContext context) {
    Perf.rebuildCount('VideoProgressBar');
    // Position ticks stay inside _SeekBar. Markers only rebuild for event or
    // duration changes, while control streams retain this same child.
    final seekBar = StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, snapshot) => _SeekBar(
        player: widget.player,
        duration: snapshot.data ?? Duration.zero,
        onScrubStart: widget.onScrubStart,
        markers: EventTimeline(
          events: widget.events,
          totalDuration: snapshot.data ?? Duration.zero,
          onEventTap: widget.onEventTap,
        ),
      ),
    );
    return Positioned(
      bottom: 10,
      left: usesPhoneLayout(context) ? 4 : 20,
      right: usesPhoneLayout(context) ? 4 : 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: StreamBuilder<bool>(
            stream: widget.player.stream.playing,
            initialData: widget.player.state.playing,
            builder: (context, playing) => StreamBuilder<double>(
              stream: widget.player.stream.rate,
              initialData: widget.player.state.rate,
              builder: (context, rate) => StreamBuilder<double>(
                stream: widget.player.stream.volume,
                initialData: widget.player.state.volume,
                builder: (context, volume) {
                  final level = volume.data ?? widget.player.state.volume;
                  if (level > 0) _audibleVolume = level;
                  return VideoTransportBar(
                    playing: playing.data ?? false,
                    rate: rate.data ?? 1,
                    muted: level == 0,
                    seekBar: seekBar,
                    onPlayPause: widget.onPlayPause,
                    onJumpBackward: usesPhoneLayout(context)
                        ? widget.onJumpBackward
                        : null,
                    onSpeedChange: widget.onSpeedChange,
                    onMute: () =>
                        widget.player.setVolume(level > 0 ? 0 : _audibleVolume),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed transport controls flank a seek area whose geometry owns its markers.
class VideoTransportBar extends StatelessWidget {
  final bool playing;
  final double rate;
  final bool muted;
  final Widget seekBar;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback? onJumpBackward;
  final ValueChanged<double> onSpeedChange;
  const VideoTransportBar({
    super.key,
    required this.playing,
    required this.rate,
    required this.muted,
    required this.seekBar,
    required this.onPlayPause,
    required this.onMute,
    required this.onSpeedChange,
    this.onJumpBackward,
  });

  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static String rateLabel(double value) =>
      '${value == value.roundToDouble() ? value.toInt() : value}×';

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontFamily: 'Roboto');
    final rates = {...speeds, rate}.toList()..sort();
    final width = _labelWidth(context, rates.map(rateLabel), style) + 16;
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: playing ? 'Pause video' : 'Play video',
              onPressed: onPlayPause,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: ToolsetLayout.glyph,
              ),
            ),
          ),
          Expanded(child: seekBar),
          if (onJumpBackward != null)
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: 'Back 5 seconds',
                onPressed: onJumpBackward,
                icon: const Icon(
                  Icons.replay_5_rounded,
                  size: ToolsetLayout.glyph,
                ),
              ),
            ),
          SizedBox(
            width: math.max(48, width),
            height: 48,
            child: PopupMenuButton<double>(
              tooltip: 'Playback speed',
              initialValue: rate,
              onSelected: onSpeedChange,
              itemBuilder: (_) => [
                for (final speed in rates)
                  CheckedPopupMenuItem(
                    value: speed,
                    checked: speed == rate,
                    child: Text(rateLabel(speed)),
                  ),
              ],
              child: Semantics(
                button: true,
                label: 'Playback speed ${rateLabel(rate)}',
                child: Center(child: Text(rateLabel(rate), style: style)),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: muted ? 'Unmute video' : 'Mute video',
              onPressed: onMute,
              icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: ToolsetLayout.glyph,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _labelWidth(
  BuildContext context,
  Iterable<String> labels,
  TextStyle style,
) {
  var width = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    width = math.max(width, painter.width.ceilToDouble());
    painter.dispose();
  }
  return width;
}

/// A shared inset is used for drawing, event hit testing and slider seeking.
class VideoSeekTrack extends StatelessWidget {
  static const trackInset = 14.0;
  final Widget markers;
  final Duration position;
  final Duration duration;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  const VideoSeekTrack({
    super.key,
    required this.markers,
    required this.position,
    required this.duration,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontFamily: 'Roboto',
      );
      final labelWidth =
          _labelWidth(context, [
            formatVideoTime(position),
            formatVideoTime(duration),
          ], style) +
          8;
      final showBoth = constraints.maxWidth >= 120 + labelWidth * 2;
      final showPosition = constraints.maxWidth >= 120 + labelWidth;
      Widget time(Duration value) => SizedBox(
        width: labelWidth,
        height: 48,
        child: Center(
          child: Text(formatVideoTime(value), style: style, maxLines: 1),
        ),
      );
      final value = duration.inMicroseconds > 0
          ? (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0)
          : 0.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showPosition) time(position),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 4,
                          trackShape: _VideoTrackShape(),
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: trackInset,
                          ),
                        ),
                        child: Slider(
                          key: const ValueKey('video-seek-slider'),
                          padding: EdgeInsets.zero,
                          value: value,
                          activeColor: FlowTheme.accent,
                          inactiveColor: FlowTheme.raised,
                          semanticFormatterCallback: (_) =>
                              '${formatVideoTime(position)} of ${formatVideoTime(duration)}',
                          onChangeStart: duration > Duration.zero
                              ? onChangeStart
                              : null,
                          onChanged: duration > Duration.zero
                              ? onChanged
                              : null,
                          onChangeEnd: duration > Duration.zero
                              ? onChangeEnd
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: trackInset,
                      right: trackInset,
                      height: 24,
                      child: markers,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showBoth) time(duration),
        ],
      );
    },
  );
}

class _VideoTrackShape extends RoundedRectSliderTrackShape {
  const _VideoTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) => Rect.fromLTWH(
    offset.dx + VideoSeekTrack.trackInset,
    offset.dy + (parentBox.size.height - (sliderTheme.trackHeight ?? 4)) / 2,
    math.max(0, parentBox.size.width - VideoSeekTrack.trackInset * 2),
    sliderTheme.trackHeight ?? 4,
  );
}

String formatVideoTime(Duration duration) {
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  return duration.inHours > 0
      ? '${duration.inHours}:$minutes:$seconds'
      : '$minutes:$seconds';
}

class _SeekBar extends StatefulWidget {
  final Player player;
  final Duration duration;
  final Widget markers;
  final VoidCallback? onScrubStart;
  const _SeekBar({
    required this.player,
    required this.duration,
    required this.markers,
    this.onScrubStart,
  });
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _isDragging = false;
  double _dragValue = 0;
  late ScrubSeekCoordinator _scrub;
  @override
  void initState() {
    super.initState();
    _scrub = _createCoordinator();
  }

  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _scrub.cancel();
      _scrub = _createCoordinator();
      _isDragging = false;
    }
  }

  @override
  void dispose() {
    _scrub.cancel();
    super.dispose();
  }

  ScrubSeekCoordinator _createCoordinator() => ScrubSeekCoordinator(
    seek: widget.player.seek,
    pause: widget.player.pause,
    play: widget.player.play,
    isPlaying: () => widget.player.state.playing,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: widget.player.stream.position,
    initialData: widget.player.state.position,
    builder: (context, snapshot) {
      Perf.rebuildCount('_SeekBar.stream');
      return VideoSeekTrack(
        markers: widget.markers,
        duration: widget.duration,
        position: _isDragging
            ? Duration(
                microseconds: (_dragValue * widget.duration.inMicroseconds)
                    .round(),
              )
            : snapshot.data ?? Duration.zero,
        onChangeStart: (value) {
          _scrub.begin();
          widget.onScrubStart?.call();
          setState(() {
            _isDragging = true;
            _dragValue = value;
          });
        },
        onChanged: (value) => setState(() => _dragValue = value),
        onChangeEnd: (value) async {
          final current = await _scrub.complete(
            Duration(
              microseconds: (value * widget.duration.inMicroseconds).round(),
            ),
          );
          if (!mounted || !current) return;
          setState(() => _isDragging = false);
        },
      );
    },
  );
}
