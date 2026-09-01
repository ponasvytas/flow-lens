import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Compile-time gated performance instrumentation.
///
/// Enable in debug or profile mode with
/// `--dart-define=FLOW_LENS_PERF=true`. When disabled, calls return directly
/// without allocating stopwatches or metric entries.
class Perf {
  Perf._();

  static const bool enabled = bool.fromEnvironment(
    'FLOW_LENS_PERF',
    defaultValue: false,
  );

  static final Map<String, int> _counters = <String, int>{};
  static final Map<String, List<int>> _operations = <String, List<int>>{};
  static final List<int> _frameMicros = <int>[];
  static bool _installed = false;

  static void install() {
    if (!enabled || _installed) return;
    SchedulerBinding.instance.addTimingsCallback(_recordFrames);
    _installed = true;
  }

  static void uninstall() {
    if (!_installed) return;
    SchedulerBinding.instance.removeTimingsCallback(_recordFrames);
    _installed = false;
  }

  static void _recordFrames(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameMicros.add(timing.totalSpan.inMicroseconds);
    }
  }

  static void rebuildCount(String tag) => count('rebuild:$tag');

  static void count(String tag, [int amount = 1]) {
    if (!enabled) return;
    _counters[tag] = (_counters[tag] ?? 0) + amount;
  }

  static T time<T>(String label, T Function() action) {
    if (!enabled) return action();
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      _operations
          .putIfAbsent(label, () => <int>[])
          .add(stopwatch.elapsedMicroseconds);
    }
  }

  static Future<T> timeAsync<T>(
    String label,
    Future<T> Function() action,
  ) async {
    if (!enabled) return action();
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _operations
          .putIfAbsent(label, () => <int>[])
          .add(stopwatch.elapsedMicroseconds);
    }
  }

  @visibleForTesting
  static MetricSummary summarize(Iterable<int> samples) {
    final sorted = samples.toList()..sort();
    if (sorted.isEmpty) return const MetricSummary.empty();
    int percentile(double value) {
      final index = ((sorted.length - 1) * value).ceil();
      return sorted[index.clamp(0, sorted.length - 1)];
    }

    return MetricSummary(
      count: sorted.length,
      p50Micros: percentile(0.50),
      p95Micros: percentile(0.95),
      maxMicros: sorted.last,
    );
  }

  static PerfSnapshot snapshot() {
    final operations = <String, MetricSummary>{
      for (final entry in _operations.entries)
        entry.key: summarize(entry.value),
    };
    final slowFrames = _frameMicros.where((value) => value > 33300).length;
    return PerfSnapshot(
      counters: Map<String, int>.unmodifiable(_counters),
      operations: Map<String, MetricSummary>.unmodifiable(operations),
      frames: summarize(_frameMicros),
      droppedFrameCount: slowFrames,
    );
  }

  static void dump() {
    if (!enabled) return;
    debugPrint('[flow-lens-perf] ${snapshot()}');
  }

  static void reset() {
    if (!enabled) return;
    _counters.clear();
    _operations.clear();
    _frameMicros.clear();
  }
}

@immutable
class MetricSummary {
  final int count;
  final int p50Micros;
  final int p95Micros;
  final int maxMicros;

  const MetricSummary({
    required this.count,
    required this.p50Micros,
    required this.p95Micros,
    required this.maxMicros,
  });

  const MetricSummary.empty()
    : count = 0,
      p50Micros = 0,
      p95Micros = 0,
      maxMicros = 0;

  @override
  String toString() =>
      'count=$count p50=${p50Micros}us p95=${p95Micros}us max=${maxMicros}us';
}

@immutable
class PerfSnapshot {
  final Map<String, int> counters;
  final Map<String, MetricSummary> operations;
  final MetricSummary frames;
  final int droppedFrameCount;

  const PerfSnapshot({
    required this.counters,
    required this.operations,
    required this.frames,
    required this.droppedFrameCount,
  });

  @override
  String toString() =>
      'frames=($frames) over33ms=$droppedFrameCount counters=$counters '
      'operations=$operations';
}
