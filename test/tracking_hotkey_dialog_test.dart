import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/widgets/tracking_hotkey_dialog.dart';

void main() {
  for (final dismissal in ['Assign', 'Clear', 'Cancel', 'Escape', 'Outside']) {
    testWidgets('$dismissal restores workspace hotkeys after editing', (
      tester,
    ) async {
      final controller = TrackingController(
        session: TrackingSession(
          id: 'test',
          subjects: const [TrackingSubject(id: 's', label: 'Player')],
          trackers: const [
            TrackingDefinition(
              id: 't',
              label: 'Passes',
              kind: TrackerKind.counter,
            ),
          ],
        ),
      );
      final workspace = FocusNode();
      final field = FocusNode();
      final received = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: workspace,
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent && workspace.hasPrimaryFocus) {
                received.add(event.logicalKey);
                controller.handleHotkeyDown(
                  event.logicalKey.keyLabel.toLowerCase(),
                  const Duration(seconds: 5),
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextField(focusNode: field),
                    GestureDetector(
                      onTap: () => showTrackingHotkeyDialog(
                        context: context,
                        controller: controller,
                        subjectId: 's',
                        trackerId: 't',
                      ),
                      child: const Text('Assign tracker key'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Assign tracker key'));
      await tester.pumpAndSettle();
      for (final key in [
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowLeft,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(find.textContaining('Reserved for playback'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Assign'))
              .onPressed,
          isNull,
        );
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.textContaining('Use a key without'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(received, isEmpty);
      expect(controller.events, isEmpty);
      if (dismissal == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else if (dismissal == 'Outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(dismissal));
      }
      await tester.pumpAndSettle();
      expect(workspace.hasPrimaryFocus, isTrue);
      expect(
        controller.getHotkey('s', 't'),
        dismissal == 'Assign' ? 'j' : isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      expect(received, [
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyS,
      ]);
      expect(
        controller.getCounterValue('s', 't'),
        dismissal == 'Assign' ? 1 : 0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      workspace.dispose();
      field.dispose();
      controller.dispose();
    });
  }
}
