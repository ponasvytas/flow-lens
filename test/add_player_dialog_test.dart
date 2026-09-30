import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/widgets/add_player_dialog.dart';

void main() {
  testWidgets('player entry keeps focus when the keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    String? playerName;
    String? playerNumber;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AddPlayerDialog(
                    onAdd: (name, number) {
                      playerName = name;
                      playerNumber = number;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextField, 'Name');
    final nameEditor = find.descendant(
      of: nameField,
      matching: find.byType(EditableText),
    );
    expect(find.byType(AddPlayerDialog), findsOneWidget);
    expect(tester.widget<EditableText>(nameEditor).focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(nameEditor).focusNode.hasFocus, isTrue);
    expect(tester.getBottomLeft(nameField).dy, lessThan(544));
    await tester.enterText(nameField, 'Jordan Smith');
    await tester.enterText(find.widgetWithText(TextField, 'Number'), '12');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    expect(playerName, 'Jordan Smith');
    expect(playerNumber, '12');
    expect(find.byType(AddPlayerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
