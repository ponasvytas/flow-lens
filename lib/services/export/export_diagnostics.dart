import 'dart:async';
import 'dart:collection';

import 'export_models.dart';

class BoundedLineBuffer {
  BoundedLineBuffer({this.capacity = 200}) : assert(capacity > 0);

  final int capacity;
  final Queue<String> _lines = Queue<String>();

  void add(String line) {
    if (_lines.length == capacity) _lines.removeFirst();
    _lines.addLast(line);
  }

  List<String> get lines => List<String>.unmodifiable(_lines);
  int get length => _lines.length;
}

/// Sends progress no faster than [interval], while status transitions and
/// terminal states bypass the throttle.
class ExportProgressDispatcher {
  ExportProgressDispatcher(
    this._send, {
    this.interval = const Duration(milliseconds: 100),
  });

  final void Function(ExportProgress progress) _send;
  final Duration interval;
  ExportStatus? _lastStatus;
  DateTime? _lastSent;
  ExportProgress? _pending;
  Timer? _timer;
  bool _closed = false;

  void emit(ExportProgress progress) {
    if (_closed) return;
    final now = DateTime.now();
    final terminal =
        progress.status == ExportStatus.done ||
        progress.status == ExportStatus.failed ||
        progress.status == ExportStatus.cancelled;
    final immediate =
        terminal ||
        progress.status != _lastStatus ||
        _lastSent == null ||
        now.difference(_lastSent!) >= interval;
    if (immediate) {
      _timer?.cancel();
      _timer = null;
      _pending = null;
      _dispatch(progress, now);
      return;
    }
    _pending = progress;
    _timer ??= Timer(interval - now.difference(_lastSent!), () {
      _timer = null;
      final pending = _pending;
      _pending = null;
      if (pending != null && !_closed) _dispatch(pending, DateTime.now());
    });
  }

  void _dispatch(ExportProgress progress, DateTime now) {
    _lastStatus = progress.status;
    _lastSent = now;
    _send(progress);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
