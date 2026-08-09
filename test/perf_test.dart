import 'package:flow_lens/utils/perf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('performance summaries report p50, p95, and max', () {
    final summary = Perf.summarize(
      List<int>.generate(100, (index) => index + 1),
    );
    expect(summary.count, 100);
    expect(summary.p50Micros, 51);
    expect(summary.p95Micros, 96);
    expect(summary.maxMicros, 100);
  });
}
