import 'package:flow_lens/services/export/export_diagnostics.dart';
import 'package:flow_lens/services/export/export_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bounded log retains only the newest 200 lines', () {
    final buffer = BoundedLineBuffer();
    for (var index = 0; index < 250; index++) {
      buffer.add('line $index');
    }
    expect(buffer.length, 200);
    expect(buffer.lines.first, 'line 50');
    expect(buffer.lines.last, 'line 249');
  });

  test('progress is throttled but terminal state is immediate', () {
    final sent = <ExportProgress>[];
    final dispatcher = ExportProgressDispatcher(sent.add);
    for (var index = 0; index < 20; index++) {
      dispatcher.emit(
        ExportProgress(
          status: ExportStatus.extractingClips,
          overallProgress: index / 20,
        ),
      );
    }
    expect(sent, hasLength(1));
    dispatcher.emit(const ExportProgress(status: ExportStatus.done));
    expect(sent.last.status, ExportStatus.done);
    expect(sent, hasLength(2));
    dispatcher.close();
  });
}
