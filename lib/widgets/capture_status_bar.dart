import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_event.dart';
import '../theme/flow_theme.dart';

/// Transient capture feedback overlays the video without reserving layout space.
class CaptureStatusBar extends StatefulWidget {
  const CaptureStatusBar({
    super.key,
    this.lastEvent,
    this.draft,
    this.onEdit,
    this.onUndo,
    this.onResume,
    this.onCancel,
  });
  final GameEvent? lastEvent;
  final GameEvent? draft;
  final VoidCallback? onEdit;
  final VoidCallback? onUndo;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  State<CaptureStatusBar> createState() => _CaptureStatusBarState();
}

class _CaptureStatusBarState extends State<CaptureStatusBar> {
  Timer? _timer;
  bool _showCapture = false;
  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(CaptureStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastEvent != widget.lastEvent) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _showCapture = widget.lastEvent != null;
    if (_showCapture) {
      _timer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showCapture = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.draft ?? (_showCapture ? widget.lastEvent : null);
    if (event == null) return const SizedBox.shrink();
    final draft = widget.draft != null;
    final time =
        '${event.timestamp.inMinutes}:${(event.timestamp.inSeconds % 60).toString().padLeft(2, '0')}';
    final label =
        '${draft ? 'Event entry' : 'Recorded'}: ${event.label} ${event.detail ?? ''} · $time';
    return Align(
      alignment: Alignment.bottomRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: FlowTheme.background,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Tooltip(
                      message: label,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: draft ? 'Resume event entry' : 'Edit last event',
                  onPressed: draft ? widget.onResume : widget.onEdit,
                  icon: Icon(draft ? Icons.edit_note : Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: draft ? 'Cancel event entry' : 'Undo last event',
                  onPressed: draft ? widget.onCancel : widget.onUndo,
                  icon: Icon(draft ? Icons.close : Icons.undo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
