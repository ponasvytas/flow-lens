import 'package:flow_lens/models/app_settings.dart';
import 'package:flow_lens/widgets/control_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget controls(
  List<double> rates, {
  double rate = 0.5,
  AppSettings settings = const AppSettings(fastPlaySpeed: 5),
}) => MaterialApp(
  home: Scaffold(
    body: PlaybackControls(
      rate: rate,
      playing: true,
      settings: settings,
      onSpeedChange: rates.add,
      onJumpForward: (_) {},
      onJumpBackward: (_) {},
      onTogglePlayPause: () {},
      onToggleMute: () {},
    ),
  ),
);

void main() {
  testWidgets('touch fast play starts immediately and restores on release', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    final press = await tester.startGesture(
      tester.getCenter(find.text('Fast\n5.0x')),
    );
    expect(rates, [5]);
    await tester.pumpWidget(controls(rates, rate: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(rates, [5]);
    await press.up();
    await tester.pumpAndSettle();
    expect(rates, [5, 0.5]);
  });

  testWidgets('quick touch tap does not leave fast play enabled', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    await tester.tap(find.text('Fast\n5.0x'));
    await tester.pumpAndSettle();
    expect(rates, [5, 0.5]);
  });

  testWidgets('touch cancellation restores the previous speed', (tester) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    final press = await tester.startGesture(
      tester.getCenter(find.text('Fast\n5.0x')),
    );
    await press.cancel();
    await tester.pumpAndSettle();
    expect(rates, [5, 0.5]);
  });

  testWidgets('release outside the button restores the previous speed', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    final press = await tester.startGesture(
      tester.getCenter(find.text('Fast\n5.0x')),
    );
    await press.moveBy(const Offset(0, 200));
    await press.up();
    await tester.pumpAndSettle();
    expect(rates, [5, 0.5]);
  });

  testWidgets('removing controls while held restores the previous speed', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    final press = await tester.startGesture(
      tester.getCenter(find.text('Fast\n5.0x')),
    );
    await tester.pumpWidget(const SizedBox());
    expect(rates, [5, 0.5]);
    await press.up();
  });

  testWidgets('backgrounding the app restores held fast play', (tester) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    final press = await tester.startGesture(
      tester.getCenter(find.text('Fast\n5.0x')),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(rates, [5, 0.5]);
    await press.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(rates, [5, 0.5]);
  });

  testWidgets('sticky touch setting keeps fast play after release', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(
      controls(
        rates,
        settings: const AppSettings(
          fastPlaySpeed: 5,
          stickyFastPlayOnTouch: true,
        ),
      ),
    );
    await tester.tap(find.text('Fast\n5.0x'));
    await tester.pumpAndSettle();
    expect(rates, [5]);
  });

  testWidgets('mouse click keeps the existing fast play behavior', (
    tester,
  ) async {
    final rates = <double>[];
    await tester.pumpWidget(controls(rates));
    await tester.tap(find.text('Fast\n5.0x'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(rates, [5]);
  });
}
