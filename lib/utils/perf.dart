import 'package:flutter/foundation.dart';

/// Lightweight performance tracker, active only in debug mode.
///
/// Usage:
///   Perf.rebuildCount('VideoProgressBar');   // call in build()
///   Perf.time('filterEvents', () => ...);    // wrap expensive work
///   Perf.dump();                             // print summary to console
///   Perf.reset();                            // clear counters
///
/// All methods are no-ops when [kDebugMode] is false, so there is zero
/// overhead in profile/release builds.
class Perf {
  Perf._();

  /// Master switch — set to `true` to re-enable output in debug mode.
  static bool enabled = false;

  /// How often [rebuildCount] prints (every N rebuilds per tag).
  static int rebuildLogInterval = 50;

  // ── Rebuild tracking ────────────────────────────────────────────────

  static final Map<String, int> _rebuilds = {};

  /// Call at the top of a widget's `build()` method.
  /// Increments the counter for [tag] and logs every [rebuildLogInterval].
  static void rebuildCount(String tag) {
    if (!kDebugMode || !enabled) return;
    final count = (_rebuilds[tag] ?? 0) + 1;
    _rebuilds[tag] = count;
    if (count % rebuildLogInterval == 0) {
      debugPrint('[Perf] $tag rebuilt $count times');
    }
  }

  // ── Timing ──────────────────────────────────────────────────────────

  static final Map<String, _TimingStat> _timings = {};

  /// Runs [action] and records how long it took under [label].
  static T time<T>(String label, T Function() action) {
    if (!kDebugMode || !enabled) return action();
    final sw = Stopwatch()..start();
    final result = action();
    sw.stop();
    final stat = _timings.putIfAbsent(label, _TimingStat.new);
    stat.record(sw.elapsedMicroseconds);
    return result;
  }

  /// Async variant of [time].
  static Future<T> timeAsync<T>(String label, Future<T> Function() action) async {
    if (!kDebugMode || !enabled) return action();
    final sw = Stopwatch()..start();
    final result = await action();
    sw.stop();
    final stat = _timings.putIfAbsent(label, _TimingStat.new);
    stat.record(sw.elapsedMicroseconds);
    return result;
  }

  // ── Reporting ───────────────────────────────────────────────────────

  /// Prints a summary of all tracked metrics to the debug console.
  static void dump() {
    if (!kDebugMode || !enabled) return;
    debugPrint('╔══════════════════════════════════════════════');
    debugPrint('║  Perf Summary');
    debugPrint('╠══════════════════════════════════════════════');

    if (_rebuilds.isNotEmpty) {
      debugPrint('║  Rebuilds:');
      final sorted = _rebuilds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        debugPrint('║    ${e.key}: ${e.value}');
      }
    }

    if (_timings.isNotEmpty) {
      debugPrint('║  Timings:');
      for (final e in _timings.entries) {
        final s = e.value;
        debugPrint(
          '║    ${e.key}: calls=${s.count}  '
          'avg=${(s.totalMicros / s.count).toStringAsFixed(0)}µs  '
          'max=${s.maxMicros}µs',
        );
      }
    }

    if (_rebuilds.isEmpty && _timings.isEmpty) {
      debugPrint('║  (no data recorded)');
    }

    debugPrint('╚══════════════════════════════════════════════');
  }

  /// Resets all counters and timings.
  static void reset() {
    _rebuilds.clear();
    _timings.clear();
  }
}

class _TimingStat {
  int count = 0;
  int totalMicros = 0;
  int maxMicros = 0;

  void record(int micros) {
    count++;
    totalMicros += micros;
    if (micros > maxMicros) maxMicros = micros;
  }
}
