import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/services/event_storage_service.dart';
import 'package:flow_lens/services/tracking_storage_service.dart';

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.data);

  final Uint8List data;
  @override
  String get name => 'timeline.json';
  @override
  Uri get uri => Uri.parse('content://documents/timeline.json');
  @override
  Future<Uint8List> readAsBytes() async => data;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Import must read bytes, not access a local path.');
}

class _Picker extends FilePickerPlatform {
  PlatformFile? selected;
  Uint8List? savedBytes;
  String? savedName;
  String? savedMime;
  Uri? destination = Uri.parse('content://documents/export');
  int saves = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => selected;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saves++;
    savedName = fileName;
    savedBytes = bytes;
    savedMime = mimeType;
    return destination;
  }
}

void main() {
  late _Picker picker;
  late FilePickerPlatform original;
  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  final events = [
    GameEvent(
      id: 'goal',
      timestamp: const Duration(milliseconds: 1234),
      label: 'Įvartis 🏒',
      categoryId: 'attack',
      grade: EventGrade.positive,
    ),
  ];
  final session = TrackingSession(
    id: 'tracking',
    createdAt: DateTime.utc(2026, 9, 26),
    subjects: [const TrackingSubject(id: 'player', label: 'Žaidėjas')],
    trackers: [
      const TrackingDefinition(
        id: 'passes',
        label: 'Passes',
        kind: TrackerKind.counter,
      ),
    ],
    events: [
      const TrackingEvent(
        id: 'pass',
        timestamp: Duration(seconds: 4),
        subjectId: 'player',
        trackerId: 'passes',
        action: TrackingAction.increment,
        delta: 1,
      ),
    ],
  );

  test(
    'event JSON round-trips UTF-8 through a picker URI without a disk path',
    () async {
      final service = EventImportExportService();
      await service.saveEvents(events);
      expect(picker.savedName, endsWith('.json'));
      expect(picker.savedMime, 'application/json');
      picker.selected = _MemoryFile(picker.savedBytes!);
      expect(picker.selected!.path, isNull);
      final loaded = await service.loadEvents();
      expect(
        loaded.map((event) => event.toJson()),
        events.map((event) => event.toJson()),
      );
    },
  );

  test(
    'tracking JSON round-trips subjects, trackers and events through picker bytes',
    () async {
      final service = TrackingImportExportService();
      await service.saveSession(session);
      expect(picker.savedName, endsWith('.json'));
      expect(picker.savedMime, 'application/json');
      picker.selected = _MemoryFile(picker.savedBytes!);
      expect((await service.loadSession())!.toJson(), session.toJson());
    },
  );

  test(
    'tracking CSV saves encoded contents through the picker exactly once',
    () async {
      await TrackingImportExportService().exportCsv(session);
      expect(picker.saves, 1);
      expect(picker.savedName, endsWith('.csv'));
      expect(picker.savedMime, 'text/csv');
      final csv = utf8.decode(picker.savedBytes!);
      expect(
        csv,
        contains('pass,4000,player,"Žaidėjas",passes,"Passes",increment,1'),
      );
    },
  );

  test('cancelled imports and exports return normally', () async {
    picker.destination = null;
    final eventService = EventImportExportService();
    final trackingService = TrackingImportExportService();
    expect(await eventService.loadEvents(), isEmpty);
    expect(await trackingService.loadSession(), isNull);
    await eventService.saveEvents(events);
    await trackingService.saveSession(session);
    await trackingService.exportCsv(session);
    expect(picker.saves, 3);
  });

  test('empty data does not open a save dialog', () async {
    await EventImportExportService().saveEvents([]);
    final empty = TrackingSession(id: 'empty');
    await TrackingImportExportService().saveSession(empty);
    await TrackingImportExportService().exportCsv(empty);
    expect(picker.saves, 0);
  });

  test('malformed imported JSON still reports a format error', () async {
    picker.selected = _MemoryFile(Uint8List.fromList(utf8.encode('{broken')));
    await expectLater(
      EventImportExportService().loadEvents(),
      throwsFormatException,
    );
    await expectLater(
      TrackingImportExportService().loadSession(),
      throwsFormatException,
    );
  });
}
