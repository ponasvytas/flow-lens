import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Draggable playback control bar with speed and jump controls
class DraggableControlBar extends StatefulWidget {
  final Player player;
  final Function(double) onSpeedChange;
  final Function(Duration) onJumpForward;
  final Function(Duration) onJumpBackward;
  final VoidCallback onTogglePlayPause;

  const DraggableControlBar({
    required this.player,
    required this.onSpeedChange,
    required this.onJumpForward,
    required this.onJumpBackward,
    required this.onTogglePlayPause,
    super.key,
  });

  @override
  State<DraggableControlBar> createState() => _DraggableControlBarState();
}

class _DraggableControlBarState extends State<DraggableControlBar> {
  Offset? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize position centered on first build
    _position ??= Offset(
      MediaQuery.of(context).size.width / 2 - 175,
      20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Only this widget rebuilds on drag, not the entire app!
            _position = Offset(
              _position!.dx + details.delta.dx,
              _position!.dy + details.delta.dy,
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Speed Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Speed: ', style: TextStyle(color: Colors.white)),
                  ...[0.25, 0.5, 1.0, 2.0, 3.0].map((speed) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => widget.onSpeedChange(speed),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(50, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('${speed}x'),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              // Jump Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Jump Backward
                  IconButton(
                    onPressed: () => widget.onJumpBackward(const Duration(seconds: 10)),
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    tooltip: 'Back 10s (Large)',
                  ),
                  IconButton(
                    onPressed: () => widget.onJumpBackward(const Duration(seconds: 5)),
                    icon: const Icon(Icons.replay_5, color: Colors.white),
                    tooltip: 'Back 5s (Medium)',
                  ),
                  IconButton(
                    onPressed: () => widget.onJumpBackward(const Duration(seconds: 2)),
                    icon: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_rewind, color: Colors.white, size: 20),
                        Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    tooltip: 'Back 2s (Small)',
                  ),
                  const SizedBox(width: 8),
                  // Play/Pause Button
                  StreamBuilder<bool>(
                    stream: widget.player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return IconButton(
                        onPressed: widget.onTogglePlayPause,
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: isPlaying ? 'Pause' : 'Play',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Jump Forward
                  IconButton(
                    onPressed: () => widget.onJumpForward(const Duration(seconds: 2)),
                    icon: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                        Icon(Icons.fast_forward, color: Colors.white, size: 20),
                      ],
                    ),
                    tooltip: 'Forward 2s (Small)',
                  ),
                  IconButton(
                    onPressed: () => widget.onJumpForward(const Duration(seconds: 5)),
                    icon: const Icon(Icons.forward_5, color: Colors.white),
                    tooltip: 'Forward 5s (Medium)',
                  ),
                  IconButton(
                    onPressed: () => widget.onJumpForward(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    tooltip: 'Forward 10s (Large)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
